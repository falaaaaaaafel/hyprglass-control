#!/usr/bin/env bash
# Installer sederhana untuk Hyprglass Control Center.
# Menyalin shell.qml ke ~/.config/quickshell dan membuat entri menu aplikasi.
set -e
cd "$(dirname "$0")"

if ! command -v quickshell >/dev/null 2>&1; then
    echo "Peringatan: 'quickshell' belum terpasang. Pasang dulu sebelum menjalankan aplikasi."
fi

dir="$HOME/.config/quickshell/hyprglass-control"
mkdir -p "$dir" "$HOME/.local/share/applications"
cp shell.qml "$dir/shell.qml"

printf '%s\n' \
  '[Desktop Entry]' \
  'Type=Application' \
  'Name=Hyprglass Control Center' \
  'Exec=quickshell -c hyprglass-control' \
  'Icon=preferences-desktop-theme' \
  'Categories=Settings;' \
  > "$HOME/.local/share/applications/hyprglass-control.desktop"

echo "Selesai. Jalankan dengan: quickshell -c hyprglass-control"
echo "Atau cari 'Hyprglass' di menu aplikasi."
