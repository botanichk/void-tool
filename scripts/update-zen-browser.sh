#!/usr/bin/env bash
set -euo pipefail

CHECK_MODE=false
[[ "${1:-}" == "--check" ]] && CHECK_MODE=true

TEMPLATE="$HOME/void-packages/srcpkgs/zen-browser/template"

if [[ ! -f "$TEMPLATE" ]]; then
    echo "❌ Template not found: $TEMPLATE"
    exit 1
fi

# --- get current version from template ---
current_ver=$(grep -oP '^version=\K.*' "$TEMPLATE")
echo "🔍 zen-browser: текущая версия $current_ver"

# --- fetch latest tag from GitHub ---
echo "🌐 Проверяю новые релизы на GitHub..."
latest_tag=$(curl -sL --max-time 15 https://api.github.com/repos/zen-browser/desktop/releases/latest 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' || true)

if [[ -z "$latest_tag" ]]; then
    echo "⚠️  Не удалось проверить GitHub (сервер недоступен или пустой ответ)"
    exit 0
fi

# strip leading 'v' if present
latest_ver=${latest_tag#v}
echo "🏷️  Последний релиз: $latest_ver"

if [[ "$current_ver" == "$latest_ver" ]]; then
    echo "✅ Версии совпадают, обновление не требуется."
    exit 0
fi

echo "⬆️  zen-browser: $current_ver → $latest_ver"
$CHECK_MODE && exit 1

# --- download tarball and compute checksum ---
tarball_url="https://github.com/zen-browser/desktop/releases/download/${latest_tag}/zen.linux-x86_64.tar.xz"
echo "📥 Скачиваю: $tarball_url"
tarball_path=$(mktemp /tmp/zen-XXXXXXXX.tar.xz)
curl -sL -o "$tarball_path" "$tarball_url"
new_checksum=$(sha256sum "$tarball_path" | cut -d' ' -f1)
rm -f "$tarball_path"
echo "🔑 Новый checksum: $new_checksum"

# --- back up template ---
cp "$TEMPLATE" "$TEMPLATE.bak"

# --- update template ---
sed -i "s/^version=$current_ver/version=$latest_ver/" "$TEMPLATE"

# update first checksum (main tarball), keep second (langpack) unchanged
sed -i "/^checksum=/ s/[a-f0-9]\{64\}/$new_checksum/" "$TEMPLATE"

echo "📝 Шаблон обновлён: $current_ver → $latest_ver"

# --- build ---
echo "🔨 Собираю пакет..."
cd "$HOME/void-packages"
if ! ./xbps-src pkg zen-browser; then
    echo "❌ Сборка не удалась, откатываю шаблон..."
    mv "$TEMPLATE.bak" "$TEMPLATE"
    exit 1
fi

# --- install ---
echo "📦 Устанавливаю..."
if command -v xi &>/dev/null; then
    sudo xi -y zen-browser
elif command -v xbps-install &>/dev/null; then
    sudo xbps-install -y --repository="$HOME/void-packages/hostdir/binpkgs" zen-browser
else
    echo "⚠️  xbps-install не найден, установи вручную:"
    echo "   sudo xbps-install -y --repository=$HOME/void-packages/hostdir/binpkgs zen-browser"
fi

rm -f "$TEMPLATE.bak"
echo "✅ Готово! Zen Browser обновлён до $latest_ver"
