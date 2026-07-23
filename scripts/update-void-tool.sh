#!/usr/bin/env bash
# update-void-tool.sh — Self-update void-tool from GitHub
set -euo pipefail

REPO_DIR="$HOME/void-tool"

CHECK_MODE=false
INSTALL_MODE=false
[[ "${1:-}" == "--check" ]] && CHECK_MODE=true
[[ "${1:-}" == "--install" ]] && INSTALL_MODE=true

detect_branch() {
    git -C "$REPO_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
        | sed 's|^refs/remotes/origin/||' || echo "main"
}

if $CHECK_MODE; then
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        echo "void-tool: repo not cloned"
        exit 1
    fi
    branch=$(detect_branch)
    git -C "$REPO_DIR" fetch origin "$branch" 2>/dev/null || { echo "void-tool: ?"; exit 1; }
    behind=$(git -C "$REPO_DIR" rev-list --count HEAD.."origin/$branch" 2>/dev/null || echo "0")
    if [[ "$behind" -gt 0 ]]; then
        current_ver=$(grep "^VERSION" "$REPO_DIR/void-tool" | head -1 | awk -F'"' '{print $2}' || echo "?")
        echo "void-tool: $current_ver → update available ($behind commits behind)"
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

branch=$(detect_branch)
git -C "$REPO_DIR" pull origin "$branch"
echo "✓ Репозиторий обновлён"

# self-install
"$REPO_DIR/void-tool" self-install

echo "✅ void-tool обновлён. Перезагрузи оболочку: exec \$SHELL"
