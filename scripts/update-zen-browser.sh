#!/usr/bin/env bash
set -euo pipefail

# determine real user home (works under sudo, su, or direct login)
if [[ -n "${SUDO_USER:-}" ]]; then
    REAL_HOME="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)"
else
    REAL_HOME="$HOME"
fi
: "${REAL_HOME:=$HOME}"

CHECK_MODE=false
INSTALL_MODE=false
[[ "${1:-}" == "--check" ]] && CHECK_MODE=true
[[ "${1:-}" == "--install" ]] && INSTALL_MODE=true

TEMPLATE="$REAL_HOME/void-packages/srcpkgs/zen-browser/template"

# bootstrap template from void-tool if missing
if [[ ! -f "$TEMPLATE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for src in "$SCRIPT_DIR/templates/zen-browser/template" \
               "$REAL_HOME/void-tool/templates/zen-browser/template"; do
        if [[ -f "$src" ]]; then
            echo "📋 Copying template from $src"
            mkdir -p "$(dirname "$TEMPLATE")"
            cp "$src" "$TEMPLATE"
            break
        fi
    done
fi

if [[ ! -f "$TEMPLATE" ]]; then
    echo "❌ Template not found: $TEMPLATE"
    echo "   Clone void-packages first:"
    echo "     git clone https://github.com/void-linux/void-packages.git ~/void-packages"
    echo "     cd ~/void-packages && ./xbps-src binary-bootstrap"
    echo "   Then rerun this command."
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
    if $INSTALL_MODE; then
        echo "✅ версии совпадают ($current_ver), собираю..."
    else
        echo "✅ Версии совпадают, обновление не требуется."
        exit 0
    fi
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
sed -i "s/^revision=[0-9]\+/revision=1/" "$TEMPLATE"

echo "📝 Шаблон обновлён: $current_ver → $latest_ver (revision=1)"

# --- use shared build functions ---
PKGNAME="zen-browser"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/xbps-build-common.sh
source "$SCRIPT_DIR/xbps-build-common.sh"

xbps_ensure_repo_and_bootstrap || { mv "$TEMPLATE.bak" "$TEMPLATE" 2>/dev/null || true; exit 1; }
xbps_sync_repo_and_masterdir || { mv "$TEMPLATE.bak" "$TEMPLATE" 2>/dev/null || true; exit 1; }
if ! xbps_build_with_retry "$PKGNAME"; then
    mv "$TEMPLATE.bak" "$TEMPLATE"
    exit 1
fi
xbps_install_package "$PKGNAME"

rm -f "$TEMPLATE.bak"
echo "✅ Готово! Zen Browser обновлён до $latest_ver"
