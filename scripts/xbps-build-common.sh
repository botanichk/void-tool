# xbps-build-common.sh — shared functions for xbps-src package builds
# Source from update-*.sh after setting REAL_HOME, PKGNAME, TEMPLATE

xbps_ensure_repo_and_bootstrap() {
    if ! command -v git &>/dev/null; then
        echo "📥 Устанавливаю git..."
        sudo xbps-install -Sy git
    fi

    local VP="$REAL_HOME/void-packages"
    if [[ -d "$VP" && ! -f "$VP/xbps-src" ]]; then
        echo "⚠️  void-packages повреждён (нет xbps-src), удаляю и клонирую заново..."
        rm -rf "$VP"
    fi
    if [[ ! -d "$VP" ]]; then
        echo "📥 Клонирую void-packages..."
        if ! git clone --depth 1 https://github.com/void-linux/void-packages.git "$VP"; then
            echo "❌ Ошибка клонирования void-packages"
            return 1
        fi
    fi
    if [[ ! -d "$VP/masterdir" ]]; then
        echo "🔧 Выполняю binary-bootstrap..."
        if ! (cd "$VP" && ./xbps-src binary-bootstrap); then
            echo "❌ binary-bootstrap не удался"
            echo "   Возможно проблема с файловой системой (chown)."
            echo "   Убедись, что $VP на ext4/btrfs, не FAT/NTFS."
            return 1
        fi
    fi
}

xbps_sync_repo_and_masterdir() {
    local VP="$REAL_HOME/void-packages"
    echo "🔄 Обновляю void-packages и синхронизирую masterdir..."
    (cd "$VP" && git fetch --quiet origin master && git reset --hard origin/master) || true
    if ! (cd "$VP" && ./xbps-src update-sys 2>/dev/null); then
        echo "⚠️  update-sys предупредил об ошибке, продолжаю..."
    fi
    sudo xbps-install -Suy -r "$VP/masterdir" 2>/dev/null || echo "⚠️  masterdir sync skipped (non-fatal)"
}

xbps_build_with_retry() {
    local pkg="$1"
    local VP="$REAL_HOME/void-packages"
    local build_ok=false

    for attempt in 1 2; do
        echo "🔨 Собираю пакет (попытка $attempt)..."
        if (cd "$VP" && ./xbps-src pkg "$pkg"); then
            build_ok=true
            break
        fi
        if [[ "$attempt" -eq 1 ]]; then
            echo "🔄 Сборка не удалась — чищу мастердир + обновляю void-packages, пробую заново..."
            (cd "$VP" && ./xbps-src clean 2>/dev/null) || true
            (cd "$VP" && git fetch --quiet origin master && git reset --hard origin/master) || true
            if ! (cd "$VP" && ./xbps-src binary-bootstrap); then
                echo "❌ binary-bootstrap не удался"
                return 1
            fi
        fi
    done

    if ! $build_ok; then
        echo "❌ Сборка не удалась"
        return 1
    fi
    return 0
}

xbps_install_package() {
    local pkg="$1"
    echo "📦 Устанавливаю..."
    local repo="$REAL_HOME/void-packages/hostdir/binpkgs"
    local cmd
    cmd="xbps-install -y --repository=$repo $pkg"

    if sudo -n true 2>/dev/null; then
        sudo $cmd
    else
        echo ""
        echo "  sudo $cmd"
        echo ""
        /usr/bin/sudo -v 2>/dev/null && sudo $cmd && return
        echo "⚠️  Требуется sudo. Запусти в терминале:"
        echo "   sudo $cmd"
    fi
}
