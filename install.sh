#!/usr/bin/env bash
# dms-hermes-monitor 安装脚本
# 用法: ./install.sh
# 卸载: ./uninstall.sh
set -euo pipefail

PLUGIN_DIR="$HOME/.config/DankMaterialShell/plugins/HermesMonitor"
BIN_DIR="$HOME/.local/bin"
SRC="$(cd "$(dirname "$0")" && pwd)"

echo "==> dms-hermes-monitor 安装"

# 依赖检查
MISSING=()
command -v python3 >/dev/null || MISSING+=("python3")
command -v curl >/dev/null || MISSING+=("curl")
command -v ss >/dev/null || MISSING+=("iproute2 (ss)")
if [ ${#MISSING[@]} -gt 0 ]; then
  echo "缺少依赖: ${MISSING[*]}"; exit 1
fi
if ! command -v dms >/dev/null; then
  echo "⚠ 未找到 dms (DankMaterialShell)。本插件是 DMS widget, 没有 DMS 无法显示。继续安装, 但你需要先装好 DMS。"
fi

# 1. 采集器
install -Dm755 "$SRC/collector/hermes-bar-status" "$BIN_DIR/hermes-bar-status"
echo "  ✓ 采集器 → $BIN_DIR/hermes-bar-status"

# 2. 插件
mkdir -p "$PLUGIN_DIR"
install -m644 "$SRC/plugin/plugin.json" "$PLUGIN_DIR/plugin.json"
install -m644 "$SRC/plugin/HermesWidget.qml" "$PLUGIN_DIR/HermesWidget.qml"
echo "  ✓ 插件 → $PLUGIN_DIR/"

# 3. 可选: 加入顶栏 (仅在 settings.json 存在且未包含本插件时)
SETTINGS="$HOME/.config/DankMaterialShell/settings.json"
if [ -f "$SETTINGS" ] && ! grep -q '"hermesMonitor"' "$SETTINGS"; then
  python3 - "$SETTINGS" <<'EOF'
import json, sys
p = sys.argv[1]
with open(p) as f:
    cfg = json.load(f)
try:
    bar = cfg["barConfigs"][0]
    w = bar.setdefault("rightWidgets", [])
    if "hermesMonitor" not in w:
        w.append("hermesMonitor")
        with open(p, "w") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
        print("  ✓ 已加入顶栏右侧 (rightWidgets)")
except Exception as e:
    print(f"  ! 未能自动加入顶栏 ({e}); 请在 DMS 设置里手动把 hermesMonitor 加到 bar", file=sys.stderr)
EOF
fi

# 4. 首次扫描 & 启用 (dms 在运行时才有效)
if command -v dms >/dev/null && dms ipc call plugin-scan scan >/dev/null 2>&1; then
  dms ipc call plugins enable hermesMonitor >/dev/null 2>&1 || true
  dms ipc call plugins reload hermesMonitor >/dev/null 2>&1 || true
  echo "  ✓ 已注册并启用插件"
else
  echo "  ! dms 未运行或 scan 失败 — 重启 DMS 后插件会被自动发现, 再在 DMS 设置里启用 hermesMonitor"
fi

echo
echo "==> 完成。首次运行会自动采样网络/余额, 面板内容 ~10 秒内出现。"
echo "    余额功能需要在 ~/.hermes/.env 配置 DEEPSEEK_API_KEY (可选)。"
echo "    卸载: $(dirname "$0")/uninstall.sh"
