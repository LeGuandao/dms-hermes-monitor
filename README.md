# dms-hermes-monitor

[DankMaterialShell (DMS)](https://danklinux.com/docs/dankmaterialshell/plugin-development) 顶栏插件:Hermes Agent 会话监控 + 多通道模型余额 + Clash 流量面板。

![screenshot](assets/screenshot.png)

## 功能

**顶栏 pill**
- 显示当前对话实际使用的模型(从 Hermes 调用记录实时读取, 切模型即切显示) + 当前通道余额; 从未调用时显示「待使用」
- 答完一轮后模型名前亮小绿点(常亮到下次提问)

**弹出面板**(点击 pill)
- 余额英雄卡: 大数字 + 走势图(自适应量程) + 状态 chip(正常/偏低/欠费/不支持) + 可用天数估算; 点击「通道余额」里任意行可预览该通道, 再点返回
- 通道余额: 所有已配置通道一览, 无公开余额 API 的通道显示「不支持」; 新通道只需在采集器 `BALANCE_PRESETS` 加一行
- 今日 Hermes: 对话数 / token 量 / 估算花费
- Clash 流量: 实时下载/上传速率波形图(4s 采样, 8 分钟窗口) + 按进程聚合的实时流量排行(前 5, 基于 `ss -tinHp` 差分, 无 root)
- 系统卡: 磁盘 / 待更新包数
- 最近对话: 近 24h 会话列表 + 活跃度

## 安装

```bash
git clone https://github.com/<you>/dms-hermes-monitor.git
cd dms-hermes-monitor
./install.sh
```

要求: 运行中的 [DMS](https://danklinux.com) (Quickshell)、`python3`、`curl`、`iproute2`。

余额功能(可选): `~/.hermes/.env` 里配 `DEEPSEEK_API_KEY`。没有它其余功能照常, 余额显示「未知/不支持」。

## 卸载

```bash
./uninstall.sh
```

## 工作原理

```
┌─ DMS bar pill / popout (QML) ────────────┐
│ 每 5s 执行一次采集器, 读单行 JSON 渲染     │
└──────────────┬───────────────────────────┘
               ↓
┌─ collector/hermes-bar-status (python3) ──┐
│ · ~/.hermes/state.db → 模型/会话/用量/回合结束检测 │
│ · api.deepseek.com/user/balance → 余额 (免费接口) │
│ · /proc/net/dev + ss -tinHp → 全局速率 + 每进程流量 │
│ · ~/.hermes/.env 只读取, 不改不传           │
└──────────────────────────────────────────┘
```

采集器输出单行 JSON, 缓存在 `~/.cache/hermes-bar/`(余额 3 分钟 TTL + 答完即刷、网络 4s 采样)。密钥只被读取用于调余额接口, 不会出现在任何输出里。

## 许可

MIT
