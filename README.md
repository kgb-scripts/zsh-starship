# zsh-starship

一键为 **Debian / Ubuntu** 安装 **Zsh + Starship（Catppuccin Mocha）+ zoxide + 常用插件**。兼容全新环境，也兼容已有 Oh My Zsh：会自动备份并卸载 OMZ，同时尽量保留原 `~/.zshrc` 里的自定义环境变量、别名与函数。

## 特性

- **Starship** 提示行，预设 **Catppuccin Mocha** 主题（`starship.toml` 以 base64 嵌入，避免粘贴损坏 UTF-8／Nerd Font 图标）
- **zoxide** 智能目录跳转
- 插件：**zsh-syntax-highlighting**、**zsh-autosuggestions**
- 双击 **ESC** 给当前命令加／去掉 `sudo`（不依赖 Oh My Zsh）
- 常用 Git 别名：`gst` / `gcam` / `gco`
- 已有 Oh My Zsh 时：备份 `~/.zshrc`、移走 `~/.oh-my-zsh`，抽取并合并自定义 `export`／`alias`／`function` 等
- 针对 `curl | bash` 加固：脚本包进 `main()`、`apt` 不读管道 stdin、无 TTY 时不会因 EOF 立刻退出 zsh

## 一键安装（curl）

### 方式一（推荐，直接管道执行，兼容 bash / zsh）

```bash
curl -fsSL https://raw.githubusercontent.com/kgb-scripts/zsh-starship/main/install.sh | bash
```

### 方式二（进程替换，不落盘且保留原终端 stdin，适用于 bash / zsh）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kgb-scripts/zsh-starship/main/install.sh)
```

### 方式三（先下载检查再执行）

```bash
curl -fsSLO https://raw.githubusercontent.com/kgb-scripts/zsh-starship/main/install.sh && bash install.sh
```

> 请用 **bash** 执行本脚本；不要用 `zsh` 去 `source`（避免 `!` 历史展开）。

## 系统要求

- **Debian / Ubuntu**（需要 `apt`）
- 建议终端使用 **Nerd Font**（例如 Maple Mono NF CN），以便正常显示 Starship／系统图标
- 安装过程需要网络（拉取 Starship 安装脚本与插件仓库）
- 非 root 用户需要 `sudo`（套件安装／必要时改默认 shell）

## 执行步骤说明

脚本会按顺序：

1. 检查 `apt`
2. 从旧 `~/.zshrc` 抽取可保留字段
3. 备份 `~/.zshrc` → `~/.zshrc.bak-<时间戳>`
4. 若存在 Oh My Zsh，移走为 `~/.oh-my-zsh.bak-<时间戳>`
5. 安装 `zsh`、`git`、`curl`、`zoxide`、`python3`
6. 安装／更新 Starship，克隆语法高亮与自动建议插件到 `~/.zsh/plugins/`
7. 写入 `~/.config/starship.toml`（并做 UTF-8／结构校验）
8. 写入新 `~/.zshrc`，合并保留字段，语法检查，尝试将默认 shell 设为 zsh

## 一键还原

安装结束时会打印带时间戳的还原命令，形如：

```bash
cp ~/.zshrc.bak-<时间戳> ~/.zshrc
[ -d ~/.oh-my-zsh.bak-<时间戳> ] && mv ~/.oh-my-zsh.bak-<时间戳> ~/.oh-my-zsh
[ -f ~/.config/starship.toml.bak-<时间戳> ] && mv ~/.config/starship.toml.bak-<时间戳> ~/.config/starship.toml
```

把 `<时间戳>` 换成安装时输出的实际值即可。

## License

MIT
