#!/usr/bin/env bash
# 卸载：从 .zshrc / .zshenv 里删掉本仓库写入的块，并关掉代理
set -euo pipefail

MARK="# >>> zsh-proxy-switch >>>"
END="# <<< zsh-proxy-switch <<<"
ts=$(date +%Y%m%d-%H%M%S)

for f in "$HOME/.zshrc" "$HOME/.zshenv"; do
  [ -f "$f" ] || continue
  grep -qF "$MARK" "$f" || { echo "· $f 没装过，跳过"; continue; }
  cp "$f" "${f}.bak.${ts}"
  awk -v m="$MARK" -v e="$END" '
    $0 == m {skip=1; next}
    $0 == e {skip=0; next}
    !skip {print}
  ' "${f}.bak.${ts}" > "$f"
  echo "✓ 已从 $(basename "$f") 移除（备份 ${f}.bak.${ts}）"
done

# 清掉残留状态
rm -f "$HOME/.proxy-state" "$HOME/.codex/.env"
for v in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy; do
  /bin/launchctl unsetenv "$v" 2>/dev/null || true
done
if command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1; then
  git config --global --unset "http.https://github.com/.proxy" 2>/dev/null || true
fi
echo "卸载完成。开个新终端生效。"
