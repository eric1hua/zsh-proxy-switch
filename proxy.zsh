#!/usr/bin/env zsh
# zsh-proxy-switch — 终端 + GUI 统一代理开关
# 用法: source /path/to/proxy.zsh  然后 proxy on|off|status|check

# ==============================
# Terminal Proxy Switch
# ==============================
# 改地址/端口只改这两行，下面全部自动跟着变
PROXY_HOST="127.0.0.1"
PROXY_PORT="10808"

# 不走代理的目标。各家工具匹配规则不一样，所以写法要保守：
#   - CIDR：curl 8.7+ / Go 都认（实测通过）
#   - 域名：裸域和前置点两种都写。curl 两种都认；
#     Python requests 用 endswith，只认前置点；所以两个都留着最稳
#   - 千万别写 *.example.com —— curl 不认通配符，实测会照样走代理
_proxy_noproxy_list=(
  127.0.0.0/8 127.0.0.1 0.0.0.0 localhost .localhost ::1
  10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16
  .local
  feishu.cn .feishu.cn
  larksuite.com .larksuite.com
)

# 会被 proxyon/proxyoff/launchctl 统一处理的变量名
_proxy_env_vars=(
  HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
  http_proxy https_proxy all_proxy no_proxy
)

# 真实连通性检测：端口在听 ≠ 代理能用，所以要真发一次请求
proxycheck() {
  local host="$PROXY_HOST" port="$PROXY_PORT"
  local purl="http://${host}:${port}"

  if ! nc -z -w 2 "$host" "$port" 2>/dev/null; then
    echo "✗ 端口 ${host}:${port} 没在监听 —— 代理软件没开"
    return 1
  fi
  echo "✓ 端口 ${host}:${port} 在监听"

  local pip
  pip=$(curl -s --max-time 8 -x "$purl" https://api.ipify.org 2>/dev/null)
  if [[ -z "$pip" ]]; then
    echo "✗ 走代理请求失败 —— 端口开着但代理不通（节点挂了？）"
    return 1
  fi
  echo "✓ 代理连通，出口 IP: ${pip}"

  local dip
  dip=$(curl -s --max-time 4 --noproxy '*' https://api.ipify.org 2>/dev/null)
  if [[ -n "$dip" ]]; then
    echo "  不走代理时的出口 IP: ${dip}"
    if [[ "$pip" == "$dip" ]]; then
      # 开了 TUN 的话，"不走代理"其实也被隧道接管了，两个相同才是对的
      if netstat -rn -f inet 2>/dev/null | grep -qE '^(0/1|128\.0/1|1/8)\b'; then
        echo "  ✓ 两个 IP 相同：TUN 已接管全部流量，属正常"
      else
        echo "⚠ 两个 IP 相同，且没开 TUN —— 流量可能没真的走代理"
      fi
    fi
  fi
  return 0
}

proxyon() {
  local h="http://${PROXY_HOST}:${PROXY_PORT}"
  local s="socks5h://${PROXY_HOST}:${PROXY_PORT}"
  local np="${(j:,:)_proxy_noproxy_list}"
  local v

  # 状态文件是唯一事实来源，.zshenv 会读它，openclaw 靠 shellEnv 从 shell 继承
  cat > "$HOME/.proxy-state" <<EOF
export http_proxy="$h" HTTP_PROXY="$h"
export https_proxy="$h" HTTPS_PROXY="$h"
export all_proxy="$s" ALL_PROXY="$s"
export no_proxy="$np" NO_PROXY="$np"
EOF
  source "$HOME/.proxy-state"

  # 同步一份 .env 给会读它的工具（Codex 自身不读，详见文件顶部说明）
  if [[ -d "$HOME/.codex" ]]; then
    {
      echo "# 由 proxyon 自动生成，勿手改（下次 proxyon 会覆盖，proxyoff 会删除）"
      echo "# 内容与 ~/.proxy-state 保持一致"
      for v in $_proxy_env_vars; do
        echo "${v}=${(P)v}"
      done
    } > "$HOME/.codex/.env"
  fi

  # 只让 GitHub 走代理，局域网/内网 git 保持直连
  # git 不可用时只警告，不要拖垮整个 proxyon
  if command git --version >/dev/null 2>&1; then
    command git config --global --unset http.proxy 2>/dev/null
    command git config --global --unset https.proxy 2>/dev/null
    command git config --global "http.https://github.com/.proxy" "$s"
  else
    echo "⚠ git 不可用，已跳过 git 代理设置"
    echo "   常见原因：Xcode 许可协议没同意 —— 跑 sudo xcodebuild -license accept"
  fi

  # GUI 应用（不读 zsh 配置）靠这个；只影响之后启动的进程
  for v in $_proxy_env_vars; do
    /bin/launchctl setenv "$v" "${(P)v}"
  done

  echo "Proxy ON: ${PROXY_HOST}:${PROXY_PORT} (终端 + GUI + 新开的 shell)"
  proxycheck
}

proxyoff() {
  local v
  for v in $_proxy_env_vars; do
    unset "$v"
    /bin/launchctl unsetenv "$v"
  done

  rm -f "$HOME/.proxy-state"
  rm -f "$HOME/.codex/.env"   # 同步删掉，避免留下过期的代理值

  if command git --version >/dev/null 2>&1; then
    command git config --global --unset http.proxy 2>/dev/null
    command git config --global --unset https.proxy 2>/dev/null
    command git config --global --unset "http.https://github.com/.proxy" 2>/dev/null
  fi

  echo "Proxy OFF (终端 + GUI + 新开的 shell)"
}

proxystatus() {
  echo "代理地址: ${PROXY_HOST}:${PROXY_PORT}"
  echo ""
  local v
  for v in $_proxy_env_vars; do
    echo "${v}=${(P)v}"
  done
  echo ""
  echo "状态文件: $([[ -f $HOME/.proxy-state ]] && echo '存在 (开机后自动生效)' || echo '不存在 (关闭状态)')"
  echo ""
  echo "Git proxy (仅 GitHub):"
  if command git --version >/dev/null 2>&1; then
    command git config --global --get "http.https://github.com/.proxy" || echo "  (未设置)"
  else
    echo "  (git 不可用 —— Xcode 协议没同意？)"
  fi
  echo ""
  echo "连通性:"
  proxycheck
}

# 统一入口。老命令 proxyon / proxyoff / proxycheck / proxystatus 仍然可用
proxy() {
  case "$1" in
    on)        proxyon ;;
    off)       proxyoff ;;
    check)     proxycheck ;;
    status|"") proxystatus ;;
    -h|--help|help)
      echo "用法: proxy [on|off|status|check]"
      echo "  on      开代理（终端 + GUI + 新 shell）"
      echo "  off     关代理"
      echo "  status  看当前状态（不带参数时的默认行为）"
      echo "  check   只做连通性检测"
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: proxy [on|off|status|check]"
      return 1
      ;;
  esac
}

# ------------------------------
# Tab 补全
# 需要外部先跑过 compinit（见 README）；没跑过就静默跳过，不报错
# ------------------------------
if (( $+functions[compdef] )); then
  _proxy() {
    local -a cmds
    cmds=(
      'on:开代理（终端 + GUI + 新开的 shell）'
      'off:关代理'
      'status:看当前状态'
      'check:只做连通性检测'
      '--help:显示用法'
    )
    _describe '子命令' cmds
  }
  compdef _proxy proxy
fi
