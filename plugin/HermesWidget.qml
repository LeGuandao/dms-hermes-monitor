import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "hermes-monitor"

    popoutWidth: 440
    popoutHeight: root.convHeight() + root.balCardHeight() + 570

    // ================= 运行时数据 =================
    property var data: ({
        model: "", provider: "", provider_label: "",
        balance: null, currency: "CNY", balance_stale: false,
        latency_ms: null, hist: [], spend24h: null, days_left: null,
        alert: { level: null, changed: false },
        tasks: { todo: 0, running: 0, done: 0, failed: 0 },
        running: [], proxy_ok: false, node: null,
        net: { rx_bps: null, tx_bps: null },
        today: null, disk: null, updates: null, sessions: [],
        state: "idle",
        last_error: "", ts: 0
    })
    readonly property string collectorBin: Quickshell.env("HOME") + "/.local/bin/hermes-bar-status"

    // ================= 余额预览切换 =================
    // 空串 = 跟随当前通道; 否则 = 用户点选的 provider(仅影响面板预览, 不影响 pill)
    property string balanceViewProvider: ""
    function viewEntry() {
        const list = root.data.balances || []
        if (root.balanceViewProvider !== "") {
            const sel = list.find(e => e.provider === root.balanceViewProvider)
            if (sel)
                return sel
        }
        return list.find(e => e.provider === (root.data.provider || "")) || list[0] || null
    }
    function viewSupported() {
        const e = root.viewEntry()
        return e ? e.supported !== false : false
    }
    function viewBalNum() {
        const e = root.viewEntry()
        if (!e || e.balance === null || e.balance === undefined)
            return null
        return Number(e.balance)
    }
    function viewLabel() {
        const e = root.viewEntry()
        return e ? e.label : "—"
    }
    function viewIsCurrent() {
        const e = root.viewEntry()
        return e ? e.provider === (root.data.provider || "") : false
    }

    // ================= 数据刷新 =================
    function applyData(stdout) {
        if (!stdout)
            return
        let d
        try {
            d = JSON.parse(stdout)
        } catch (e) {
            return
        }
        root.data = d
        root.lastRefresh = Qt.formatTime(new Date(), "HH:mm")
        if (d.alert && d.alert.changed) {
            if (d.alert.level === "critical")
                ToastService.showError("DeepSeek 余额欠费", "余额为负，API 将不可用，请尽快充值")
            else if (d.alert.level === "low")
                ToastService.showInfo("DeepSeek 余额偏低", "余额低于 ¥5，注意及时充值")
        }
    }

    function refresh() {
        Proc.runCommand(
            "hermesMonitor.poll",
            [root.collectorBin],
            (stdout, exitCode) => {
                if (!root || exitCode !== 0)
                    return
                root.applyData(stdout)
            }, 100, 30000, root)
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ================= 工具函数 =================
    function balNum() {
        const b = root.data.balance
        return (b === null || b === undefined || b === "") ? null : Number(b)
    }
    function fmtMoney(b) {
        if (b === null || b === undefined)
            return "¥--"
        return (root.data.currency === "USD" ? "$" : "¥") + Number(b).toFixed(2)
    }
    function balColor() {
        const b = root.balNum()
        if (b === null) return Theme.surfaceVariantText
        if (b < 0) return Theme.error
        if (b < 5) return Theme.warning
        return Theme.success
    }
    function balWord() {
        if (!root.balSupported())
            return "不支持"
        const b = root.balNum()
        if (b === null) return "未知"
        if (b < 0) return "欠费"
        if (b < 5) return "偏低"
        return "正常"
    }
    function taskTotal() {
        const t = root.data.tasks
        return (t.todo || 0) + (t.running || 0) + (t.done || 0) + (t.failed || 0)
    }
    function convCount() {
        return (root.data.sessions && root.data.sessions.length) ? Math.min(root.data.sessions.length, 4) : 0
    }
    function convHeight() {
        const n = root.convCount()
        return n === 0 ? 36 : (38 + n * 22)
    }
    function relTime(ts) {
        if (!ts)
            return "—"
        const d = Date.now() / 1000 - ts
        if (d < 60) return "刚刚"
        if (d < 3600) return Math.floor(d / 60) + " 分钟前"
        if (d < 86400) return Math.floor(d / 3600) + " 小时前"
        return Math.floor(d / 86400) + " 天前"
    }
    function stateIcon() {
        if (root.data.state === "needs_user") return "back_hand"
        if (root.data.state === "working") return "progress_activity"
        if (root.data.state === "done") return "task_alt"
        return "bolt"
    }
    function stateColor() {
        if (root.data.state === "needs_user") return Theme.warning
        if (root.data.state === "working") return Theme.primary
        if (root.data.state === "done") return Theme.success
        return Theme.primary
    }
    function balTextColor() {
        const b = root.balNum()
        if (b !== null && b < 0) return Theme.error
        if (b !== null && b < 5) return Theme.warning
        return Theme.surfaceVariantText
    }
    function balSupported() {
        return root.data.balance_supported !== false
    }
    function pillMoneyText() {
        if (!root.balSupported())
            return "不支持"
        return root.fmtMoney(root.balNum())
    }
    function pillMoneyColor() {
        if (!root.balSupported())
            return Theme.surfaceVariantText
        return root.balTextColor()
    }
    function balCardHeight() {
        const n = (root.data.balances && root.data.balances.length) ? root.data.balances.length : 1
        return 44 + n * 26
    }
    function viewMoneyText() {
        if (!root.viewSupported())
            return "不支持"
        const b = root.viewBalNum()
        if (b === null)
            return "¥--"
        const e = root.viewEntry()
        return (e && e.currency === "USD" ? "$" : "¥") + b.toFixed(2)
    }
    function viewMoneyColor() {
        const b = root.viewBalNum()
        if (b === null)
            return Theme.surfaceVariantText
        if (b < 0) return Theme.error
        if (b < 5) return Theme.warning
        return Theme.success
    }
    function viewWord() {
        if (!root.viewSupported())
            return "不支持"
        const b = root.viewBalNum()
        if (b === null) return "未知"
        if (b < 0) return "欠费"
        if (b < 5) return "偏低"
        return "正常"
    }
    function viewSubline() {
        if (!root.viewIsCurrent())
            return root.viewSupported() ? "预览模式 · 点击行返回当前通道" : "该通道无余额查询 API"
        let s = ""
        if (root.data.latency_ms !== null && root.data.latency_ms !== undefined)
            s += "API " + root.data.latency_ms + "ms"
        if (root.data.spend24h !== null && root.data.spend24h !== undefined)
            s += (s ? " · " : "") + "24h消耗 ¥" + Number(root.data.spend24h).toFixed(2)
        if (root.data.balance_stale)
            s += (s ? " · " : "") + "缓存"
        return s || "数据采集中…"
    }
    function viewHist() {
        const e = root.viewEntry()
        return (e && e.hist && e.hist.length >= 2) ? e.hist : []
    }
    function chBalText(e) {
        if (!e.supported)
            return "不支持"
        if (e.balance === null || e.balance === undefined)
            return "—"
        return (e.currency === "USD" ? "$" : "¥") + Number(e.balance).toFixed(2)
    }
    function chBalColor(e) {
        if (!e.supported || e.balance === null || e.balance === undefined)
            return Theme.surfaceVariantText
        const b = Number(e.balance)
        if (b < 0) return Theme.error
        if (b < 5) return Theme.warning
        return Theme.success
    }
    function fmtTokens(n) {
        if (n === null || n === undefined) return "—"
        if (n >= 1e9) return (n / 1e9).toFixed(2) + "B"
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
        if (n >= 1e3) return (n / 1e3).toFixed(0) + "k"
        return "" + n
    }
    function fmtRate(bps) {
        if (bps === null || bps === undefined) return "—"
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + "M/s"
        if (bps >= 1024) return (bps / 1024).toFixed(1) + "K/s"
        return bps + "B/s"
    }
    function fmtLast() {
        const t = root.data.today && root.data.today.last_ts
        if (!t) return "—"
        return Qt.formatTime(new Date(t * 1000), "HH:mm")
    }
    function pillText() {
        const t = root.data.tasks
        let extra = ""
        if (t.running > 0) extra += " ▶" + t.running
        if (t.todo > 0) extra += " ⊙" + t.todo
        if (t.failed > 0) extra += " ⚠" + t.failed
        return root.fmtMoney(root.balNum()) + extra
    }

    // ================= Bar pill: 完成点 + 模型名 + 余额 =================
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            Rectangle {
                visible: root.data.state === "done"
                width: 6
                height: 6
                radius: 3
                color: Theme.success
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.data.model || "待使用"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.pillMoneyText()
                font.pixelSize: Theme.fontSizeSmall
                color: root.pillMoneyColor()
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            Rectangle {
                visible: root.data.state === "done"
                width: 6
                height: 6
                radius: 3
                color: Theme.success
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.data.model || "待使用"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.pillMoneyText()
                font.pixelSize: Theme.fontSizeSmall
                color: root.pillMoneyColor()
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ================= 弹出仪表盘 =================
    popoutContent: Component {
        PopoutComponent {
            id: pc

            headerText: "Hermes 仪表盘"
            detailsText: (root.data.model || "—") + "  ·  余额" + root.balWord() + "  ·  上次对话 " + root.fmtLast()
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - pc.headerHeight - pc.detailsHeight - Theme.spacingXL

                Column {
                    id: dash
                    width: parent.width - Theme.spacingL * 2
                    x: Theme.spacingL
                    spacing: Theme.spacingM

                    // ---------- 余额英雄卡 ----------
                    StyledRect {
                        width: parent.width
                        height: 132
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        StyledText {
                            x: Theme.spacingL
                            y: Theme.spacingM
                            text: root.viewLabel() + (root.viewIsCurrent() ? " 余额" : " 余额 (预览)")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingL
                            anchors.top: parent.top
                            anchors.topMargin: Theme.spacingM
                            width: statusChipText.width + Theme.spacingM * 2
                            height: 22
                            radius: 11
                            color: Theme.withAlpha(root.balColor(), 0.15)

                            StyledText {
                                id: statusChipText
                                anchors.centerIn: parent
                                text: root.viewWord()
                                font.pixelSize: Theme.fontSizeSmall
                                color: root.viewMoneyColor()
                            }
                        }

                        StyledText {
                            id: balBigText
                            x: Theme.spacingL
                            y: 40
                            text: root.viewMoneyText()
                            font.pixelSize: 34
                            font.weight: Font.Bold
                            color: root.viewMoneyColor()
                        }

                        StyledText {
                            id: balDaysText
                            visible: root.viewIsCurrent() && root.data.days_left !== null && root.data.days_left !== undefined
                            x: balBigText.x + balBigText.width + 8
                            y: 66
                            text: "可用≈" + (root.data.days_left !== null && root.data.days_left !== undefined ? Number(root.data.days_left).toFixed(1) : "—") + "天"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            x: Theme.spacingL
                            y: 92
                            width: parent.width - 172 - Theme.spacingM - Theme.spacingL - 16
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            // 预览非当前通道时只显示其支持状态; 当前通道才显示 API 延迟/24h 消耗/缓存
                            text: root.viewSubline()
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Canvas {
                            id: balCanvas
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.top: parent.top
                            anchors.topMargin: 44
                            width: 172
                            height: 52
                            renderStrategy: Canvas.Cooperative

                            property var hist: root.viewHist()
                            property color lineColor: root.viewMoneyColor()

                            onHistChanged: requestPaint()
                            onLineColorChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.clearRect(0, 0, width, height)
                                const h = hist
                                if (!h || h.length < 2)
                                    return

                                let mn = h[0]
                                let mx = h[0]
                                for (let i = 1; i < h.length; i++) {
                                    mn = Math.min(mn, h[i])
                                    mx = Math.max(mx, h[i])
                                }
                                let pad = (mx - mn) * 0.2
                                if (pad < 0.01)
                                    pad = 0.01
                                mn -= pad
                                mx += pad

                                const c = root.lineColor
                                const grad = ctx.createLinearGradient(0, 0, 0, height)
                                grad.addColorStop(0, Theme.withAlpha(c, 0.30))
                                grad.addColorStop(1, Theme.withAlpha(c, 0.02))

                                ctx.beginPath()
                                ctx.moveTo(0, height)
                                for (let j = 0; j < h.length; j++) {
                                    const x = (width / (h.length - 1)) * j
                                    const y = height - ((h[j] - mn) / (mx - mn)) * (height - 6) - 3
                                    ctx.lineTo(x, y)
                                }
                                ctx.lineTo(width, height)
                                ctx.closePath()
                                ctx.fillStyle = grad
                                ctx.fill()

                                ctx.beginPath()
                                for (let k = 0; k < h.length; k++) {
                                    const px = (width / (h.length - 1)) * k
                                    const py = height - ((h[k] - mn) / (mx - mn)) * (height - 6) - 3
                                    k === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py)
                                }
                                ctx.strokeStyle = Theme.withAlpha(c, 0.85)
                                ctx.lineWidth = 2
                                ctx.lineJoin = "round"
                                ctx.stroke()
                            }
                        }

                        // 右下角"更新"按钮: 强制刷新余额(跳过缓存)
                        StyledRect {
                            id: balUpdateBtn
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            width: balUpdateRow.width + 20
                            height: 24
                            radius: 12
                            property bool busy: false
                            color: balUpdateMouse.containsMouse ? Theme.primaryHover
                                 : balUpdateBtn.busy ? Theme.surfaceContainerHighest
                                 : Theme.withAlpha(Theme.primary, 0.12)

                            Row {
                                id: balUpdateRow
                                anchors.centerIn: parent
                                spacing: 3
                                DankIcon {
                                    name: "refresh"
                                    size: 12
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: balUpdateBtn.busy ? "更新中" : "更新"
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: balUpdateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (balUpdateBtn.busy)
                                        return
                                    balUpdateBtn.busy = true
                                    Proc.runCommand(
                                        "hermesMonitor.balance.refresh",
                                        [root.collectorBin, "--force"],
                                        (stdout, exitCode) => {
                                            if (balUpdateBtn)
                                                balUpdateBtn.busy = false
                                            if (!root || exitCode !== 0)
                                                return
                                            root.applyData(stdout)
                                            ToastService.showInfo("余额已更新")
                                        }, 0, 30000, root)
                                }
                            }
                        }
                    }

                    // ---------- 通道余额(所有预设通道一览) ----------
                    StyledRect {
                        width: parent.width
                        height: root.balCardHeight()
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        StyledText {
                            x: Theme.spacingM
                            y: Theme.spacingS
                            text: "通道余额"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                        }

                        Column {
                            x: Theme.spacingM
                            y: 34
                            width: parent.width - Theme.spacingM * 2
                            spacing: 4

                            Repeater {
                                model: root.data.balances && root.data.balances.length ? root.data.balances : []

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    Item {
                                        id: chRow
                                        width: parent.width
                                        height: 22

                                        // 选中/悬停高亮
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.leftMargin: -6
                                            anchors.rightMargin: -6
                                            radius: 6
                                            visible: chRowMa.containsMouse || (root.balanceViewProvider === modelData.provider)
                                            color: root.balanceViewProvider === modelData.provider
                                                   ? Theme.withAlpha(Theme.primary, 0.14)
                                                   : Theme.withAlpha(Theme.surfaceText, 0.05)
                                        }

                                        Rectangle {
                                            width: 6
                                            height: 6
                                            radius: 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root.chBalColor(modelData)
                                        }

                                        StyledText {
                                            x: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.label + " (" + modelData.provider + ")"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            x: 14 + (modelData.label + " (" + modelData.provider + ")").length * 7 + 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: modelData.provider === (root.data.provider || "")
                                            text: "当前"
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: Theme.primary
                                        }

                                        StyledText {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.chBalText(modelData)
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: root.chBalColor(modelData)
                                        }

                                        MouseArea {
                                            id: chRowMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                // 点选切换预览; 再点已选中的 → 回到跟随当前通道
                                                root.balanceViewProvider =
                                                    (root.balanceViewProvider === modelData.provider) ? "" : modelData.provider
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---------- 今日用量 | 系统 ----------
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledRect {
                            width: (parent.width - Theme.spacingM) / 2
                            height: 82
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh

                            Column {
                                x: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                StyledText {
                                    text: "今日 Hermes"
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceVariantText
                                }
                                StyledText {
                                    text: root.data.today
                                        ? (root.data.today.user_msgs + " 对话 · " + root.data.today.msgs + " 消息")
                                        : "—"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    text: root.data.today
                                        ? (root.fmtTokens(root.data.today.tokens) + " tok · ≈$" + Number(root.data.today.cost_usd).toFixed(2))
                                        : "—"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }

                        StyledRect {
                            width: (parent.width - Theme.spacingM) / 2
                            height: 82
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh

                            Column {
                                x: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                StyledText {
                                    text: "系统"
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceVariantText
                                }
                                StyledText {
                                    text: root.data.disk
                                        ? ("磁盘 " + Math.round(root.data.disk.free_gb) + "G 可用")
                                        : "—"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    text: {
                                        if (!root.data.updates)
                                            return "更新检查中…"
                                        const c = root.data.updates.count
                                        if (c === null || c === undefined)
                                            return "更新 —"
                                        return c === 0 ? "已是最新 ✓" : (c + " 个包待更新")
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: (root.data.updates && root.data.updates.count > 0)
                                        ? Theme.warning : Theme.surfaceVariantText
                                }
                            }
                        }
                    }

                    // ---------- Clash 流量: 左波形 | 右进程榜 ----------
                    StyledRect {
                        width: parent.width
                        height: 148
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        StyledText {
                            x: Theme.spacingM
                            y: Theme.spacingS
                            text: "Clash 流量"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                        }

                        DankIcon {
                            x: Theme.spacingM + 76
                            anchors.verticalCenter: titleRow.verticalCenter
                            name: root.data.proxy_ok ? "cloud_done" : "cloud_off"
                            size: 13
                            color: root.data.proxy_ok ? Theme.success : Theme.error
                        }

                        Row {
                            id: titleRow
                            x: parent.width - Theme.spacingM - netHeadRow.width
                            y: Theme.spacingS
                            spacing: Theme.spacingM

                            Row {
                                id: netHeadRow
                                spacing: 4

                                DankIcon {
                                    name: "arrow_downward"
                                    size: 13
                                    color: Theme.success
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: root.fmtRate(root.data.net ? root.data.net.rx_bps : null)
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.family: "monospace"
                                    color: Theme.success
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankIcon {
                                    name: "arrow_upward"
                                    size: 13
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: root.fmtRate(root.data.net ? root.data.net.tx_bps : null)
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.family: "monospace"
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // 左: 流量波形 (rx 面积 + tx 线)
                        Canvas {
                            id: netCanvas
                            x: Theme.spacingM
                            y: 30
                            width: 196
                            height: parent.height - 42
                            renderStrategy: Canvas.Cooperative
                            clip: true

                            property var hist: (root.data.net && root.data.net.hist) ? root.data.net.hist : []

                            onHistChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.clearRect(0, 0, width, height)
                                if (!hist || hist.length < 2) {
                                    ctx.fillStyle = Theme.withAlpha(Theme.surfaceVariantText, 0.4)
                                    ctx.font = "11px sans-serif"
                                    ctx.textAlign = "center"
                                    ctx.fillText("采样中…", width / 2, height / 2)
                                    return
                                }
                                // 自适应量程: 至少 64KB/s, 否则小流量曲线贴底
                                let mx = 65536
                                for (const p of hist) {
                                    mx = Math.max(mx, p[0], p[1])
                                }
                                mx *= 1.15
                                const W = width, H = height
                                const yOf = v => H - (v / mx) * (H - 4) - 2

                                // rx 渐变面积
                                const grad = ctx.createLinearGradient(0, 0, 0, H)
                                grad.addColorStop(0, Theme.withAlpha(Theme.success, 0.32))
                                grad.addColorStop(1, Theme.withAlpha(Theme.success, 0.02))
                                ctx.beginPath()
                                ctx.moveTo(0, H)
                                for (let j = 0; j < hist.length; j++)
                                    ctx.lineTo((W / (hist.length - 1)) * j, yOf(hist[j][0]))
                                ctx.lineTo(W, H)
                                ctx.closePath()
                                ctx.fillStyle = grad
                                ctx.fill()

                                ctx.beginPath()
                                for (let k = 0; k < hist.length; k++) {
                                    const px = (W / (hist.length - 1)) * k
                                    k === 0 ? ctx.moveTo(px, yOf(hist[k][0])) : ctx.lineTo(px, yOf(hist[k][0]))
                                }
                                ctx.strokeStyle = Theme.withAlpha(Theme.success, 0.9)
                                ctx.lineWidth = 1.6
                                ctx.lineJoin = "round"
                                ctx.stroke()

                                // tx 折线
                                ctx.beginPath()
                                for (let k = 0; k < hist.length; k++) {
                                    const px = (W / (hist.length - 1)) * k
                                    k === 0 ? ctx.moveTo(px, yOf(hist[k][1])) : ctx.lineTo(px, yOf(hist[k][1]))
                                }
                                ctx.strokeStyle = Theme.withAlpha(Theme.primary, 0.9)
                                ctx.lineWidth = 1.4
                                ctx.lineJoin = "round"
                                ctx.stroke()
                            }
                        }

                        // 右: 使用流量的进程 (实时排序, 前5)
                        Column {
                            x: netCanvas.x + netCanvas.width + Theme.spacingM
                            y: 30
                            width: parent.width - netCanvas.width - Theme.spacingM * 3
                            spacing: 4

                            Repeater {
                                model: (root.data.net && root.data.net.procs && root.data.net.procs.length)
                                       ? root.data.net.procs : []

                                Item {
                                    width: parent.width
                                    height: 17

                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Theme.primary
                                        opacity: 0.55 + Math.min(0.45, (modelData.rx + modelData.tx) / 262144)
                                    }

                                    StyledText {
                                        x: 11
                                        width: parent.width - 96
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.fmtRate(modelData.rx + modelData.tx)
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: "monospace"
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            StyledText {
                                visible: !(root.data.net && root.data.net.procs && root.data.net.procs.length)
                                text: "无活跃连接"
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    // ---------- 最近对话 ----------
                    StyledRect {
                        width: parent.width
                        height: root.convHeight()
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        StyledText {
                            id: convTitle
                            visible: root.convCount() > 0
                            x: Theme.spacingL
                            y: Theme.spacingS
                            text: "对话"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            visible: root.convCount() > 0
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingL
                            anchors.verticalCenter: convTitle.verticalCenter
                            text: "近 24 小时"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            visible: root.convCount() === 0
                            x: Theme.spacingL
                            anchors.verticalCenter: parent.verticalCenter
                            text: "近 24 小时无对话"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Column {
                            visible: root.convCount() > 0
                            x: Theme.spacingL
                            y: 32
                            spacing: 0
                            width: parent.width - Theme.spacingL * 2

                            Repeater {
                                model: root.data.sessions ? root.data.sessions.slice(0, 4) : []

                                delegate: Item {
                                    width: parent.width
                                    height: 22

                                    Rectangle {
                                        id: sessDot
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: (Date.now() / 1000 - modelData.last_ts) < 600 ? Theme.success : Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        anchors.left: sessDot.right
                                        anchors.leftMargin: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 104
                                        text: modelData.title
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.relTime(modelData.last_ts)
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: root.data.last_error || ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        visible: root.data.last_error !== ""
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
