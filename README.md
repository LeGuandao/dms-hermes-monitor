# dms-hermes-monitor

[DankMaterialShell (DMS)](https://danklinux.com/docs/dankmaterialshell/plugin-development) 顶栏插件：Hermes Agent 会话监控 + 多通道模型余额 + Clash 流量面板。

![screenshot](assets/screenshot.png)

## 功能

**顶栏 pill**
- 显示当前对话实际使用的模型（从 Hermes 调用记录实时读取，切模型即切显示）+ 当前通道余额；从未调用时显示「待使用」
- 答完一轮后模型名前亮小绿点（常亮到下次提问）

**弹出面板**（点击 pill）
- 余额英雄卡：大数字 + 走势图（自适应量程）+ 状态 chip（正常/偏低/欠费/不支持）+ 可用天数估算
- 通道余额：所有已配置通道一览，无公开余额 API 的通道显示「不支持」；新通道只需在采集器 `BALANCE_PRESETS` 加一行；**点击任意行可在英雄卡预览该通道余额，再点返回当前通道**
- 今日 Hermes：对话数 / token 量 / 估算花费
- Clash 流量：实时下载/上传速率波形图（4s 采样，约 8 分钟窗口，下载绿色面积 + 上传蓝色曲线，量程自适应）+ 按进程聚合的实时流量排行（前 5，基于 `ss -tinHp` 差分，无需 root）
- 系统卡：磁盘 / 待更新包数
- 最近对话：近 24h 会话列表 + 活跃度

## 安装

```bash
git clone https://github.com/LeGuandao/dms-hermes-monitor.git
cd dms-hermes-monitor
./install.sh
```

脚本会：

1. 安装采集器到 `~/.local/bin/hermes-bar-status`
2. 安装插件到 `~/.config/DankMaterialShell/plugins/HermesMonitor/`
3. 自动把 `hermesMonitor` 加入 DMS 顶栏右侧（如 `settings.json` 存在）
4. 注册并启用插件（DMS 运行中时），否则重启 DMS 后在设置里启用

**要求**：运行中的 [DMS](https://danklinux.com)（Quickshell）、`python3`、`curl`、`iproute2`（`ss` 命令，用于进程流量）。

**余额功能（可选）**：在 `~/.hermes/.env` 配置 `DEEPSEEK_API_KEY`。没有它其余功能照常，余额显示「未知/不支持」。当前预设：

| 通道 | 余额查询 | 说明 |
|---|---|---|
| DeepSeek | ✅ | 官方免费接口，无需消耗 token |
| GLM·智谱 (zai) | ❌ 不支持 | 智谱无公开余额 API |

## 卸载

```bash
./uninstall.sh
```

会移除插件、采集器和 `~/.cache/hermes-bar/` 缓存。

## 工作原理

```
┌─ DMS bar pill / popout (QML) ────────────────┐
│  每 5s 执行一次采集器，读单行 JSON 渲染          │
└──────────────┬───────────────────────────────┘
               ↓
┌─ collector/hermes-bar-status (python3) ──────┐
│ · ~/.hermes/state.db → 模型/会话/用量/回合结束检测 │
│ · api.deepseek.com/user/balance → 余额（免费接口）│
│ · /proc/net/dev + ss -tinHp → 全局速率 + 每进程流量│
│ · ~/.hermes/.env 只读取，不修改、不上传          │
└──────────────────────────────────────────────┘
```

- 采集器输出单行 JSON，缓存在 `~/.cache/hermes-bar/`（余额 3 分钟 TTL + 每轮对话答完即刷、网络 4s 采样、每进程流量 5s 差分）
- API 密钥只在运行时读取用于调余额接口，不会出现在任何输出或日志里

## 已知限制

- 进程流量排行只能看到**当前用户**的进程连接；其他用户/root 进程与已关闭的 TIME-WAIT 连接不计入（全局速率仍准确，来自 `/proc/net/dev`）
- FlClash 未开启「外部控制」时无法获取节点名，仅显示存活状态
- 面板为 DMS 插件，仅适用于运行 DankMaterialShell 的 Wayland 环境（niri 等）

## 许可

MIT
