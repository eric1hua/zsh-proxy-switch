#!/usr/bin/env bash
# zsh-proxy-switch 安装脚本
# 幂等：重复跑不会重复写入
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARK="# >>> zsh-proxy-switch >>>"
END="# <<< zsh-proxy-switch <<<"

ts=$(date +%Y%m%d-%H%M%S)

# 1) .zshrc 里 source 主脚本（交互式 shell 拿到 proxy 命令）
if [ -f "$HOME/.zshrc" ] && grep -qF "$MARK" "$HOME/.zshrc"; then
  echo "· .zshrc 已装过，跳过"
else
  [ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$ts" && echo "· 备份 ~/.zshrc.bak.$ts"
  {
    echo ""
    echo "$MARK"
    echo "source \"$REPO/proxy.zsh\""
    echo "$END"
  } >> "$HOME/.zshrc"
  echo "✓ 已写入 ~/.zshrc"
fi

# 2) .zshenv 里读状态文件
#    非交互式 shell（脚本、各种 agent 的 shellEnv 导入）不读 .zshrc，只读 .zshenv
if [ -f "$HOME/.zshenv" ] && grep -qF "$MARK" "$HOME/.zshenv"; then
  echo "· .zshenv 已装过，跳过"
else
  [ -f "$HOME/.zshenv" ] && cp "$HOME/.zshenv" "$HOME/.zshenv.bak.$ts" && echo "· 备份 ~/.zshenv.bak.$ts"
  {
    echo ""
    echo "$MARK"
    echo '# 代理状态由 proxy on/off 写入 ~/.proxy-state'
    echo '[[ -f "$HOME/.proxy-state" ]] && source "$HOME/.proxy-state"'
    echo "$END"
  } >> "$HOME/.zshenv"
  echo "✓ 已写入 ~/.zshenv"
fi

echo ""
echo "装好了。开个新终端，或者跑: source ~/.zshrc"
echo "然后: proxy on"
