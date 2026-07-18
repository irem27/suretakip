-- =============================================================
-- SüreTakip - Migration 6: server_now()
-- Canlı seans sayacını cihaz saati kaymasından bağımsız kılmak için
-- sunucunun o anki zamanını döndürür. İstemci, fetch anındaki server
-- zamanını çapa alıp üstüne kendi ölçtüğü geçen süreyi ekler.
-- =============================================================

create function public.server_now()
returns timestamptz
language sql
stable
as $$
  select now();
$$;

revoke execute on function public.server_now() from public;
grant execute on function public.server_now() to authenticated, anon;
