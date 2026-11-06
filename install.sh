#!/bin/bash
# Starship 版 zsh 一键安装（新装／已有 Oh My Zsh 通用）
# 1) 保存旧 ~/.zshrc 有用部分  2) 卸载 OMZ  3) 安装 Starship 版  4) 合并有用字段
# 粘贴安全：请用 bash 跑（bash /path/to/script.sh），唔好用 zsh source（避免 ! history）
# starship.toml 以 base64 写入，避免 Powerline glyph 在 heredoc/粘贴时损坏 UTF-8
# curl|bash 加固：整段包进 main()，避免管道 stdin 被子命令吞掉／半截执行
set -eu

main() {

stamp=$(date +%Y%m%d%H%M%S)
ZSHRC="$HOME/.zshrc"
PRESERVE="$HOME/.zshrc.preserve-$stamp"
ZSH_PLUGIN_DIR="$HOME/.zsh/plugins"
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

step "0/7 检查 apt"
if ! command -v apt >/dev/null 2>&1; then
  echo "冇 apt：呢个脚本只支援 Debian/Ubuntu，请手动安装。" >&2
  exit 1
fi
SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"

step "1/7 由旧 ~/.zshrc 抽取有用字段 -> $PRESERVE"
: > "$PRESERVE"
if [ -f "$ZSHRC" ]; then
  awk '
    function brace(s,  o,c,t){ t=s; o=gsub(/\{/,"",t); t=s; c=gsub(/\}/,"",t); return o-c }
    # 跳过旧 preserved 标记 / agnoster 覆盖块
    /^# BEGIN agnoster-color-override/ { skipblk=1; next }
    /^# END agnoster-color-override/   { skipblk=0; next }
    skipblk { next }
    # 收集中嘅 function 块
    infn { if (keepfn) print; depth+=brace($0); if (depth<=0) infn=0; next }
    { line=$0; sub(/^[ \t]+/,"",line) }
    line=="" || line ~ /^#/ { next }
    # ---- SKIP：OMZ / starship / 插件 / 新 .zshrc 已有内容 ----
    line ~ /^(export[ \t]+)?(ZSH|ZSH_THEME|ZSH_CUSTOM|ZSH_CACHE_DIR|UPDATE_ZSH_DAYS|HIST_STAMPS|HISTFILE|HISTSIZE|SAVEHIST)=/ { next }
    line ~ /^plugins=/ { if (line !~ /\)/) inplug=1; next }
    inplug { if (line ~ /\)/) inplug=0; next }
    line ~ /^(export[ \t]+)?(DISABLE_|COMPLETION_WAITING|CASE_SENSITIVE|HYPHEN_INSENSITIVE|ENABLE_CORRECTION|COMP_DIST)/ { next }
    line ~ /^zstyle[ \t]+.?:omz/ { next }
    line ~ /oh-my-zsh|\$ZSH\/|starship|zoxide init|zsh-syntax-highlighting|zsh-autosuggestions/ { next }
    line ~ /^(prompt_context|prompt_dir)[ \t]*\(\)/ || line ~ /^function[ \t]+(prompt_context|prompt_dir)/ { skipfn=1 }
    line ~ /sudo-command-line/ { skipfn=1 }
    line ~ /^(autoload[ \t]+-Uz[ \t]+compinit|compinit|setopt[ \t]+no_nomatch)/ { next }
    line ~ /^alias[ \t]+(gst|gcam|gco)=/ { next }
    # ---- function 块（多行）----
    line ~ /^function[ \t]+[^ \t]+/ || line ~ /^[A-Za-z0-9_.:-]+[ \t]*\(\)[ \t]*(\{|$)/ {
      keepfn=!skipfn; skipfn=0
      if (keepfn) print
      depth=brace(line); if (depth>0 || line !~ /\}/) infn=(depth>0); next
    }
    skipfn { skipfn=0; next }
    # ---- KEEP ----
    line ~ /^export[ \t]+/                         { print; next }
    line ~ /^[A-Za-z_][A-Za-z0-9_]*=/              { print; next }
    line ~ /^(path|fpath)[+]?=/                    { print; next }
    line ~ /path_helper/                           { print; next }
    line ~ /^(source|\.)[ \t]+/                    { print; next }
    line ~ /^eval[ \t]/                            { print; next }
    line ~ /^alias[ \t]/                           { print; next }
    line ~ /^autoload[ \t]/                        { print; next }
    line ~ /^\[[ \t\[].*\][ \t]*&&[ \t]*(source|\.)[ \t]/ { print; next }
  ' "$ZSHRC" > "$PRESERVE"
fi
if [ -s "$PRESERVE" ]; then
  echo "保留咗以下字段："; echo "-----"; cat "$PRESERVE"; echo "-----"
else
  echo "（冇需要保留嘅字段）"
fi

step "2/7 备份 ~/.zshrc"
[ -f "$ZSHRC" ] && cp -a "$ZSHRC" "$HOME/.zshrc.bak-$stamp" && echo "已备份 -> ~/.zshrc.bak-$stamp" || echo "冇旧 ~/.zshrc"

step "3/7 卸载 Oh My Zsh"
if [ -d "$HOME/.oh-my-zsh" ]; then
  mv "$HOME/.oh-my-zsh" "$HOME/.oh-my-zsh.bak-$stamp"
  echo "已移走 -> ~/.oh-my-zsh.bak-$stamp（custom 插件／主题都喺入面）"
else
  echo "冇 ~/.oh-my-zsh，跳过"
fi
rm -f "$HOME"/.zcompdump* 2>/dev/null || true

step "4/7 安装套件 zsh git curl zoxide python3"
export DEBIAN_FRONTEND=noninteractive
$SUDO apt update </dev/null
$SUDO apt -y install zsh git curl zoxide python3 </dev/null

step "5/7 安装 Starship 同插件"
if command -v starship >/dev/null 2>&1; then
  echo "starship 已存在：$(starship --version | head -n1)（重新执行安装以更新）"
fi
curl -sS https://starship.rs/install.sh | $SUDO sh -s -- -y
mkdir -p "$ZSH_PLUGIN_DIR"
[ -d "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting" ] && echo "zsh-syntax-highlighting 已存在，跳过" || git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting"
[ -d "$ZSH_PLUGIN_DIR/zsh-autosuggestions" ] && echo "zsh-autosuggestions 已存在，跳过" || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGIN_DIR/zsh-autosuggestions"

step "6/7 写入 ~/.config/starship.toml（Catppuccin mocha，base64→UTF-8）"
mkdir -p "$HOME/.config"
[ -f "$HOME/.config/starship.toml" ] && cp -a "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak-$stamp" && echo "已备份 -> ~/.config/starship.toml.bak-$stamp"
# 用 base64 嵌入，避免 heredoc/粘贴把 Powerline/Nerd glyph 弄坏成非法 UTF-8
STARSHIP_TOML_B64='
IiRzY2hlbWEiID0gJ2h0dHBzOi8vc3RhcnNoaXAucnMvY29uZmlnLXNjaGVtYS5qc29uJwoKZm9y
bWF0ID0gIiIiClvugrZdKHJlZClcCiRvc1wKJHVzZXJuYW1lXAokaG9zdG5hbWVcClvugrBdKGJn
OnBlYWNoIGZnOnJlZClcCiRkaXJlY3RvcnlcClvugrBdKGJnOnllbGxvdyBmZzpwZWFjaClcCiRn
aXRfYnJhbmNoXAokZ2l0X3N0YXR1c1wKW+6CsF0oZmc6eWVsbG93IGJnOmdyZWVuKVwKJGNcCiRy
dXN0XAokZ29sYW5nXAokbm9kZWpzXAokYnVuXAokcGhwXAokamF2YVwKJGtvdGxpblwKJGhhc2tl
bGxcCiRweXRob25cClvugrBdKGZnOmdyZWVuIGJnOnNhcHBoaXJlKVwKJGNvbmRhXApb7oKwXShm
ZzpzYXBwaGlyZSBiZzpsYXZlbmRlcilcCiR0aW1lXApb7oK0IF0oZmc6bGF2ZW5kZXIpXAokY21k
X2R1cmF0aW9uXAokbGluZV9icmVha1wKJGNoYXJhY3RlciIiIgoKcGFsZXR0ZSA9ICdjYXRwcHVj
Y2luX21vY2hhJwoKW29zXQpkaXNhYmxlZCA9IGZhbHNlCnN0eWxlID0gImJnOnJlZCBmZzpjcnVz
dCIKCltvcy5zeW1ib2xzXQpXaW5kb3dzID0gIu6cjyIKVWJ1bnR1ID0gIvOwlYgiClNVU0UgPSAi
74yUIgpSYXNwYmlhbiA9ICLzsJC/IgpNaW50ID0gIvOwo60iCk1hY29zID0gIvOwgLUiCk1hbmph
cm8gPSAi74ySIgpMaW51eCA9ICLzsIy9IgpHZW50b28gPSAi87CjqCIKRmVkb3JhID0gIvOwo5si
CkFscGluZSA9ICLvjIAiCkFtYXpvbiA9ICLvibAiCkFuZHJvaWQgPSAi7pyOIgpBT1NDID0gIu+M
gSIKQXJjaCA9ICLzsKOHIgpBcnRpeCA9ICLzsKOHIgpDZW50T1MgPSAi74yEIgpEZWJpYW4gPSAi
87CjmiIKUmVkaGF0ID0gIvOxhJsiClJlZEhhdEVudGVycHJpc2UgPSAi87GEmyIKClt1c2VybmFt
ZV0Kc2hvd19hbHdheXMgPSB0cnVlCnN0eWxlX3VzZXIgPSAiYmc6cmVkIGZnOmNydXN0IgpzdHls
ZV9yb290ID0gImJnOnJlZCBmZzpjcnVzdCIKZm9ybWF0ID0gJ1sgJHVzZXJdKCRzdHlsZSknCgpb
ZGlyZWN0b3J5XQpzdHlsZSA9ICJiZzpwZWFjaCBmZzpjcnVzdCIKZm9ybWF0ID0gIlsgJHBhdGgg
XSgkc3R5bGUpIgp0cnVuY2F0aW9uX2xlbmd0aCA9IDMKdHJ1bmNhdGlvbl9zeW1ib2wgPSAi4oCm
LyIKCltkaXJlY3Rvcnkuc3Vic3RpdHV0aW9uc10KIkRvY3VtZW50cyIgPSAi87CImSAiCiJEb3du
bG9hZHMiID0gIu+AmSAiCiJNdXNpYyIgPSAi87CdmiAiCiJQaWN0dXJlcyIgPSAi74C+ICIKIkRl
dmVsb3BlciIgPSAi87CyiyAiCgpbZ2l0X2JyYW5jaF0Kc3ltYm9sID0gIu+QmCIKc3R5bGUgPSAi
Ymc6eWVsbG93Igpmb3JtYXQgPSAnW1sgJHN5bWJvbCAkYnJhbmNoIF0oZmc6Y3J1c3QgYmc6eWVs
bG93KV0oJHN0eWxlKScKCltnaXRfc3RhdHVzXQpzdHlsZSA9ICJiZzp5ZWxsb3ciCmZvcm1hdCA9
ICdbWygkYWxsX3N0YXR1cyRhaGVhZF9iZWhpbmQgKV0oZmc6Y3J1c3QgYmc6eWVsbG93KV0oJHN0
eWxlKScKCltub2RlanNdCnN5bWJvbCA9ICLunJgiCnN0eWxlID0gImJnOmdyZWVuIgpmb3JtYXQg
PSAnW1sgJHN5bWJvbCggJHZlcnNpb24pIF0oZmc6Y3J1c3QgYmc6Z3JlZW4pXSgkc3R5bGUpJwoK
W2J1bl0Kc3ltYm9sID0gIu6dryIKc3R5bGUgPSAiYmc6Z3JlZW4iCmZvcm1hdCA9ICdbWyAkc3lt
Ym9sKCAkdmVyc2lvbikgXShmZzpjcnVzdCBiZzpncmVlbildKCRzdHlsZSknCgpbY10Kc3ltYm9s
ID0gIu6YniAiCnN0eWxlID0gImJnOmdyZWVuIgpmb3JtYXQgPSAnW1sgJHN5bWJvbCggJHZlcnNp
b24pIF0oZmc6Y3J1c3QgYmc6Z3JlZW4pXSgkc3R5bGUpJwoKW3J1c3RdCnN5bWJvbCA9ICLunqgi
CnN0eWxlID0gImJnOmdyZWVuIgpmb3JtYXQgPSAnW1sgJHN5bWJvbCggJHZlcnNpb24pIF0oZmc6
Y3J1c3QgYmc6Z3JlZW4pXSgkc3R5bGUpJwoKW2dvbGFuZ10Kc3ltYm9sID0gIu6YpyIKc3R5bGUg
PSAiYmc6Z3JlZW4iCmZvcm1hdCA9ICdbWyAkc3ltYm9sKCAkdmVyc2lvbikgXShmZzpjcnVzdCBi
ZzpncmVlbildKCRzdHlsZSknCgpbcGhwXQpzeW1ib2wgPSAi7piIIgpzdHlsZSA9ICJiZzpncmVl
biIKZm9ybWF0ID0gJ1tbICRzeW1ib2woICR2ZXJzaW9uKSBdKGZnOmNydXN0IGJnOmdyZWVuKV0o
JHN0eWxlKScKCltqYXZhXQpzeW1ib2wgPSAi7omWICIKc3R5bGUgPSAiYmc6Z3JlZW4iCmZvcm1h
dCA9ICdbWyAkc3ltYm9sKCAkdmVyc2lvbikgXShmZzpjcnVzdCBiZzpncmVlbildKCRzdHlsZSkn
Cgpba290bGluXQpzeW1ib2wgPSAi7pi0IgpzdHlsZSA9ICJiZzpncmVlbiIKZm9ybWF0ID0gJ1tb
ICRzeW1ib2woICR2ZXJzaW9uKSBdKGZnOmNydXN0IGJnOmdyZWVuKV0oJHN0eWxlKScKCltoYXNr
ZWxsXQpzeW1ib2wgPSAi7pifIgpzdHlsZSA9ICJiZzpncmVlbiIKZm9ybWF0ID0gJ1tbICRzeW1i
b2woICR2ZXJzaW9uKSBdKGZnOmNydXN0IGJnOmdyZWVuKV0oJHN0eWxlKScKCltweXRob25dCnN5
bWJvbCA9ICLumIYiCnN0eWxlID0gImJnOmdyZWVuIgpmb3JtYXQgPSAnW1sgJHN5bWJvbCggJHZl
cnNpb24pKFwoIyR2aXJ0dWFsZW52XCkpIF0oZmc6Y3J1c3QgYmc6Z3JlZW4pXSgkc3R5bGUpJwoK
W2RvY2tlcl9jb250ZXh0XQpzeW1ib2wgPSAi74yIIgpzdHlsZSA9ICJiZzpzYXBwaGlyZSIKZm9y
bWF0ID0gJ1tbICRzeW1ib2woICRjb250ZXh0KSBdKGZnOmNydXN0IGJnOnNhcHBoaXJlKV0oJHN0
eWxlKScKCltjb25kYV0Kc3ltYm9sID0gIiDvhIwgIgpzdHlsZSA9ICJmZzpjcnVzdCBiZzpzYXBw
aGlyZSIKZm9ybWF0ID0gJ1skc3ltYm9sJGVudmlyb25tZW50IF0oJHN0eWxlKScKaWdub3JlX2Jh
c2UgPSBmYWxzZQoKW3RpbWVdCmRpc2FibGVkID0gZmFsc2UKdGltZV9mb3JtYXQgPSAiJVIiCnN0
eWxlID0gImJnOmxhdmVuZGVyIgpmb3JtYXQgPSAnW1sg75C6ICR0aW1lIF0oZmc6Y3J1c3QgYmc6
bGF2ZW5kZXIpXSgkc3R5bGUpJwoKW2xpbmVfYnJlYWtdCmRpc2FibGVkID0gdHJ1ZQoKW2NoYXJh
Y3Rlcl0KZGlzYWJsZWQgPSBmYWxzZQpzdWNjZXNzX3N5bWJvbCA9ICdb4p2vXShib2xkIGZnOmdy
ZWVuKScKZXJyb3Jfc3ltYm9sID0gJ1vina9dKGJvbGQgZmc6cmVkKScKdmltY21kX3N5bWJvbCA9
ICdb4p2uXShib2xkIGZnOmdyZWVuKScKdmltY21kX3JlcGxhY2Vfb25lX3N5bWJvbCA9ICdb4p2u
XShib2xkIGZnOmxhdmVuZGVyKScKdmltY21kX3JlcGxhY2Vfc3ltYm9sID0gJ1vina5dKGJvbGQg
Zmc6bGF2ZW5kZXIpJwp2aW1jbWRfdmlzdWFsX3N5bWJvbCA9ICdb4p2uXShib2xkIGZnOnllbGxv
dyknCgpbY21kX2R1cmF0aW9uXQpzaG93X21pbGxpc2Vjb25kcyA9IHRydWUKZm9ybWF0ID0gIu6r
tCBpbiAkZHVyYXRpb24gIgpzdHlsZSA9ICJiZzpsYXZlbmRlciIKZGlzYWJsZWQgPSB0cnVlCnNo
b3dfbm90aWZpY2F0aW9ucyA9IHRydWUKbWluX3RpbWVfdG9fbm90aWZ5ID0gNDUwMDAKCltwYWxl
dHRlcy5jYXRwcHVjY2luX21vY2hhXQpyb3Nld2F0ZXIgPSAiI2Y1ZTBkYyIKZmxhbWluZ28gPSAi
I2YyY2RjZCIKcGluayA9ICIjZjVjMmU3IgptYXV2ZSA9ICIjY2JhNmY3IgpyZWQgPSAiI2YzOGJh
OCIKbWFyb29uID0gIiNlYmEwYWMiCnBlYWNoID0gIiNmYWIzODciCnllbGxvdyA9ICIjZjllMmFm
IgpncmVlbiA9ICIjYTZlM2ExIgp0ZWFsID0gIiM5NGUyZDUiCnNreSA9ICIjODlkY2ViIgpzYXBw
aGlyZSA9ICIjNzRjN2VjIgpibHVlID0gIiM4OWI0ZmEiCmxhdmVuZGVyID0gIiNiNGJlZmUiCnRl
eHQgPSAiI2NkZDZmNCIKc3VidGV4dDEgPSAiI2JhYzJkZSIKc3VidGV4dDAgPSAiI2E2YWRjOCIK
b3ZlcmxheTIgPSAiIzkzOTliMiIKb3ZlcmxheTEgPSAiIzdmODQ5YyIKb3ZlcmxheTAgPSAiIzZj
NzA4NiIKc3VyZmFjZTIgPSAiIzU4NWI3MCIKc3VyZmFjZTEgPSAiIzQ1NDc1YSIKc3VyZmFjZTAg
PSAiIzMxMzI0NCIKYmFzZSA9ICIjMWUxZTJlIgptYW50bGUgPSAiIzE4MTgyNSIKY3J1c3QgPSAi
IzExMTExYiIKCltwYWxldHRlcy5jYXRwcHVjY2luX2ZyYXBwZV0Kcm9zZXdhdGVyID0gIiNmMmQ1
Y2YiCmZsYW1pbmdvID0gIiNlZWJlYmUiCnBpbmsgPSAiI2Y0YjhlNCIKbWF1dmUgPSAiI2NhOWVl
NiIKcmVkID0gIiNlNzgyODQiCm1hcm9vbiA9ICIjZWE5OTljIgpwZWFjaCA9ICIjZWY5Zjc2Igp5
ZWxsb3cgPSAiI2U1Yzg5MCIKZ3JlZW4gPSAiI2E2ZDE4OSIKdGVhbCA9ICIjODFjOGJlIgpza3kg
PSAiIzk5ZDFkYiIKc2FwcGhpcmUgPSAiIzg1YzFkYyIKYmx1ZSA9ICIjOGNhYWVlIgpsYXZlbmRl
ciA9ICIjYmFiYmYxIgp0ZXh0ID0gIiNjNmQwZjUiCnN1YnRleHQxID0gIiNiNWJmZTIiCnN1YnRl
eHQwID0gIiNhNWFkY2UiCm92ZXJsYXkyID0gIiM5NDljYmIiCm92ZXJsYXkxID0gIiM4MzhiYTci
Cm92ZXJsYXkwID0gIiM3Mzc5OTQiCnN1cmZhY2UyID0gIiM2MjY4ODAiCnN1cmZhY2UxID0gIiM1
MTU3NmQiCnN1cmZhY2UwID0gIiM0MTQ1NTkiCmJhc2UgPSAiIzMwMzQ0NiIKbWFudGxlID0gIiMy
OTJjM2MiCmNydXN0ID0gIiMyMzI2MzQiCgpbcGFsZXR0ZXMuY2F0cHB1Y2Npbl9sYXR0ZV0Kcm9z
ZXdhdGVyID0gIiNkYzhhNzgiCmZsYW1pbmdvID0gIiNkZDc4NzgiCnBpbmsgPSAiI2VhNzZjYiIK
bWF1dmUgPSAiIzg4MzllZiIKcmVkID0gIiNkMjBmMzkiCm1hcm9vbiA9ICIjZTY0NTUzIgpwZWFj
aCA9ICIjZmU2NDBiIgp5ZWxsb3cgPSAiI2RmOGUxZCIKZ3JlZW4gPSAiIzQwYTAyYiIKdGVhbCA9
ICIjMTc5Mjk5Igpza3kgPSAiIzA0YTVlNSIKc2FwcGhpcmUgPSAiIzIwOWZiNSIKYmx1ZSA9ICIj
MWU2NmY1IgpsYXZlbmRlciA9ICIjNzI4N2ZkIgp0ZXh0ID0gIiM0YzRmNjkiCnN1YnRleHQxID0g
IiM1YzVmNzciCnN1YnRleHQwID0gIiM2YzZmODUiCm92ZXJsYXkyID0gIiM3YzdmOTMiCm92ZXJs
YXkxID0gIiM4YzhmYTEiCm92ZXJsYXkwID0gIiM5Y2EwYjAiCnN1cmZhY2UyID0gIiNhY2IwYmUi
CnN1cmZhY2UxID0gIiNiY2MwY2MiCnN1cmZhY2UwID0gIiNjY2QwZGEiCmJhc2UgPSAiI2VmZjFm
NSIKbWFudGxlID0gIiNlNmU5ZWYiCmNydXN0ID0gIiNkY2UwZTgiCgpbcGFsZXR0ZXMuY2F0cHB1
Y2Npbl9tYWNjaGlhdG9dCnJvc2V3YXRlciA9ICIjZjRkYmQ2IgpmbGFtaW5nbyA9ICIjZjBjNmM2
IgpwaW5rID0gIiNmNWJkZTYiCm1hdXZlID0gIiNjNmEwZjYiCnJlZCA9ICIjZWQ4Nzk2IgptYXJv
b24gPSAiI2VlOTlhMCIKcGVhY2ggPSAiI2Y1YTk3ZiIKeWVsbG93ID0gIiNlZWQ0OWYiCmdyZWVu
ID0gIiNhNmRhOTUiCnRlYWwgPSAiIzhiZDVjYSIKc2t5ID0gIiM5MWQ3ZTMiCnNhcHBoaXJlID0g
IiM3ZGM0ZTQiCmJsdWUgPSAiIzhhYWRmNCIKbGF2ZW5kZXIgPSAiI2I3YmRmOCIKdGV4dCA9ICIj
Y2FkM2Y1IgpzdWJ0ZXh0MSA9ICIjYjhjMGUwIgpzdWJ0ZXh0MCA9ICIjYTVhZGNiIgpvdmVybGF5
MiA9ICIjOTM5YWI3IgpvdmVybGF5MSA9ICIjODA4N2EyIgpvdmVybGF5MCA9ICIjNmU3MzhkIgpz
dXJmYWNlMiA9ICIjNWI2MDc4IgpzdXJmYWNlMSA9ICIjNDk0ZDY0IgpzdXJmYWNlMCA9ICIjMzYz
YTRmIgpiYXNlID0gIiMyNDI3M2EiCm1hbnRsZSA9ICIjMWUyMDMwIgpjcnVzdCA9ICIjMTgxOTI2
IgoKW2hvc3RuYW1lXQpzc2hfb25seSA9IGZhbHNlCnRyaW1fYXQgPSAiLiIKc3R5bGUgPSAiYmc6
cmVkIGZnOmNydXN0Igpmb3JtYXQgPSAnW0AkaG9zdG5hbWUgXSgkc3R5bGUpJw==
'
printf '%s' "$STARSHIP_TOML_B64" | tr -d ' \n\t\r' | base64 -d > "$HOME/.config/starship.toml"
python3 - "$HOME/.config/starship.toml" <<'PYCHECK'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
raw = p.read_bytes()
try:
    text = raw.decode("utf-8")
except UnicodeDecodeError as e:
    print(f"[FATAL] starship.toml 非法 UTF-8: {e}", file=sys.stderr)
    sys.exit(1)
tomllib = None
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib  # type: ignore
    except ImportError:
        tomllib = None
if tomllib is not None:
    cfg = tomllib.loads(text)
    fmt = cfg.get("format") or ""
    if "$os" not in fmt:
        print("[FATAL] starship.toml format 缺少 $os（可能解码损坏或回退到默认）", file=sys.stderr)
        sys.exit(1)
    print(f"starship.toml OK: {len(raw)} bytes, UTF-8, format 含 $os, palette={cfg.get('palette')}")
else:
    # Python < 3.11 且无 tomli：退化为 UTF-8 + 关键字段文本检查
    if "$os" not in text or "catppuccin_mocha" not in text:
        print("[FATAL] starship.toml 缺少 $os 或 catppuccin_mocha（无 tomllib/tomli，文本校验失败）", file=sys.stderr)
        sys.exit(1)
    print(f"starship.toml OK: {len(raw)} bytes, UTF-8 (no tomllib/tomli; text check $os + catppuccin_mocha)")
PYCHECK

step "7/7 写入新 ~/.zshrc 并合并保留字段"
cat << 'EOF' > "$ZSHRC"
setopt no_nomatch
autoload -Uz compinit && compinit

# 代替 OMZ 嘅雙擊 ESC 加 sudo 功能
bindkey -M emacs '\e\e' sudo-command-line
bindkey -M vicmd '\e\e' sudo-command-line
sudo-command-line() {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    elif [[ $BUFFER == $EDITOR\ * ]]; then
        LBUFFER="${LBUFFER#$EDITOR }"
        LBUFFER="sudoedit $LBUFFER"
    elif [[ $BUFFER == sudoedit\ * ]]; then
        LBUFFER="${LBUFFER#sudoedit }"
        LBUFFER="$EDITOR $LBUFFER"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line

# 常用 Git Alias
alias gst='git status'
alias gcam='git commit -a -m'
alias gco='git checkout'

# 載入 Zoxide (目錄跳轉)
eval "$(zoxide init zsh)"

# 載入神級插件
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
EOF
if [ -s "$PRESERVE" ]; then
  {
    echo ""
    echo "# BEGIN preserved-from-old-zshrc ($stamp)"
    cat "$PRESERVE"
    echo "# END preserved-from-old-zshrc"
  } >> "$ZSHRC"
  echo "已合并 $(wc -l < "$PRESERVE") 行保留字段"
fi
cat << 'EOF' >> "$ZSHRC"

# 啟動 Starship
eval "$(starship init zsh)"
EOF

if zsh -n "$ZSHRC"; then echo "~/.zshrc 语法检查 OK"; else echo "⚠️ ~/.zshrc 语法有问题，请检查保留块" >&2; fi

ZSH_BIN=$(command -v zsh)
CUR_SHELL=$(getent passwd "$(id -un)" | cut -d: -f7)
if [ "$CUR_SHELL" != "$ZSH_BIN" ]; then
  echo "切换预设 shell：$CUR_SHELL -> $ZSH_BIN"
  chsh_ok=0
  if [ "$(id -u)" -eq 0 ]; then
    if chsh -s "$ZSH_BIN"; then chsh_ok=1; fi || true
  else
    # 优先用 sudo chsh（免密 sudo 更稳），避免 chsh 向管道 stdin 要登录密码
    if $SUDO chsh -s "$ZSH_BIN" "$(id -un)" </dev/null 2>/dev/null; then
      chsh_ok=1
    elif [ -r /dev/tty ] && [ -w /dev/tty ]; then
      if chsh -s "$ZSH_BIN" </dev/tty 2>/dev/null; then chsh_ok=1; fi || true
    fi
  fi
  if [ "$chsh_ok" -ne 1 ]; then
    echo "⚠️ chsh 未能自动切换（容器／受限环境常见）。手动执行：chsh -s $(command -v zsh)"
  fi
else
  echo "预设 shell 已经係 zsh"
fi

cat << EOF

✅ 完成！还原方法：
  cp ~/.zshrc.bak-$stamp ~/.zshrc
  [ -d ~/.oh-my-zsh.bak-$stamp ] && mv ~/.oh-my-zsh.bak-$stamp ~/.oh-my-zsh
  [ -f ~/.config/starship.toml.bak-$stamp ] && mv ~/.config/starship.toml.bak-$stamp ~/.config/starship.toml
保留字段文件：$PRESERVE
EOF

echo "即将进入 zsh（或者重新登入）..."
# curl|bash 时 stdin 是已关闭的管道（EOF），直接 exec zsh -i 会立刻退出；改接 /dev/tty
if [ -t 1 ] && ( : </dev/tty ) 2>/dev/null; then
  exec </dev/tty
  exec "$ZSH_BIN" -i
else
  echo "当前非交互终端，重新登入或执行 exec zsh 即可生效。"
fi
}

main "$@"
