import AppKit
import SwiftUI

private enum XlyraMenuLayout {
    static let width: CGFloat = 460
    static let scrollMaxHeight: CGFloat = 320
}

enum XlyraDetailTab: String, CaseIterable, Identifiable {
    case oauth = "OAuth"
    case sites = "站点"
    case apiKeys = "API Key"

    var id: String { rawValue }
}

struct XlyraMenuBarLabel: View {
    @ObservedObject var state: XlyraMonitorState
    @ObservedObject var preferences: AppPreferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = MenuBarPalette(mode: preferences.themeMode, systemColorScheme: colorScheme)
        Image(nsImage: XlyraMenuBarImageRenderer.image(state: state, palette: palette))
            .accessibilityLabel(state.title)
    }
}

enum XlyraMenuBarImageRenderer {
    @MainActor
    static func image(state: XlyraMonitorState, palette: MenuBarPalette) -> NSImage {
        guard let snapshot = state.snapshot else {
            return fallbackImage(text: "xLyra", colorName: state.statusColorName, palette: palette)
        }

        let fiveHourCapacity = snapshot.oauth.fiveHourCapacity
        let weeklyCapacity = snapshot.oauth.weeklyCapacity
        let valueFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        let barWidth: CGFloat = 30
        let markRect = CGRect(x: 0, y: 2.5, width: 17, height: 17)
        let labelX = markRect.maxX + 3
        let barX = labelX + 17 + 3
        let valueX = barX + barWidth + 3
        let valueWidth = max(
            measuredWidth(fiveHourCapacity.shortText, font: valueFont),
            measuredWidth(weeklyCapacity.shortText, font: valueFont)
        )
        let size = NSSize(width: ceil(valueX + valueWidth), height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        drawStatusMark(
            colorName: state.statusColorName,
            centerText: availableAccountCountText(snapshot.oauth.liveHealthy),
            in: markRect,
            palette: palette
        )
        drawRow(
            label: "5h",
            value: fiveHourCapacity.shortText,
            progress: fiveHourCapacity.usedFraction,
            tint: MenuBarQuotaImageRenderer.color(for: fiveHourCapacity.riskColorName),
            palette: palette,
            labelX: labelX,
            barX: barX,
            barWidth: barWidth,
            valueX: valueX,
            valueWidth: valueWidth,
            valueFont: valueFont,
            y: 12
        )
        drawRow(
            label: "7d",
            value: weeklyCapacity.shortText,
            progress: weeklyCapacity.usedFraction,
            tint: MenuBarQuotaImageRenderer.color(for: weeklyCapacity.riskColorName),
            palette: palette,
            labelX: labelX,
            barX: barX,
            barWidth: barWidth,
            valueX: valueX,
            valueWidth: valueWidth,
            valueFont: valueFont,
            y: 2
        )
        return image
    }

    @MainActor
    private static func fallbackImage(text: String, colorName: String, palette: MenuBarPalette) -> NSImage {
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        let textWidth = ceil(NSString(string: text).size(withAttributes: [.font: font]).width)
        let size = NSSize(width: 18 + textWidth, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        MenuBarQuotaImageRenderer.color(for: colorName).setFill()
        NSBezierPath(ovalIn: CGRect(x: 1, y: 4.5, width: 9, height: 9)).fill()
        drawText(
            text,
            rect: CGRect(x: 15, y: 1, width: textWidth, height: 16),
            font: font,
            color: palette.text,
            alignment: .left
        )
        return image
    }

    private static func availableAccountCountText(_ count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }

    private static func drawRow(
        label: String,
        value: String,
        progress: Double,
        tint: NSColor,
        palette: MenuBarPalette,
        labelX: CGFloat,
        barX: CGFloat,
        barWidth: CGFloat,
        valueX: CGFloat,
        valueWidth: CGFloat,
        valueFont: NSFont,
        y: CGFloat
    ) {
        drawText(
            label,
            rect: CGRect(x: labelX, y: y - 1.5, width: 17, height: 11),
            font: .monospacedSystemFont(ofSize: 9, weight: .semibold),
            color: palette.text,
            alignment: .left
        )

        let barRect = CGRect(x: barX, y: y + 2, width: barWidth, height: 4)
        let backgroundPath = NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2)
        palette.track.setFill()
        backgroundPath.fill()

        let clampedProgress = max(0, min(1, progress))
        let filledWidth = clampedProgress * barRect.width
        if filledWidth > 0 {
            let filledPath = NSBezierPath(
                roundedRect: CGRect(x: barRect.minX, y: barRect.minY, width: filledWidth, height: barRect.height),
                xRadius: 2,
                yRadius: 2
            )
            tint.setFill()
            filledPath.fill()
        }

        drawText(
            value,
            rect: CGRect(x: valueX, y: y - 1.5, width: valueWidth, height: 11),
            font: valueFont,
            color: palette.text,
            alignment: .left
        )
    }

    private static func drawStatusMark(colorName: String, centerText: String, in rect: CGRect, palette: MenuBarPalette) {
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.1, dy: 1.1))
        MenuBarQuotaImageRenderer.color(for: colorName).setStroke()
        ring.lineWidth = 1.8
        ring.stroke()

        let fontSize: CGFloat = centerText.count >= 3 ? 7 : 9.5
        drawText(
            centerText,
            rect: CGRect(x: rect.minX, y: rect.midY - 6, width: rect.width, height: 12),
            font: .monospacedSystemFont(ofSize: fontSize, weight: .bold),
            color: palette.text,
            alignment: .center
        )
    }

    private static func drawText(
        _ text: String,
        rect: CGRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byClipping
        NSString(string: text).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private static func measuredWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil(NSString(string: text).size(withAttributes: [.font: font]).width)
    }
}

struct XlyraStatusMenuView: View {
    @ObservedObject var state: XlyraMonitorState
    @ObservedObject var preferences: AppPreferences
    let monitorPreferences: XlyraMonitorPreferences
    let monitor: XlyraMonitor

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let theme = MenuTheme(mode: preferences.themeMode, systemColorScheme: colorScheme)

        VStack(alignment: .leading, spacing: 12) {
            XlyraSummaryView(state: state, theme: theme)

            if let snapshot = state.snapshot {
                XlyraTabStrip(
                    selectedTab: state.selectedDetailTab,
                    snapshot: snapshot,
                    theme: theme,
                    onSelect: state.selectDetailTab
                )

                XlyraMenuScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch state.selectedDetailTab {
                        case .oauth:
                            XlyraOAuthPane(snapshot: snapshot, state: state, monitor: monitor, theme: theme)
                        case .sites:
                            XlyraSitesPane(snapshot: snapshot, theme: theme)
                        case .apiKeys:
                            XlyraAPIKeysPane(snapshot: snapshot, theme: theme)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(height: XlyraMenuLayout.scrollMaxHeight)
            } else {
                Text(state.lastError ?? "等待第一次检查")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(state.lastError == nil ? theme.secondary : theme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.card))
            }

            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)

            HStack(spacing: 8) {
                Button {
                    Task { await monitor.refresh() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(state.isRefreshing)
                .buttonStyle(MenuToolButtonStyle(theme: theme))

                Button {
                    openWindow(id: "xlyra-settings")
                    WindowFocusHelper.focusWindow(title: "xLyra 监控设置")
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
                .buttonStyle(MenuToolButtonStyle(theme: theme))

                Spacer(minLength: 8)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("退出", systemImage: "power")
                }
                .buttonStyle(MenuToolButtonStyle(theme: theme))
            }
            .controlSize(.small)

            XlyraFooterView(state: state, monitorPreferences: monitorPreferences, theme: theme)
        }
        .padding(12)
        .frame(width: XlyraMenuLayout.width)
        .background(theme.background)
        .preferredColorScheme(preferences.themeMode.preferredColorScheme)
    }
}

private struct XlyraTabStrip: View {
    let selectedTab: XlyraDetailTab
    let snapshot: XlyraSnapshot
    let theme: MenuTheme
    let onSelect: (XlyraDetailTab) -> Void

    var body: some View {
        HStack(spacing: 6) {
            tabButton(.oauth, countText: "\(snapshot.oauth.liveHealthy)/\(snapshot.oauth.liveTotal)")
            tabButton(.sites, countText: "\(snapshot.sites.healthy)/\(snapshot.sites.total)")
            tabButton(.apiKeys, countText: "\(snapshot.apiKeys.active)/\(snapshot.apiKeys.total)")
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.control))
    }

    private func tabButton(_ tab: XlyraDetailTab, countText: String) -> some View {
        Button {
            onSelect(tab)
        } label: {
            HStack(spacing: 6) {
                Text(tab.rawValue)
                Text(countText)
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(selectedTab == tab ? theme.text : theme.secondary)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(selectedTab == tab ? theme.text : theme.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == tab ? theme.card : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct XlyraMenuScrollView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.trailing, 8)
        }
        .scrollIndicators(.visible)
        .defaultScrollAnchor(.top)
    }
}

private struct XlyraSummaryView: View {
    @ObservedObject var state: XlyraMonitorState
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 11, height: 11)

                Text(state.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.text)

                Spacer(minLength: 8)

                if state.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.65)
                        .frame(width: 16, height: 16)
                }
            }

            HStack(spacing: 8) {
                XlyraStatCard(value: siteText, label: "站点池", theme: theme)
                XlyraStatCard(value: abnormalText, label: "异常项", theme: theme)
                XlyraStatCard(value: successText, label: "今日成功率", theme: theme)
            }

            HStack(spacing: 8) {
                XlyraStatCard(value: tokenText, label: "今日 Tokens", theme: theme)
                XlyraStatCard(value: costText, label: "今日成本", theme: theme)
                XlyraStatCard(value: requestText, label: "今日请求", theme: theme)
            }
        }
    }

    private var statusColor: Color {
        switch state.statusColorName {
        case "green":
            return theme.green
        case "yellow":
            return theme.orange
        case "red":
            return theme.red
        default:
            return theme.secondary
        }
    }

    private var siteText: String {
        guard let snapshot = state.snapshot else { return "--" }
        return "O \(snapshot.oauth.liveHealthy)/\(snapshot.oauth.liveTotal) · S \(snapshot.sites.healthy)/\(snapshot.sites.total)"
    }

    private var abnormalText: String {
        guard let snapshot = state.snapshot else { return "--" }
        return "冷却 \(snapshot.cooldowns.active) · 异常 \(snapshot.abnormalItemCount)"
    }

    private var successText: String {
        guard let snapshot = state.snapshot else { return "--" }
        return "\(XlyraFormat.percent(snapshot.requests.successRate24h)) · 失败 \(snapshot.requests.failed24h)"
    }

    private var costText: String {
        guard let cost = state.snapshot?.usage.cost24h else { return "--" }
        return XlyraFormat.money(cost)
    }

    private var tokenText: String {
        guard let tokens = state.snapshot?.usage.tokens24h else { return "--" }
        return XlyraFormat.compact(tokens)
    }

    private var requestText: String {
        guard let snapshot = state.snapshot else { return "--" }
        return "\(snapshot.requests.last24h) · 成功 \(snapshot.requests.ok24h)"
    }
}

private struct XlyraStatCard: View {
    let value: String
    let label: String
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.elevatedCard))
    }
}

private struct XlyraSectionHeader: View {
    let title: String
    let detail: String
    let theme: MenuTheme

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            Text(detail)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.secondary)
        }
    }
}

private struct XlyraOAuthPane: View {
    let snapshot: XlyraSnapshot
    @ObservedObject var state: XlyraMonitorState
    let monitor: XlyraMonitor
    let theme: MenuTheme
    @State private var expandedAccountIDs = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                XlyraSectionHeader(
                    title: "OAuth 账号",
                    detail: "\(snapshot.oauth.liveHealthy)/\(snapshot.oauth.liveTotal) 可用",
                    theme: theme
                )

                Button {
                    Task { await monitor.refreshOAuth() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .help("刷新 OAuth 额度")
                .disabled(state.isRefreshing)
                .buttonStyle(MenuToolButtonStyle(theme: theme))
                .controlSize(.small)
            }

            if snapshot.oauth.rows.isEmpty {
                XlyraEmptyState(text: "暂无 OAuth 账号", theme: theme)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(snapshot.oauth.rows) { account in
                        XlyraOAuthRowView(
                            account: account,
                            isExpanded: expandedAccountIDs.contains(account.id),
                            theme: theme
                        ) {
                            if expandedAccountIDs.contains(account.id) {
                                expandedAccountIDs.remove(account.id)
                            } else {
                                expandedAccountIDs.insert(account.id)
                            }
                        }
                    }
                }
            }

        }
    }
}

private struct XlyraSitesPane: View {
    let snapshot: XlyraSnapshot
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            XlyraSectionHeader(
                title: "站点池",
                detail: "\(snapshot.sites.healthy)/\(snapshot.sites.total) 可用",
                theme: theme
            )

            VStack(alignment: .leading, spacing: 7) {
                ForEach(snapshot.sites.rows) { site in
                    XlyraSiteRowView(site: site, theme: theme)
                }
            }
        }
    }
}

private struct XlyraAPIKeysPane: View {
    let snapshot: XlyraSnapshot
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            XlyraSectionHeader(
                title: "API Key",
                detail: "\(snapshot.apiKeys.active)/\(snapshot.apiKeys.total) 启用",
                theme: theme
            )

            if snapshot.apiKeys.rows.isEmpty {
                XlyraEmptyState(text: "暂无 API Key", theme: theme)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(snapshot.apiKeys.rows) { apiKey in
                        XlyraAPIKeyRowView(apiKey: apiKey, theme: theme)
                    }
                }
            }
        }
    }
}

private struct XlyraEmptyState: View {
    let text: String
    let theme: MenuTheme

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.card))
    }
}

private struct XlyraOAuthRowView: View {
    let account: XlyraOAuthRow
    let isExpanded: Bool
    let theme: MenuTheme
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(account.isHealthy ? theme.green : theme.red)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(account.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(account.planDisplayText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.secondary)
                                .padding(.horizontal, 5)
                                .frame(height: 17)
                                .background(Capsule().fill(theme.control))
                        }
                        Text(compactSubtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(account.stateText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(account.isHealthy ? theme.green : theme.red)
                            .lineLimit(1)
                        Text(account.quotaText)
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 14)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    XlyraOAuthQuotaBar(
                        title: "5h",
                        usedPercent: account.fiveHourUsedDisplayPercent,
                        remainingPercent: account.fiveHourRemainingDisplayPercent,
                        resetText: XlyraFormat.resetTime(account.fiveHourResetAt),
                        tint: quotaTint(usedPercent: account.fiveHourUsedDisplayPercent),
                        theme: theme
                    )
                    XlyraOAuthQuotaBar(
                        title: "7d",
                        usedPercent: account.weeklyUsedDisplayPercent,
                        remainingPercent: account.weeklyRemainingDisplayPercent,
                        resetText: XlyraFormat.resetTime(account.weeklyResetAt),
                        tint: quotaTint(usedPercent: account.weeklyUsedDisplayPercent),
                        theme: theme
                    )
                }

                XlyraOAuthMetaGrid(account: account, theme: theme)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(account.isHealthy ? theme.separator : theme.red.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var compactSubtitle: String {
        let siteText = account.siteName ?? account.siteSlug ?? account.provider
        if account.creditsUnlimited == true {
            return "\(siteText) · Credits 不限"
        }
        if let creditsBalance = account.creditsBalance {
            return "\(siteText) · Credits \(creditsBalance)"
        }
        return siteText
    }

    private func quotaTint(usedPercent: Double?) -> Color {
        guard account.isHealthy, let usedPercent else {
            return account.isHealthy ? theme.secondary : theme.red
        }
        switch usedPercent {
        case 91...:
            return theme.red
        case 81..<91:
            return theme.orange
        case 61..<81:
            return Color.yellow
        default:
            return theme.green
        }
    }
}

private struct XlyraOAuthQuotaBar: View {
    let title: String
    let usedPercent: Double?
    let remainingPercent: Double?
    let resetText: String
    let tint: Color
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(width: 24, alignment: .leading)

                Text(remainingText)
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.text)
                    .lineLimit(1)

                Text(usedText)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text("重置 \(resetText)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            XlyraUsageBar(progress: usedFraction, tint: tint, track: theme.control)
                .frame(height: 6)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.elevatedCard.opacity(theme.isDark ? 0.76 : 0.88))
        )
    }

    private var usedFraction: Double {
        guard let usedPercent else { return 0 }
        return max(0, min(1, usedPercent / 100))
    }

    private var remainingText: String {
        guard let remainingPercent else { return "剩余 --" }
        return "剩余 \(Self.percentFormatter.string(from: NSNumber(value: remainingPercent)) ?? "--")%"
    }

    private var usedText: String {
        guard let usedPercent else { return "已用 --" }
        return "已用 \(Self.percentFormatter.string(from: NSNumber(value: usedPercent)) ?? "--")%"
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

private struct XlyraUsageBar: View {
    let progress: Double
    let tint: Color
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = max(0, min(1, progress))
            let width = clampedProgress * proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.10), lineWidth: 0.7)
                    )
                Capsule()
                    .fill(tint)
                    .frame(width: max(width, clampedProgress > 0 ? 3 : 0))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct XlyraOAuthMetaGrid: View {
    let account: XlyraOAuthRow
    let theme: MenuTheme

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
            GridRow {
                XlyraInlineMetric(title: "Credits", value: creditsText, theme: theme)
                XlyraInlineMetric(title: "Tokens", value: XlyraFormat.compact(account.tokens24h), theme: theme)
                XlyraInlineMetric(title: "成本", value: XlyraFormat.money(account.cost24h), theme: theme)
            }
            GridRow {
                XlyraInlineMetric(title: "刷新", value: XlyraFormat.shortTime(account.lastRefreshAt), theme: theme)
                XlyraInlineMetric(title: "同步", value: XlyraFormat.shortTime(account.lastSyncAt), theme: theme)
                XlyraInlineMetric(title: "过期", value: XlyraFormat.shortTime(account.expiresAt), theme: theme)
            }
        }
    }

    private var creditsText: String {
        if account.creditsUnlimited == true { return "不限" }
        return account.creditsBalance ?? "--"
    }
}

private struct XlyraSiteRowView: View {
    let site: XlyraSiteRow
    let theme: MenuTheme

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Circle()
                .fill(site.isHealthy ? theme.green : theme.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(site.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(site.type)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                        .frame(width: 54, height: 17)
                        .background(RoundedRectangle(cornerRadius: 4).fill(theme.control))
                }

                Text("P\(XlyraFormat.priority(site.priority)) · \(site.modelCount) 模型 · \(site.apiKeyCount) Key")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 7) {
                    XlyraPlainMetric(title: "T", value: XlyraFormat.compact(site.tokens24h), theme: theme)
                    XlyraPlainMetric(title: "$", value: XlyraFormat.money(site.cost24h), theme: theme)
                    XlyraPlainMetric(title: "H", value: healthText, theme: theme)
                }

                Text(site.stateText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(site.isHealthy ? theme.green : theme.red)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(site.isHealthy ? theme.separator : theme.red.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var healthText: String {
        guard let health = site.recentHealth else { return "--" }
        if let latency = health.latencyMS {
            return "\(latency) ms"
        }
        return health.success == true ? "OK" : (health.errorType ?? "异常")
    }
}

private struct XlyraPlainMetric: View {
    let title: String
    let value: String
    let theme: MenuTheme

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.tertiary)
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct XlyraAPIKeyRowView: View {
    let apiKey: XlyraAPIKeyRow
    let theme: MenuTheme

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(apiKey.isActive && apiKey.isExhausted == false ? theme.green : theme.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(apiKey.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(apiKey.maskedKey)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(apiKey.quotaText)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(apiKey.isExhausted ? theme.red : theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(apiKey.status)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(apiKey.isActive ? theme.green : theme.red)
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(apiKey.copyText, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("复制 API Key")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.card))
    }
}

private struct XlyraErrorRowView: View {
    let error: XlyraErrorRow
    let theme: MenuTheme

    var body: some View {
        HStack {
            Text(error.errorType)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Spacer()
            Text("\(error.count)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.red)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.card))
    }
}

private struct XlyraInlineMetric: View {
    let title: String
    let value: String
    let theme: MenuTheme

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.tertiary)
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(RoundedRectangle(cornerRadius: 6).fill(theme.elevatedCard))
    }
}

private struct XlyraFooterView: View {
    @ObservedObject var state: XlyraMonitorState
    let monitorPreferences: XlyraMonitorPreferences
    let theme: MenuTheme

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(state.lastError == nil ? theme.secondary : theme.red)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private var text: String {
        if let error = state.lastError {
            return "最近错误 \(error)"
        }
        guard let snapshot = state.snapshot else {
            return "xLyra 控制面 API · Access Token"
        }
        return "更新 \(Self.formatter.string(from: snapshot.checkedAt)) · 延迟 \(latencyText) · xLyra API"
    }

    private var latencyText: String {
        guard let duration = state.lastRefreshDuration else {
            return "--"
        }
        if duration < 1 {
            return "\(Int((duration * 1000).rounded()))ms"
        }
        return String(format: "%.2fs", duration)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter
    }()
}

struct XlyraSettingsWindowView: View {
    @ObservedObject var preferences: AppPreferences
    let monitorPreferences: XlyraMonitorPreferences
    let monitor: XlyraMonitor
    let loginItem: LoginItemService

    @State private var consoleURLText = ""
    @State private var adminAccessTokenText = ""
    @State private var refreshIntervalText = "30"
    @State private var themeMode: AppThemeMode = .automatic
    @State private var launchAtLogin = false
    @State private var message: String?
    @State private var savedConsoleURLText = ""
    @State private var savedRefreshIntervalText = "30"
    @State private var savedThemeMode: AppThemeMode = .automatic
    @State private var savedLaunchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("xLyra 监控设置")
                .font(.title2.weight(.semibold))

            SettingsTextFieldRow(title: "控制台") {
                TextField("https://your-xlyra.example.com", text: $consoleURLText)
            }

            SettingsTextFieldRow(title: "Access Token") {
                SecureField(
                    monitorPreferences.hasAdminAccessToken ? "留空保持当前 Token；输入新值则替换" : "粘贴 xLyra Admin Access Token",
                    text: $adminAccessTokenText
                )
            }

            Text(monitorPreferences.adminAccessTokenStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 96)

            SettingsTextFieldRow(title: "刷新间隔") {
                HStack(spacing: 6) {
                    TextField("30", text: $refreshIntervalText)
                    Text("秒")
                        .foregroundStyle(.secondary)
                }
            }

            Picker("主题", selection: $themeMode) {
                ForEach(AppThemeMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 340)
            .onChange(of: themeMode) { _, newValue in
                preferences.updateThemeMode(newValue)
            }

            Toggle("开机自启动", isOn: $launchAtLogin)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button {
                    save()
                } label: {
                    Label("保存", systemImage: "checkmark.circle")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hasUnsavedChanges == false)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            consoleURLText = monitorPreferences.consoleURL?.absoluteString ?? ""
            adminAccessTokenText = ""
            refreshIntervalText = String(Int(preferences.refreshIntervalSeconds))
            themeMode = preferences.themeMode
            launchAtLogin = loginItem.isEnabled
            rememberSavedValues()
        }
    }

    private var hasUnsavedChanges: Bool {
        normalizedConsoleURLText != savedConsoleURLText
            || refreshIntervalText.trimmingCharacters(in: .whitespacesAndNewlines) != savedRefreshIntervalText
            || themeMode != savedThemeMode
            || launchAtLogin != savedLaunchAtLogin
            || adminAccessTokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func save() {
        guard let consoleURL = URL(string: consoleURLText.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(consoleURL.scheme?.lowercased() ?? ""),
              consoleURL.host?.isEmpty == false else {
            message = "控制台地址必须是 http 或 https URL"
            return
        }
        guard let interval = Int(refreshIntervalText.trimmingCharacters(in: .whitespacesAndNewlines)),
              interval >= 10,
              interval <= 3600 else {
            message = "刷新间隔必须是 10 到 3600 秒"
            return
        }

        monitorPreferences.consoleURL = consoleURL
        do {
            if adminAccessTokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                try monitorPreferences.saveAdminAccessToken(adminAccessTokenText)
                adminAccessTokenText = ""
            }
        } catch {
            message = "Admin Access Token 保存失败"
            return
        }
        preferences.update(
            refreshIntervalSeconds: TimeInterval(interval),
            showsMenuBarNumbers: preferences.showsMenuBarNumbers,
            themeMode: themeMode
        )
        try? loginItem.setEnabled(launchAtLogin)
        monitor.start(interval: TimeInterval(interval))
        Task { await monitor.refreshOAuth() }
        message = "已保存"
        rememberSavedValues()
    }

    private var normalizedConsoleURLText: String {
        consoleURLText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rememberSavedValues() {
        savedConsoleURLText = normalizedConsoleURLText
        savedRefreshIntervalText = refreshIntervalText.trimmingCharacters(in: .whitespacesAndNewlines)
        savedThemeMode = themeMode
        savedLaunchAtLogin = launchAtLogin
    }
}

private enum XlyraFormat {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int((value * 100).rounded()))%"
    }

    static func money(_ value: Double) -> String {
        "$" + (moneyFormatter.string(from: NSNumber(value: value)) ?? "0.00")
    }

    static func compact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return "\(format(Double(value) / 1_000_000))M"
        }
        if value >= 1_000 {
            return "\(format(Double(value) / 1_000))K"
        }
        return "\(value)"
    }

    static func priority(_ value: Double) -> String {
        format(value)
    }

    static func shortTime(_ value: String?) -> String {
        guard let value, let date = parseDate(value) else {
            return "--"
        }
        return shortDateFormatter.string(from: date)
    }

    static func resetTime(_ epochSeconds: Double?) -> String {
        guard let epochSeconds else {
            return "--"
        }
        return shortDateFormatter.string(from: Date(timeIntervalSince1970: epochSeconds))
    }

    private static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }

    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    private static func parseDate(_ value: String) -> Date? {
        isoFormatter.date(from: value) ?? fallbackISOFormatter.date(from: value)
    }
}
