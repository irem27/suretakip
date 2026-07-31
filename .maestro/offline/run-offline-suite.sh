#!/usr/bin/env bash
# Offline E2E suite runner (Android emülatör).
#
# Uygulamanın ÇEVRİMDIŞI çalışmasını uçtan uca doğrular: internet yokken tüm
# fonksiyonlar cihaza kaydeder, bağlantı gelince otomatik senkronize eder.
#
# Mekanizma: `adb shell svc wifi/data disable` gerçek bir bağlantı kesmesidir —
# hem uygulamanın Supabase erişimini keser HEM de connectivity_plus'a "bağlantı
# yok" sinyali verir, böylece bağlantı geri gelince otomatik sync tetiklenir
# (iptables ile port bloklamak connectivity olayı üretmez, bu yüzden kullanılmaz).
#
# Ön koşul: emülatör açık, lokal Supabase çalışıyor (`supabase start`), uygulama
# .env.android ile derlenip kurulu, test@suretakip.com hesabı onboard'lu.
#
# Kullanım: bash .maestro/offline/run-offline-suite.sh
set -uo pipefail

DEV="${MAESTRO_DEVICE:-emulator-5554}"
export MAESTRO_EMAIL="${MAESTRO_EMAIL:-test@suretakip.com}"
export MAESTRO_PASSWORD="${MAESTRO_PASSWORD:-Test1234!}"
SUPA="${SUPABASE_URL:-http://127.0.0.1:54321}"
SRK="${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY gerekli}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PASS=0; FAIL=0

netoff(){ adb -s "$DEV" shell svc wifi disable >/dev/null; adb -s "$DEV" shell svc data disable >/dev/null; sleep 3; }
neton(){ adb -s "$DEV" shell svc wifi enable >/dev/null; adb -s "$DEV" shell svc data enable >/dev/null; sleep 6; }
flow(){ maestro --device "$DEV" test "$1" >/tmp/off_flow.log 2>&1; grep -qiE "Flow Passed|Take screenshot|COMPLETED$" /tmp/off_flow.log && ! grep -qiE "Flow Failed|Assertion is false|not found|Couldn't" /tmp/off_flow.log; }
q(){ curl -s -m 8 "$SUPA/rest/v1/$1" -H "apikey: $SRK" -H "Authorization: Bearer $SRK"; }
check(){ # ad, sorgu, beklenen-substring
  local name="$1" res; res="$(q "$2")"
  if echo "$res" | grep -q "$3"; then echo "  ✓ $name"; PASS=$((PASS+1)); else echo "  ✗ $name  (dönen: $res)"; FAIL=$((FAIL+1)); fi
}

neton

echo "== A) Soğuk offline: hiç internet yokken müşteri ekle =="
flow "$HERE/02a-online-prelude.yaml"; netoff; flow "$HERE/01-cold-offline.yaml"; neton; sleep 8
check "Soğuk müşteri sync" "customers?select=name&name=like.*Soguk*" "Soguk"

echo "== B) Kullanım sırasında kesinti: müşteri ekle =="
flow "$HERE/02a-online-prelude.yaml"; netoff; flow "$HERE/02b-offline-add.yaml"; neton; sleep 8
check "Kesinti müşteri sync" "customers?select=name&name=like.*Kesinti*" "Kesinti"

echo "== C) Offline düzenleme: müşteriyi pasife al =="
flow "$HERE/03a-edit-prelude.yaml"; netoff; flow "$HERE/03b-edit-offline.yaml"; neton; sleep 8
check "Offline pasife alma sync" "customers?select=name,is_active&name=eq.Offline%20Edit%20Test&is_active=eq.false" "Offline Edit Test"

echo "== D) Offline seans: başlat + tamamla =="
flow "$HERE/00-login-prelude.yaml"; sleep 6; netoff; flow "$HERE/04-offline-session.yaml"; neton; sleep 10
adb -s "$DEV" shell am force-stop com.suretakip.app; adb -s "$DEV" shell am start -n com.suretakip.app/.MainActivity >/dev/null 2>&1; sleep 12
check "Offline seans completed sync" "sessions?select=status&order=created_at.desc&limit=1" "completed"

echo
echo "==== SONUÇ: $PASS geçti, $FAIL başarısız ===="
[ "$FAIL" -eq 0 ]
