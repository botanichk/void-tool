#!/usr/bin/env bash
set -euo pipefail

TEMPLATE="$HOME/void-packages/srcpkgs/portprotonqt/template"
GITLAB_HOST="git.linux-gaming.ru"
GITLAB_PROJECT="Linux-Gaming%2FPortProtonQt"

CHECK_MODE=false
INSTALL_MODE=false
[[ "${1:-}" == "--check" ]] && CHECK_MODE=true
[[ "${1:-}" == "--install" ]] && INSTALL_MODE=true

# bootstrap template from void-tool if missing
if [[ ! -f "$TEMPLATE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    for src in "$SCRIPT_DIR/templates/portprotonqt/template" \
               "$HOME/void-tool/templates/portprotonqt/template"; do
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
echo "🔍 portprotonqt: текущая версия $current_ver"

# --- fetch latest release tag from RSS feed (GitLab API disabled on this instance) ---
echo "🌐 Проверяю новые релизы через RSS..."
latest_tag=$(curl -sL --max-time 15 "https://${GITLAB_HOST}/Linux-Gaming/PortProtonQt/releases.rss" 2>/dev/null | grep -oP '<title>\Kv[\d.]+(?=</title>)' | head -1 || true)

if [[ -z "$latest_tag" ]]; then
    echo "⚠️  Не удалось проверить релизы (сервер недоступен или пустой ответ)"
    exit 0
fi

latest_ver=${latest_tag#v}
echo "🏷️  Последний релиз: $latest_ver"

if [[ "$current_ver" == "$latest_ver" ]]; then
    if $INSTALL_MODE; then
        echo "✅ версии совпадают ($current_ver), собираю..."
    else
        echo "✅ portprotonqt: версии совпадают ($current_ver), обновление не требуется."
        exit 0
    fi
fi

echo "⬆️  portprotonqt: $current_ver → $latest_ver"
$CHECK_MODE && exit 1

# --- download tarball and compute checksum ---
tarball_url="https://${GITLAB_HOST}/Linux-Gaming/PortProtonQt/archive/v${latest_ver}.tar.gz"
echo "📥 Скачиваю: $tarball_url"
tarball_path=$(mktemp /tmp/ppqt-XXXXXXXX.tar.gz)
curl -sL -o "$tarball_path" "$tarball_url"
new_checksum=$(sha256sum "$tarball_path" | cut -d' ' -f1)
rm -f "$tarball_path"
echo "🔑 Новый checksum: $new_checksum"

# --- back up template ---
cp "$TEMPLATE" "$TEMPLATE.bak"

# --- update template ---
sed -i "s/^version=$current_ver/version=$latest_ver/" "$TEMPLATE"
sed -i "s/^revision=[0-9]\+/revision=1/" "$TEMPLATE"
sed -i "/^checksum=/ s/[a-f0-9]\{64\}/$new_checksum/" "$TEMPLATE"

echo "📝 Шаблон обновлён: $current_ver → $latest_ver (revision=1)"

# --- bootstrap void-packages if needed ---
VP="$HOME/void-packages"
if [[ ! -d "$VP" ]]; then
    echo "📥 Клонирую void-packages..."
    git clone https://github.com/void-linux/void-packages.git "$VP"
fi
if [[ ! -d "$VP/masterdir" ]]; then
    echo "🔧 Выполняю binary-bootstrap..."
    cd "$VP"
    if ! ./xbps-src binary-bootstrap; then
        echo "❌ binary-bootstrap не удался"
        echo "   Возможно проблема с файловой системой (chown)."
        echo "   Убедись, что $VP на ext4/btrfs, не FAT/NTFS."
        exit 1
    fi
    cd - >/dev/null
fi

# --- build ---
echo "🔨 Собираю пакет..."
cd "$VP"
if ! ./xbps-src pkg portprotonqt; then
    echo "❌ Сборка не удалась, откатываю шаблон..."
    mv "$TEMPLATE.bak" "$TEMPLATE"
    exit 1
fi

# --- install ---
echo "📦 Устанавливаю..."
if command -v xi &>/dev/null; then
    sudo xi -y portprotonqt
elif command -v xbps-install &>/dev/null; then
    sudo xbps-install -y --repository="$HOME/void-packages/hostdir/binpkgs" portprotonqt
else
    echo "⚠️  xbps-install не найден, установи вручную:"
    echo "   sudo xbps-install -y --repository=$HOME/void-packages/hostdir/binpkgs portprotonqt"
fi

rm -f "$TEMPLATE.bak"
echo "✅ portprotonqt обновлён до $latest_ver"
