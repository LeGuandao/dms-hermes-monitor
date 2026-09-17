#!/usr/bin/env bash
# dms-hermes-monitor 卸载
set -euo pipefail
rm -rf "$HOME/.config/DankMaterialShell/plugins/HermesMonitor"
rm -f "$HOME/.local/bin/hermes-bar-status"
rm -rf "$HOME/.cache/hermes-bar"   # 采样/余额历史缓存
echo "已卸载 (含缓存)。若顶栏仍显示, 重启 DMS 或在设置中移除 hermesMonitor。"
