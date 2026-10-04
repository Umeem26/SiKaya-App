#!/usr/bin/env bash
# Tangkapan layar otomatis dari integration test (data demo fiktif).
#
# Menjalankan integration_test/satu_hari_test.dart dengan SIKAYA_FOTO=true. Tes
# mencetak "SIKAYA_HOST:<perintah>" (diteruskan ke keluaran flutter test) lalu menunggu; skrip ini menjalankan
# perintahnya lewat adb (screencap, font_scale, screenrecord) dan menjawab dengan
# membuat file files/foto_ok_<id> di folder aplikasi (adb shell run-as).
#
# Pemakaian (dari folder aplikasi Flutter, emulator sudah menyala):
#   bash tool/tangkap_layar.sh [device-id] [file-tes] [folder-hasil]
# Bawaan: integration_test/satu_hari_test.dart -> ../docs/screenshots/*.png dan
# ../docs/demo-flow.mp4. Loop kualitas UI: file-tes integration_test/pratinjau_test.dart
# dan folder-hasil mis. ui-review/putaran-1 (relatif terhadap ../docs).
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash: jangan ubah /sdcard/... jadi path Windows

PERANGKAT="${1:-emulator-5554}"
TES="${2:-integration_test/satu_hari_test.dart}"
FOLDER="${3:-screenshots}"
ADB="${ADB:-adb}"
if ! command -v "$ADB" >/dev/null 2>&1 && [ -n "${LOCALAPPDATA:-}" ]; then
  ADB="$LOCALAPPDATA/Android/sdk/platform-tools/adb.exe"
fi
PAKET="io.github.umeem26.sikaya"
KELUAR="$(cd "$(dirname "$0")/../.." && (pwd -W 2>/dev/null || pwd))/docs"
mkdir -p "$KELUAR/$FOLDER"
perangkat() { "$ADB" -s "$PERANGKAT" "$@"; }

demo() { perangkat shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }

mulai_demo() {
  perangkat shell settings put global sysui_demo_allowed 1
  demo enter
  demo clock -e hhmm 1000
  demo battery -e level 100 -e plugged false -e powersave false
  demo network -e wifi show -e level 4 -e mobile show -e datatype none -e level 4
  demo notifications -e visible false
}

selesai() {
  demo exit || true
  perangkat shell settings put system font_scale 1.0 || true
}
trap selesai EXIT

jawab() { perangkat shell run-as "$PAKET" touch "files/foto_ok_$1"; }

tangani() {
  case "$1" in
    foto:*)
      nama="${1#foto:}"
      perangkat exec-out screencap -p > "$KELUAR/$FOLDER/$nama.png"
      echo "foto: $nama.png"
      jawab "$nama" ;;
    huruf:*)
      skala="${1#huruf:}"
      perangkat shell settings put system font_scale "$skala"
      sleep 2
      mulai_demo # SystemUI keluar dari demo mode saat ukuran huruf berubah
      sleep 1
      jawab "huruf_$skala" ;;
    rekam:mulai)
      perangkat shell rm -f /sdcard/sikaya_demo.mp4
      perangkat shell screenrecord --time-limit 60 /sdcard/sikaya_demo.mp4 &
      sleep 1
      jawab rekam_mulai ;;
    rekam:selesai)
      perangkat shell pkill -INT screenrecord || true
      sleep 3
      perangkat pull /sdcard/sikaya_demo.mp4 "$KELUAR/demo-flow.mp4" >/dev/null
      echo "rekaman: demo-flow.mp4"
      jawab rekam_selesai ;;
  esac
}

mulai_demo
perangkat shell settings put system font_scale 1.0

# Keluaran tes dibaca baris per baris; setiap SIKAYA_HOST:... dijalankan berurutan.
flutter test "$TES" -d "$PERANGKAT" --dart-define=SIKAYA_FOTO=true 2>&1 |
  while IFS= read -r baris; do
    baris="${baris%$'\r'}"
    echo "$baris"
    case "$baris" in *SIKAYA_HOST:*) tangani "${baris#*SIKAYA_HOST:}" ;; esac
  done
