-- =============================================================
-- SüreTakip - Toplu ödeme durumu
--
-- Geçmiş listesi her seans için ayrı ayrı get_session_payment_summary
-- çağırıyordu (N+1). Liste 50 seans gösterince 50 RPC turu demek; mobilde
-- yavaş ve pahalı. Bu fonksiyon hepsini TEK turda döndürür.
--
-- Ödeme geçmişi (payments dizisi) BİLEREK dönmez: liste ekranı yalnızca
-- rozet ve tutarları gösterir, kalem kalem geçmiş detay ekranının işidir.
-- =============================================================

create function public.get_sessions_payment_status(p_session_ids uuid[])
returns table (
  session_id          uuid,
  session_total_minor bigint,
  collected_minor     bigint,
  refunded_minor      bigint,
  net_paid_minor      bigint,
  remaining_minor     bigint,
  payment_status      text,
  currency_code       text
)
language sql
security definer
set search_path = ''
stable
as $$
  select
    s.id,
    coalesce(s.grand_total_minor, 0),
    t.collected_minor,
    t.refunded_minor,
    t.net_paid_minor,
    greatest(0, coalesce(s.grand_total_minor, 0) - t.net_paid_minor),
    case
      when t.net_paid_minor <= 0 then 'unpaid'
      when t.net_paid_minor < coalesce(s.grand_total_minor, 0) then 'partially_paid'
      else 'paid'
    end,
    s.currency_code_snapshot
  from public.sessions s
  cross join lateral public.calc_session_payment_totals(s.id) t
  -- Tenant izolasyonu: uye olunmayan isletmenin seansi sonuca HIC girmez
  -- (varligi sizdirilmaz, hata da vermez — fail-closed filtre).
  where s.id = any (p_session_ids)
    and public.is_business_member(s.business_id);
$$;

revoke execute on function public.get_sessions_payment_status(uuid[]) from public, anon;
grant execute on function public.get_sessions_payment_status(uuid[]) to authenticated;
