#!/usr/bin/env bash
# =============================================================
# SüreTakip - Eşzamanlı ödeme testi (GERÇEK iki bağlantı)
#
# rls_test.sql tek transaction içinde koştuğu için iki cihazın aynı anda
# ödeme girmesini simüle EDEMEZ. Bu senaryo record_session_payment
# içindeki "select ... for update" kilidinin gerçekten seri hale getirip
# getirmediğini iki ayrı psql bağlantısıyla sınar.
#
# Senaryo: 450,00 TRY'lik tamamlanmış seans.
#   A: 300,00 TRY tahsilat (transaction AÇIK, kilit elinde)
#   B: aynı anda 300,00 TRY tahsilat dener -> A commit edene kadar BLOKE olur
#   A: commit -> B uyanır, kalan bakiyeyi YENİDEN okur (150,00) ve reddeder
# Beklenen: toplam tahsilat 300,00 TRY, B "payment_exceeds_balance" alır.
#
# Kullanım: bash supabase/tests/payment_concurrency_test.sh
# Test verisi sonunda TAMAMEN silinir.
# =============================================================
set -uo pipefail

DB="docker exec -i supabase_db_suretakip psql -U postgres -d postgres -q -t -A"
UID_C='cccccccc-cccc-cccc-cccc-cccccccccccc'
CLAIMS="{\"sub\":\"${UID_C}\",\"role\":\"authenticated\"}"

cleanup() {
  $DB <<SQL >/dev/null 2>&1
delete from public.payment_events where business_id in
  (select id from public.businesses where name = 'Eszamanlilik Testi');
delete from public.payment_allocations where business_id in
  (select id from public.businesses where name = 'Eszamanlilik Testi');
delete from public.payments where business_id in
  (select id from public.businesses where name = 'Eszamanlilik Testi');
delete from public.session_time_entries where business_id in
  (select id from public.businesses where name = 'Eszamanlilik Testi');
delete from public.sessions where business_id in
  (select id from public.businesses where name = 'Eszamanlilik Testi');
delete from public.services where business_id in
  (select id from public.businesses where name = 'Eszamanlilik Testi');
delete from public.business_members where business_id in
  (select id from public.businesses where name = 'Eszamanlilik Testi');
delete from public.businesses where name = 'Eszamanlilik Testi';
delete from auth.users where id = '${UID_C}';
SQL
}
trap cleanup EXIT

echo "--- kurulum ---"
cleanup
SESSION_ID=$($DB <<SQL
insert into auth.users (instance_id, id, aud, role, email)
values ('00000000-0000-0000-0000-000000000000','${UID_C}','authenticated','authenticated','concurrency@test.local');
select set_config('request.jwt.claims','${CLAIMS}', false);
select public.complete_onboarding('Eszamanlilik Testi','TRY','Europe/Istanbul','Salon',1000,1,45);
select public.complete_session(
  public.start_session(
    (select id from public.businesses where name='Eszamanlilik Testi'),
    (select id from public.services where business_id =
      (select id from public.businesses where name='Eszamanlilik Testi'))
  )
);
SQL
)
SESSION_ID=$(echo "$SESSION_ID" | tail -1 | tr -d '[:space:]')

TOTAL=$($DB -c "select grand_total_minor from public.sessions where id='${SESSION_ID}';" | tr -d '[:space:]')
echo "seans: ${SESSION_ID}  toplam: ${TOTAL} kurus"
if [ "$TOTAL" != "45000" ]; then
  echo "HATA: beklenen toplam 45000, gelen ${TOTAL}"; exit 1
fi

echo "--- A ve B es zamanli baslatiliyor ---"

# A: kilidi alir, 3 sn tutar, sonra commit eder.
$DB > /tmp/pay_a.out 2>&1 <<SQL &
begin;
select set_config('request.jwt.claims','${CLAIMS}', true);
select 'A:' || (public.record_session_payment(
  '${SESSION_ID}'::uuid, 'cash', 30000, 'concurrency-A')->>'net_paid_minor');
select pg_sleep(3);
commit;
SQL
PID_A=$!

# B: 1 sn sonra girer; A'nin kilidi yuzunden bloke olur.
$DB > /tmp/pay_b.out 2>&1 <<SQL &
select pg_sleep(1);
select set_config('request.jwt.claims','${CLAIMS}', false);
select 'B:' || (public.record_session_payment(
  '${SESSION_ID}'::uuid, 'card', 30000, 'concurrency-B')->>'net_paid_minor');
SQL
PID_B=$!

wait $PID_A; wait $PID_B

echo "--- A ciktisi ---"; cat /tmp/pay_a.out
echo "--- B ciktisi ---"; cat /tmp/pay_b.out

FINAL=$($DB -c "
  select coalesce(sum(a.amount_minor),0)
  from public.payment_allocations a
  join public.payments p on p.id = a.payment_id
  where a.session_id='${SESSION_ID}' and p.status='completed'
    and p.payment_kind='collection';" | tr -d '[:space:]')

COUNT=$($DB -c "
  select count(*) from public.payment_allocations
  where session_id='${SESSION_ID}';" | tr -d '[:space:]')

echo
echo "toplam tahsilat: ${FINAL} kurus (seans toplami ${TOTAL})"
echo "odeme adedi    : ${COUNT}"

if grep -q "payment_exceeds_balance" /tmp/pay_b.out && [ "$FINAL" = "30000" ] && [ "$COUNT" = "1" ]; then
  echo "PASS: es zamanli ikinci odeme bakiyeyi asamadi (for update seri hale getirdi)"
  exit 0
fi

echo "FAIL: es zamanlilik korumasi calismadi"
exit 1
