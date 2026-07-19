#!/usr/bin/env bash
# update-void-tool.sh — Self-update void-tool from GitHub
set -euo pipefail

REPO_DIR="$HOME/void-tool"

CHECK_MODE=false
INSTALL_MODE=false
[[ "${1:-}" == "--check" ]] && CHECK_MODE=true
[[ "${1:-}" == "--install" ]] && INSTALL_MODE=true

if $CHECK_MODE; then
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        echo "void-tool: repo not cloned"
        exit 1
    fi
    cd "$REPO_DIR"
    git fetch origin main 2>/dev/null || { echo "void-tool: ?"; exit 1; }
    behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
    if [[ "$behind" -gt 0 ]]; then
        local_ver=$(grep "^VERSION" "$REPO_DIR/void-tool" | head -1 | awk -F'"' '{print $2}' || echo "?")
        echo "void-tool: $local_ver → update available ($behind commits behind)"
        exit 1
    fi
    echo "void-tool: up-to-date"
    exit 0
fi

# --- update ---
echo "⟳ Обновляю void-tool..."
if [[ ! -d "$REPO_DIR/.git" ]]; then
    echo "📥 Клонирую репозиторий..."
    git clone https://github.com/botanichk/void-tool.git "$REPO_DIR"
fi

cd "$REPO_DIR"
git pull origin main
echo "✓ Репозиторий обновлён"

# self-install
./void-tool self-install

echo "✅ void-tool обновлён. Перезагрузи оболочку: exec \$SHELL"
