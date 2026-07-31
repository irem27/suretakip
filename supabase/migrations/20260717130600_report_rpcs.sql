-- =============================================================
-- SüreTakip - Migration 7: Rapor view'ları + RPC'leri
-- Raporlama sunucu tarafında aggregate edilir (client'ta değil).
-- Tüm tutarlar minor-unit (kuruş) bigint; dönemler işletmenin saat
-- dilimine göre hesaplanır. Yalnız 'completed' seanslar gelire girer;
-- 'cancelled' seanslar geçmişte görünür ama raporlara dahil değildir.
-- Not: Bir işletme tek para birimi kullanır (onboarding'de belirlenir);
-- currency_code temsili olarak max() ile taşınır.
-- =============================================================

-- ---------- Dönem sınırı yardımcı fonksiyonu ----------
-- Verilen dönemin [başlangıç, bitiş) sınırlarını işletme saat diliminde
-- döndürür. Yerel duvar-saatinde trunc + interval eklendiği için DST
-- geçişlerinde de gün/hafta/ay sınırları doğru kayar.
create function public.report_period_bounds(
  p_period text,
  p_as_of timestamptz,
  p_timezone text
)
returns table (period_start timestamptz, period_end_exclusive timestamptz)
language sql
stable
set search_path = ''
as $$
  select
    (date_trunc(p_period, p_as_of at time zone p_timezone) at time zone p_timezone),
    ((date_trunc(p_period, p_as_of at time zone p_timezone) + ('1 ' || p_period)::interval)
       at time zone p_timezone);
$$;

revoke execute on function public.report_period_bounds(text, timestamptz, text)
  from public, anon;
grant execute on function public.report_period_bounds(text, timestamptz, text)
  to authenticated;

-- ---------- İç görünümler (yalnız rapor RPC'leri kullanır) ----------
-- Doğrudan erişime kapalı; güvenlik, RPC'lerdeki üyelik kontrolüyle sağlanır.
create view public.report_completed_session_facts_v1 as
select
  s.business_id,
  s.id                       as session_id,
  s.customer_id,
  s.service_id,
  s.service_name_snapshot    as service_name,
  s.ended_at,
  s.charged_minutes,
  s.service_subtotal_minor   as service_total_minor,
  s.products_subtotal_minor  as products_total_minor,
  s.grand_total_minor,
  s.currency_code_snapshot   as currency_code
from public.sessions s
where s.status = 'completed';

create view public.report_completed_item_facts_v1 as
select
  si.business_id,
  si.session_id,
  si.product_id,
  si.product_name_snapshot  as product_name,
  si.quantity,
  si.line_total_minor,
  si.currency_code_snapshot as currency_code,
  s.ended_at
from public.session_items si
join public.sessions s
  on s.id = si.session_id and s.business_id = si.business_id
where s.status = 'completed';

revoke all on public.report_completed_session_facts_v1 from public, anon, authenticated;
revoke all on public.report_completed_item_facts_v1 from public, anon, authenticated;

-- ---------- 1) Gelir özeti (gün/hafta/ay tek çağrıda) ----------
create function public.report_revenue_summary(
  p_business_id uuid,
  p_as_of timestamptz default now()
)
returns table (
  period text,
  period_start timestamptz,
  period_end_exclusive timestamptz,
  completed_count bigint,
  service_total_minor bigint,
  products_total_minor bigint,
  grand_total_minor bigint,
  currency_code text
)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_tz text;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'not_a_member';
  end if;
  select b.timezone into v_tz from public.businesses b where b.id = p_business_id;

  return query
  with periods as (
    select p.period, pb.period_start, pb.period_end_exclusive
    from (values ('day'), ('week'), ('month')) as p(period)
    cross join lateral public.report_period_bounds(p.period, p_as_of, v_tz) pb
  )
  select
    pr.period,
    pr.period_start,
    pr.period_end_exclusive,
    count(f.session_id)::bigint,
    coalesce(sum(f.service_total_minor), 0)::bigint,
    coalesce(sum(f.products_total_minor), 0)::bigint,
    coalesce(sum(f.grand_total_minor), 0)::bigint,
    coalesce(max(f.currency_code), (select b.currency_code from public.businesses b where b.id = p_business_id))
  from periods pr
  left join public.report_completed_session_facts_v1 f
    on f.business_id = p_business_id
   and f.ended_at >= pr.period_start
   and f.ended_at <  pr.period_end_exclusive
  group by pr.period, pr.period_start, pr.period_end_exclusive
  order by array_position(array['day', 'week', 'month'], pr.period);
end;
$$;

revoke execute on function public.report_revenue_summary(uuid, timestamptz) from public, anon;
grant execute on function public.report_revenue_summary(uuid, timestamptz) to authenticated;

-- ---------- 2) En çok gelir getiren hizmetler ----------
create function public.report_top_services(
  p_business_id uuid,
  p_period text default 'month',
  p_limit integer default 5,
  p_as_of timestamptz default now()
)
returns table (
  service_id uuid,
  service_name text,
  completed_count bigint,
  service_revenue_minor bigint,
  currency_code text
)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_tz text;
  v_start timestamptz;
  v_end timestamptz;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'not_a_member';
  end if;
  if p_period not in ('day', 'week', 'month') then
    raise exception 'invalid_period';
  end if;
  select b.timezone into v_tz from public.businesses b where b.id = p_business_id;
  select pb.period_start, pb.period_end_exclusive into v_start, v_end
  from public.report_period_bounds(p_period, p_as_of, v_tz) pb;

  return query
  select
    f.service_id,
    max(f.service_name),
    count(*)::bigint,
    coalesce(sum(f.service_total_minor), 0)::bigint,
    max(f.currency_code)
  from public.report_completed_session_facts_v1 f
  where f.business_id = p_business_id
    and f.ended_at >= v_start
    and f.ended_at <  v_end
  group by f.service_id
  order by count(*) desc, coalesce(sum(f.service_total_minor), 0) desc
  limit greatest(p_limit, 0);
end;
$$;

revoke execute on function public.report_top_services(uuid, text, integer, timestamptz) from public, anon;
grant execute on function public.report_top_services(uuid, text, integer, timestamptz) to authenticated;

-- ---------- 3) En çok satılan ürünler ----------
create function public.report_top_products(
  p_business_id uuid,
  p_period text default 'month',
  p_limit integer default 5,
  p_as_of timestamptz default now()
)
returns table (
  product_id uuid,
  product_name text,
  sold_quantity bigint,
  product_revenue_minor bigint,
  currency_code text
)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_tz text;
  v_start timestamptz;
  v_end timestamptz;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'not_a_member';
  end if;
  if p_period not in ('day', 'week', 'month') then
    raise exception 'invalid_period';
  end if;
  select b.timezone into v_tz from public.businesses b where b.id = p_business_id;
  select pb.period_start, pb.period_end_exclusive into v_start, v_end
  from public.report_period_bounds(p_period, p_as_of, v_tz) pb;

  return query
  select
    f.product_id,
    max(f.product_name),
    coalesce(sum(f.quantity), 0)::bigint,
    coalesce(sum(f.line_total_minor), 0)::bigint,
    max(f.currency_code)
  from public.report_completed_item_facts_v1 f
  where f.business_id = p_business_id
    and f.ended_at >= v_start
    and f.ended_at <  v_end
  group by f.product_id
  order by coalesce(sum(f.quantity), 0) desc, coalesce(sum(f.line_total_minor), 0) desc
  limit greatest(p_limit, 0);
end;
$$;

revoke execute on function public.report_top_products(uuid, text, integer, timestamptz) from public, anon;
grant execute on function public.report_top_products(uuid, text, integer, timestamptz) to authenticated;

-- ---------- 4) En çok harcayan müşteriler (misafir hariç) ----------
create function public.report_top_customers(
  p_business_id uuid,
  p_period text default 'month',
  p_limit integer default 5,
  p_as_of timestamptz default now()
)
returns table (
  customer_id uuid,
  customer_name text,
  completed_count bigint,
  spending_minor bigint,
  currency_code text
)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_tz text;
  v_start timestamptz;
  v_end timestamptz;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'not_a_member';
  end if;
  if p_period not in ('day', 'week', 'month') then
    raise exception 'invalid_period';
  end if;
  select b.timezone into v_tz from public.businesses b where b.id = p_business_id;
  select pb.period_start, pb.period_end_exclusive into v_start, v_end
  from public.report_period_bounds(p_period, p_as_of, v_tz) pb;

  return query
  select
    f.customer_id,
    max(c.name),
    count(*)::bigint,
    coalesce(sum(f.grand_total_minor), 0)::bigint,
    max(f.currency_code)
  from public.report_completed_session_facts_v1 f
  join public.customers c
    on c.id = f.customer_id and c.business_id = f.business_id
  where f.business_id = p_business_id
    and f.customer_id is not null
    and f.ended_at >= v_start
    and f.ended_at <  v_end
  group by f.customer_id
  order by coalesce(sum(f.grand_total_minor), 0) desc, count(*) desc
  limit greatest(p_limit, 0);
end;
$$;

revoke execute on function public.report_top_customers(uuid, text, integer, timestamptz) from public, anon;
grant execute on function public.report_top_customers(uuid, text, integer, timestamptz) to authenticated;

-- ---------- 5) Dashboard metrikleri (tek çağrı) ----------
create function public.dashboard_metrics(
  p_business_id uuid,
  p_as_of timestamptz default now()
)
returns table (
  server_now timestamptz,
  active_session_count bigint,
  today_completed_count bigint,
  today_revenue_minor bigint,
  currency_code text
)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_tz text;
  v_start timestamptz;
  v_end timestamptz;
begin
  if not public.is_business_member(p_business_id) then
    raise exception 'not_a_member';
  end if;
  select b.timezone into v_tz from public.businesses b where b.id = p_business_id;
  select pb.period_start, pb.period_end_exclusive into v_start, v_end
  from public.report_period_bounds('day', p_as_of, v_tz) pb;

  return query
  select
    now(),
    (select count(*)::bigint
       from public.sessions s
      where s.business_id = p_business_id
        and s.status in ('active', 'paused')),
    (select count(*)::bigint
       from public.report_completed_session_facts_v1 f
      where f.business_id = p_business_id
        and f.ended_at >= v_start and f.ended_at < v_end),
    (select coalesce(sum(f.grand_total_minor), 0)::bigint
       from public.report_completed_session_facts_v1 f
      where f.business_id = p_business_id
        and f.ended_at >= v_start and f.ended_at < v_end),
    (select b.currency_code from public.businesses b where b.id = p_business_id);
end;
$$;

revoke execute on function public.dashboard_metrics(uuid, timestamptz) from public, anon;
grant execute on function public.dashboard_metrics(uuid, timestamptz) to authenticated;
