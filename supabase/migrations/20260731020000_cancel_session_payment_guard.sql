-- Finansal tutarlılık guard'ı: tahsilatı olan bir seans iptal edilemez.
--
-- Sorun (bug avı, MEDIUM): `cancel_session` ve offline `sync_session_event`
-- cancel dalı, `completed` bir seansı owner/admin rolüyle iptal edebiliyordu;
-- ancak o seansa bağlı `completed` ödemelere (payment_allocations -> payments)
-- hiç dokunulmuyordu. Sonuç: "iptal edilmiş seans" ama "tahsil edilmiş para"
-- şeklinde muhasebe tutarsızlığı; hiçbir kontrol bunu engellemiyordu.
--
-- Çözüm: `sessions` üzerinde tek, izole bir BEFORE UPDATE trigger'ı. Seans
-- `cancelled` durumuna geçerken o seansa ait `completed` (void edilmemiş) bir
-- ödeme varsa iptal reddedilir. Bu, hem online (`cancel_session`) hem offline
-- (`sync_session_event`) yolunu, büyük RPC'leri yeniden yazmadan korur.
--
-- Doğru akış: önce `void_payment` ile tahsilat iptal edilir, sonra seans
-- iptal edilir. Veri kaybı yok — yalnızca tutarsız duruma geçiş engellenir.

create or replace function public.guard_cancel_session_with_payments()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'cancelled'
     and old.status is distinct from 'cancelled'
     and exists (
       select 1
       from public.payment_allocations pa
       join public.payments pm on pm.id = pa.payment_id
       where pa.session_id = new.id
         and pm.status = 'completed'
     )
  then
    raise exception 'session_has_active_payments'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_cancel_session_with_payments on public.sessions;

create trigger trg_guard_cancel_session_with_payments
  before update on public.sessions
  for each row
  when (new.status = 'cancelled' and old.status is distinct from 'cancelled')
  execute function public.guard_cancel_session_with_payments();
