-- =============================================================
-- SüreTakip - Tahsilat raporlaması
--
-- KRİTİK: Mevcut ciro raporlarının anlamı DEĞİŞTİRİLMEZ.
-- report_revenue_summary hâlâ "kesinleşmiş satış"tır. Tahsilat AYRI bir
-- RPC'de döner. Satışı tahsilat gibi göstermek işletmeye yanlış nakit
-- tablosu verir; iki kavram bilinçli olarak ayrı tutulur.
--
-- Dönem kovalama farkı (bilinçli):
--   satış  -> sessions.ended_at   (iş ne zaman bitti)
--   tahsilat -> payments.received_at (para ne zaman geldi)
-- Dün biten bir işin bugün ödenmesi gerçek hayattır; bu yüzden her ölçüt
-- KENDİ zaman damgasına göre kovalanır.
-- =============================================================

-- ---------- İç görünüm: seans başına ödeme tablosu ----------
-- Yalnız rapor RPC'leri kullanır; authenticated'a yetki VERİLMEZ.
create view public.report_session_payment_facts_v1 as
select
  s.business_id,
  s.id                    as session_id,
  s.ended_at,
  s.currency_code_snapshot as currency_code,
  s.grand_total_minor,
  coalesce(t.collected_minor, 0) as collected_minor,
  coalesce(t.refunded_minor, 0)  as refunded_minor,
  coalesce(t.net_paid_minor, 0)  as net_paid_minor,
  greatest(0, s.grand_total_minor - coalesce(t.net_paid_minor, 0)) as remaining_minor
from public.sessions s
left join lateral public.calc_session_payment_totals(s.id) t on true
where s.status = 'completed';

revoke all on public.report_session_payment_facts_v1 from public, anon, authenticated;

-- ---------- Tahsilat özeti ----------
create function public.report_collection_summary(
  p_business_id uuid,
  p_as_of timestamptz default now()
)
returns table (
  period                        text,
  period_start                  timestamptz,
  period_end_exclusive          timestamptz,
  finalized_sales_minor         bigint,
  net_collected_minor           bigint,
  cash_collected_minor          bigint,
  card_collected_minor          bigint,
  bank_transfer_collected_minor bigint,
  other_collected_minor         bigint,
  refunded_minor                bigint,
  outstanding_minor             bigint,
  currency_code                 text
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
  ),
  -- Satış ve alacak: seansın BİTİŞ tarihine göre.
  sales as (
    select
      pr.period,
      coalesce(sum(f.grand_total_minor), 0)::bigint as finalized_sales_minor,
      coalesce(sum(f.remaining_minor), 0)::bigint   as outstanding_minor
    from periods pr
    left join public.report_session_payment_facts_v1 f
      on f.business_id = p_business_id
     and f.ended_at >= pr.period_start
     and f.ended_at <  pr.period_end_exclusive
    group by pr.period
  ),
  -- Tahsilat ve iade: paranın ALINDIĞI tarihe göre.
  -- Yalnız status='completed'; iptal edilmiş (voided) ödemeler hiç sayılmaz.
  money as (
    select
      pr.period,
      coalesce(sum(a.amount_minor) filter (
        where pm.payment_kind = 'collection' and pm.payment_method = 'cash'), 0)::bigint as cash_minor,
      coalesce(sum(a.amount_minor) filter (
        where pm.payment_kind = 'collection' and pm.payment_method = 'card'), 0)::bigint as card_minor,
      coalesce(sum(a.amount_minor) filter (
        where pm.payment_kind = 'collection' and pm.payment_method = 'bank_transfer'), 0)::bigint as bank_minor,
      coalesce(sum(a.amount_minor) filter (
        where pm.payment_kind = 'collection' and pm.payment_method = 'other'), 0)::bigint as other_minor,
      coalesce(sum(a.amount_minor) filter (
        where pm.payment_kind = 'refund'), 0)::bigint as refunded_minor
    from periods pr
    left join public.payments pm
      on pm.business_id = p_business_id
     and pm.status = 'completed'
     and pm.received_at >= pr.period_start
     and pm.received_at <  pr.period_end_exclusive
    left join public.payment_allocations a
      on a.payment_id = pm.id and a.business_id = pm.business_id
    group by pr.period
  )
  select
    pr.period,
    pr.period_start,
    pr.period_end_exclusive,
    s.finalized_sales_minor,
    (m.cash_minor + m.card_minor + m.bank_minor + m.other_minor - m.refunded_minor)::bigint,
    m.cash_minor,
    m.card_minor,
    m.bank_minor,
    m.other_minor,
    m.refunded_minor,
    s.outstanding_minor,
    (select b.currency_code from public.businesses b where b.id = p_business_id)
  from periods pr
  join sales s on s.period = pr.period
  join money m on m.period = pr.period
  order by array_position(array['day', 'week', 'month'], pr.period);
end;
$$;

revoke execute on function public.report_collection_summary(uuid, timestamptz) from public, anon;
grant execute on function public.report_collection_summary(uuid, timestamptz) to authenticated;
