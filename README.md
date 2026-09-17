# dms-hermes-monitor

[DankMaterialShell (DMS)](https://danklinux.com/docs/dankmaterialshell/plugin-development) 顶栏插件：Hermes Agent 会话监控 + 多通道模型余额 + Clash 流量面板。

![screenshot](assets/screenshot.png)

## 功能

**顶栏 pill**
- 显示当前对话实际使用的模型（从 Hermes 调用记录实时读取，切模型即切显示）+ 当前通道余额；从未调用时显示「待使用」
- 答完一轮后模型名前亮小绿点（常亮到下次提问）

**弹出面板**（点击 pill）
- 余额卡片：大数字 + 走势图（自适应量程）+ 状态标签（正常/偏低/欠费/不支持）+ 可用天数估算
- 通道余额：所有已配置通道一览，无公开余额 API 的通道显示「不支持」；新通道只需在采集器 `BALANCE_PRESETS` 加一行；**点击任意行可在上方余额卡片预览该通道，再点返回当前通道**
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

插件分两层：**QML 层**只负责界面和交互，**采集器**（一个独立的 Python 脚本）负责收集所有数据。QML 每 5 秒运行一次采集器，读取它输出的单行 JSON 来刷新界面——界面逻辑与数据采集完全解耦，采集器挂了也只是数据停更，不影响状态栏本身。

**采集器的数据来源**：

| 数据 | 来源 | 说明 |
|---|---|---|
| 当前模型 / 会话 / 用量 | `~/.hermes/state.db`（只读） | 从 Hermes 的调用记录取实际使用的模型，而非静态配置 |
| 回合结束检测（绿点） | 同上 | 检测到一轮回答完成即触发余额刷新 |
| 余额 | `api.deepseek.com/user/balance` | 官方免费记账接口，不消耗 token；3 分钟缓存 + 回合结束即刷 |
| 全局网速 | `/proc/net/dev` 两次采样差分 | 全网卡口径 |
| 每进程流量 | `ss -tinHp` 连接字节数差分 | 按进程聚合，无需 root |
| API 密钥 | `~/.hermes/.env` | 只读取，不修改、不上传，不出现在任何输出 |

**缓存**：所有采样数据落在 `~/.cache/hermes-bar/`（余额历史、网络波形、进程流量快照），面板关闭期间数据持续累积，重新打开即有完整曲线。

## 已知限制

- 进程流量排行只能看到**当前用户**的进程连接；其他用户/root 进程与已关闭的 TIME-WAIT 连接不计入（全局速率仍准确，来自 `/proc/net/dev`）
- FlClash 未开启「外部控制」时无法获取节点名，仅显示存活状态
- 面板为 DMS 插件，仅适用于运行 DankMaterialShell 的 Wayland 环境（niri 等）

## 许可

MIT
