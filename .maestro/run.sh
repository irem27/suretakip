#!/usr/bin/env bash
# SüreTakip Maestro E2E koşucusu (iOS Simulator).
#
# NEDEN GEREKLİ: iOS'ta Supabase oturumu Keychain'de saklanır ve maestro'nun
# `clearState`'i (hatta uninstall) bunu SİLMEZ. Tek `maestro test .maestro/`
# çağrısında ilk akış giriş yapınca sonraki akışlar giriş-yapılmış açılır ve
# login ekranı bekleyen akışlar düşer. Bu koşucu HER akıştan önce keychain'i
# sıfırlayıp uygulamayı sonlandırarak her akışı temiz (çıkışlı) başlatır.
#
# Kullanım:
#   .maestro/run.sh                 # ilk booted iOS simulator'da tüm akışlar
#   MAESTRO_DEVICE=<udid> .maestro/run.sh
#   .maestro/run.sh .maestro/02-login.yaml   # tek akış
#
# Not: Login akışları için Supabase'de test hesabı bulunmalı
#   (MAESTRO_EMAIL / MAESTRO_PASSWORD; varsayılan test@suretakip.com).
set -uo pipefail

APP_ID="com.suretakip.app"
DEVICE="${MAESTRO_DEVICE:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
fi
if [[ -z "$DEVICE" ]]; then
  echo "HATA: booted iOS simulator yok. Önce bir simulator başlatın." >&2
  exit 2
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ $# -gt 0 ]]; then
  FLOWS=("$@")
else
  FLOWS=("$DIR"/[0-9]*.yaml)
fi

fail=0
for flow in "${FLOWS[@]}"; do
  xcrun simctl terminate "$DEVICE" "$APP_ID" >/dev/null 2>&1 || true
  xcrun simctl keychain "$DEVICE" reset >/dev/null 2>&1 || true
  echo "▶ $(basename "$flow")"
  if ! maestro --device "$DEVICE" test "$flow"; then
    fail=1
  fi
done

if [[ $fail -eq 0 ]]; then
  echo "✅ Tüm akışlar geçti."
else
  echo "❌ En az bir akış başarısız."
fi
exit $fail
