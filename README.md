# zsh-proxy-switch

一个 zsh 代理开关。一条命令同时管住**终端、GUI 应用、之后新开的 shell**。

为 macOS + Clash / Clash Verge / v2ray 这类本地代理写的，默认 `127.0.0.1:10808`。

```
proxy on       # 开
proxy off      # 关
proxy status   # 看状态（不带参数同此）
proxy check    # 只做连通性检测
proxy --help
```

---

## 安装

### 给 agent 的安装命令

把下面整段贴给 Claude Code / Codex 之类的编码 agent：

```
克隆 https://github.com/eric1hua/zsh-proxy-switch 到 ~/Developer/zsh-proxy-switch，
然后跑 ./install.sh。装完告诉我要不要重开终端。
如果 ~/.zshrc 里已经有旧的 proxyon/proxyoff 函数，先帮我删掉，避免和新脚本重名冲突。
```

本地已经有这个仓库的话，直接：

```
跑 ~/Developer/zsh-proxy-switch/install.sh，然后告诉我怎么验证装好了
```

### 手动安装

```bash
git clone https://github.com/eric1hua/zsh-proxy-switch.git ~/Developer/zsh-proxy-switch
~/Developer/zsh-proxy-switch/install.sh
source ~/.zshrc
proxy on
```

`install.sh` 是幂等的，重复跑不会重复写入。动 `~/.zshrc` 和 `~/.zshenv` 前都会自动备份。

### 卸载

```bash
~/Developer/zsh-proxy-switch/uninstall.sh
```

---

## Tab 补全

`proxy <Tab>` 会列出子命令和说明：

```
$ proxy <Tab>
on      -- 开代理（终端 + GUI + 新开的 shell）
off     -- 关代理
status  -- 看当前状态
check   -- 只做连通性检测
--help  -- 显示用法
```

前提是你的 `.zshrc` 里跑过 `compinit`，而且在 source 本脚本**之前**：

```zsh
autoload -Uz compinit
compinit
```

没跑过的话补全会静默跳过，`proxy on/off` 照常能用，只是 Tab 补不出来。

顺带一提：`compinit` 缺失是个很隐蔽的坑。没有它，所有 `compdef` 注册都会悄悄失效 ——
补全函数加载了，按 Tab 却什么都不出来，也不报错。检查方法：

```bash
zsh -ic 'echo ${#_comps}'   # 返回 0 就是没跑 compinit
```

---

## 改端口

只改 `proxy.zsh` 开头两行：

```zsh
PROXY_HOST="127.0.0.1"
PROXY_PORT="10808"
```

其余地方全部自动跟着变。

Clash Verge 用户注意：你的端口在
`~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/verge.yaml`
的 `verge_mixed_port`，两边别对不上。

---

## 它到底做了什么

`proxy on` 会：

| 动作 | 作用范围 |
|---|---|
| 写 `~/.proxy-state` 并 source | 当前终端 |
| `.zshenv` 读这个文件 | 所有新 shell，含非交互式（agent 的 shellEnv 导入） |
| `launchctl setenv` | GUI 应用（**只影响之后启动的进程**） |
| `git config --global http.https://github.com/.proxy` | 只让 GitHub 走代理，内网 git 保持直连 |
| 写 `~/.codex/.env`（如果目录存在） | 读 .env 的工具 |

`proxy off` 把上面全部撤销。

---

## 三个踩过的坑

**1. `no_proxy` 不支持 `*` 通配符**

`*.example.com` 在 curl 里**完全无效**，会照样走代理。实测：

```
--noproxy '*.example.com' → 走代理 ✗
--noproxy '.example.com'  → 直连  ✓
```

macOS 系统代理的绕过列表认 `*.`，curl 不认。从系统设置里照抄格式会中招。

本脚本裸域和前置点两种都写（`feishu.cn` 和 `.feishu.cn`），因为 Python requests 用 `endswith`，只认前置点。

**2. CIDR 是支持的**

`10.0.0.0/8`、`127.0.0.0/8` 在 curl 8.7+ 和 Go 里都生效。

验证时别只看 HTTP 状态码 —— 连不上的目标和被代理拦住的目标都返回 `000`。要看 curl 实际连了谁：

```bash
curl -sv --proxy http://127.0.0.1:9 --noproxy "$no_proxy" http://目标/ 2>&1 | grep -m1 Trying
# Trying 127.0.0.1:9  = 走代理
# Trying <目标地址>    = 绕开了
```

**3. zsh 里 `local v` 声明两次会打印旧值**

```zsh
f(){ local v; v=abc; local v; }   # 输出 v=abc
```

函数里同一个变量只声明一次。

---

## 依赖

`zsh` · `curl` · `nc` · `netstat` · `launchctl`（macOS 自带）· `git`（可选，没有就跳过 git 代理设置）

macOS 上装了 Xcode 但没同意许可协议的话，所有 `git` 调用都会弹提示。跑一次：

```bash
sudo xcodebuild -license accept
```
