import AppKit
import SwiftUI

private enum XlyraMenuLayout {
    static let width: CGFloat = 460
    static let scrollBaseMaxHeight: CGFloat = 320
    static let scrollMaxHeight: CGFloat = scrollBaseMaxHeight * 1.3
    static let scrollMinHeight: CGFloat = 72
    static let scrollVerticalInset: CGFloat = 3
}

enum XlyraDetailTab: String, CaseIterable, Identifiable {
    case oauth = "OAuth"
    case sites = "站点"
    case apiKeys = "API Key"

    var id: String { rawValue }
}

struct MenuBarPalette {
    let text: NSColor
    let track: NSColor

    init(mode: AppThemeMode, systemColorScheme: ColorScheme) {
        let isDark = mode.resolvesToDark(systemColorScheme: systemColorScheme)
        text = isDark ? .white : .labelColor
        track = isDark ? NSColor.white.withAlphaComponent(0.18) : NSColor.black.withAlphaComponent(0.16)
    }
}

struct MenuTheme {
    let isDark: Bool
    let background: Color
    let card: Color
    let elevatedCard: Color
    let control: Color
    let separator: Color
    let text: Color
    let secondary: Color
    let tertiary: Color
    let green: Color
    let yellow: Color
    let orange: Color
    let red: Color
    let disabledProgress: Color

    init(mode: AppThemeMode, systemColorScheme: ColorScheme) {
        isDark = mode.resolvesToDark(systemColorScheme: systemColorScheme)
        background = isDark ? Color(red: 0.08, green: 0.09, blue: 0.10) : Color(red: 0.96, green: 0.97, blue: 0.98)
        card = isDark ? Color(red: 0.13, green: 0.14, blue: 0.15) : .white
        elevatedCard = isDark ? Color(red: 0.18, green: 0.19, blue: 0.20) : Color(red: 0.98, green: 0.99, blue: 1.0)
        control = isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
        separator = isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
        text = isDark ? .white : Color(red: 0.10, green: 0.11, blue: 0.13)
        secondary = isDark ? Color.white.opacity(0.62) : Color.black.opacity(0.58)
        tertiary = isDark ? Color.white.opacity(0.42) : Color.black.opacity(0.42)
        green = XlyraRiskPalette.color(forRiskName: "green", fallback: .secondary)
        yellow = XlyraRiskPalette.color(forRiskName: "yellow", fallback: .secondary)
        orange = XlyraRiskPalette.color(forRiskName: "orange", fallback: .secondary)
        red = XlyraRiskPalette.color(forRiskName: "red", fallback: .secondary)
        disabledProgress = isDark ? Color.white.opacity(0.28) : Color.black.opacity(0.22)
    }

    func color(forRiskName riskColorName: String) -> Color {
        XlyraRiskPalette.color(forRiskName: riskColorName, fallback: disabledProgress)
    }
}

private enum XlyraRiskPalette {
    static func color(forRiskName riskColorName: String, fallback: Color) -> Color {
        guard let nsColor = nsColor(forRiskName: riskColorName) else {
            return fallback
        }
        return Color(nsColor: nsColor)
    }

    static func nsColor(forRiskName riskColorName: String, fallback: NSColor = .systemGray) -> NSColor {
        nsColor(forRiskName: riskColorName) ?? fallback
    }

    private static func nsColor(forRiskName riskColorName: String) -> NSColor? {
        switch riskColorName {
        case "green":
            return NSColor(calibratedRed: 0.18, green: 0.70, blue: 0.38, alpha: 1)
        case "yellow":
            return NSColor(calibratedRed: 0.82, green: 0.63, blue: 0.10, alpha: 1)
        case "orange":
            return NSColor(calibratedRed: 0.93, green: 0.43, blue: 0.16, alpha: 1)
        case "red":
            return NSColor(calibratedRed: 0.88, green: 0.21, blue: 0.24, alpha: 1)
        default:
            return nil
        }
    }
}

enum MenuBarQuotaImageRenderer {
    static func color(for colorName: String) -> NSColor {
        XlyraRiskPalette.nsColor(forRiskName: colorName)
    }
}

struct MenuToolButtonStyle: ButtonStyle {
    let theme: MenuTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.text)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? theme.control.opacity(0.7) : theme.control)
            )
    }
}

struct SettingsTextFieldRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .trailing)
            content()
                .textFieldStyle(.roundedBorder)
        }
    }
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
    @ObservedObject var updateCoordinator: XlyraAppUpdateCoordinator

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @State private var detailContentHeights: [XlyraDetailTab: CGFloat] = [:]

    var body: some View {
        let theme = MenuTheme(mode: preferences.themeMode, systemColorScheme: colorScheme)

        VStack(alignment: .leading, spacing: 12) {
            XlyraSummaryView(state: state, theme: theme)

            if let snapshot = state.snapshot {
                let selectedTab = state.selectedDetailTab
                let detailHeight = detailFrameHeight(snapshot: snapshot, tab: selectedTab)

                XlyraTabStrip(
                    selectedTab: selectedTab,
                    snapshot: snapshot,
                    theme: theme,
                    onSelect: state.selectDetailTab
                )

                XlyraDetailHeader(
                    selectedTab: selectedTab,
                    snapshot: snapshot,
                    state: state,
                    monitor: monitor,
                    updateCoordinator: updateCoordinator,
                    theme: theme
                )

                XlyraMenuScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch selectedTab {
                        case .oauth:
                            XlyraOAuthPane(snapshot: snapshot, theme: theme)
                        case .sites:
                            XlyraSitesPane(snapshot: snapshot, theme: theme)
                        case .apiKeys:
                            XlyraAPIKeysPane(snapshot: snapshot, theme: theme)
                        }
                    }
                    .background(XlyraDetailContentHeightReader())
                }
                .frame(height: detailHeight)
                .onPreferenceChange(XlyraDetailContentHeightKey.self) { height in
                    guard height > 0 else { return }
                    detailContentHeights[selectedTab] = ceil(height)
                }
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
                    openWindow(id: "xlyra-oauth-import")
                    WindowFocusHelper.focusWindow(title: "导入 OAuth 账号")
                } label: {
                    Label("导入", systemImage: "tray.and.arrow.down")
                }
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

    private func detailFrameHeight(snapshot: XlyraSnapshot, tab: XlyraDetailTab) -> CGFloat {
        let measuredHeight = detailContentHeights[tab]
        let contentHeight = (measuredHeight ?? estimatedDetailContentHeight(snapshot: snapshot, tab: tab))
            + XlyraMenuLayout.scrollVerticalInset * 2
        return min(max(contentHeight, XlyraMenuLayout.scrollMinHeight), XlyraMenuLayout.scrollMaxHeight)
    }

    private func estimatedDetailContentHeight(snapshot: XlyraSnapshot, tab: XlyraDetailTab) -> CGFloat {
        switch tab {
        case .oauth:
            let count = snapshot.oauth.rows.count
            guard count > 0 else { return 44 }
            return CGFloat(count) * 72 + CGFloat(max(0, count - 1)) * 7
        case .sites:
            let count = snapshot.sites.rows.count
            guard count > 0 else { return 44 }
            return CGFloat(count) * 60 + CGFloat(max(0, count - 1)) * 7
        case .apiKeys:
            let count = snapshot.apiKeys.rows.count
            guard count > 0 else { return 44 }
            return CGFloat(count) * 64 + CGFloat(max(0, count - 1)) * 7
        }
    }
}

private struct XlyraDetailContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct XlyraDetailContentHeightReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: XlyraDetailContentHeightKey.self, value: proxy.size.height)
        }
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
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedTab == tab ? theme.card : Color.clear)
        )
        .onTapGesture {
            onSelect(tab)
        }
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
                .padding(.horizontal, 1)
                .padding(.trailing, 12)
                .padding(.vertical, XlyraMenuLayout.scrollVerticalInset)
        }
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.always, axes: .vertical)
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
        theme.color(forRiskName: state.statusColorName)
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

private struct XlyraDetailHeader: View {
    let selectedTab: XlyraDetailTab
    let snapshot: XlyraSnapshot
    @ObservedObject var state: XlyraMonitorState
    let monitor: XlyraMonitor
    @ObservedObject var updateCoordinator: XlyraAppUpdateCoordinator
    let theme: MenuTheme

    var body: some View {
        HStack(spacing: 8) {
            XlyraSectionHeader(title: title, detail: detail, theme: theme)

            if let update = updateCoordinator.updateStatus.availableUpdate {
                Button {
                    updateCoordinator.installAvailableUpdate()
                } label: {
                    Label(updateButtonTitle(for: update), systemImage: "arrow.down.circle.fill")
                }
                .help("更新到 \(update.version)")
                .disabled(updateCoordinator.updateStatus.isBusy)
                .buttonStyle(MenuToolButtonStyle(theme: theme))
                .controlSize(.small)
            }

            if selectedTab == .oauth {
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
        }
    }

    private func updateButtonTitle(for update: XlyraAppUpdate) -> String {
        switch updateCoordinator.updateStatus {
        case .downloading:
            return "下载中"
        case .installing:
            return "安装中"
        default:
            return "更新"
        }
    }

    private var title: String {
        switch selectedTab {
        case .oauth:
            return "OAuth 账号"
        case .sites:
            return "站点池"
        case .apiKeys:
            return "API Key"
        }
    }

    private var detail: String {
        switch selectedTab {
        case .oauth:
            return "\(snapshot.oauth.liveHealthy)/\(snapshot.oauth.liveTotal) 可用"
        case .sites:
            return "\(snapshot.sites.healthy)/\(snapshot.sites.total) 可用"
        case .apiKeys:
            return "\(snapshot.apiKeys.active)/\(snapshot.apiKeys.total) 启用"
        }
    }
}

private struct XlyraOAuthPane: View {
    let snapshot: XlyraSnapshot
    let theme: MenuTheme
    @State private var expandedAccountIDs = Set<String>()
    @State private var remainingResetTimeAccountIDs = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if snapshot.oauth.rows.isEmpty {
                XlyraEmptyState(text: "暂无 OAuth 账号", theme: theme)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(snapshot.oauth.rows) { account in
                        XlyraOAuthRowView(
                            account: account,
                            isExpanded: expandedAccountIDs.contains(account.id),
                            showsRemainingResetTime: remainingResetTimeAccountIDs.contains(account.id),
                            theme: theme
                        ) {
                            if expandedAccountIDs.contains(account.id) {
                                expandedAccountIDs.remove(account.id)
                            } else {
                                expandedAccountIDs.insert(account.id)
                            }
                        } onToggleResetTime: {
                            if remainingResetTimeAccountIDs.contains(account.id) {
                                remainingResetTimeAccountIDs.remove(account.id)
                            } else {
                                remainingResetTimeAccountIDs.insert(account.id)
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
    let showsRemainingResetTime: Bool
    let theme: MenuTheme
    let onToggle: () -> Void
    let onToggleResetTime: () -> Void

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
                        Text(compactResetText)
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
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
                    ForEach(account.quotaDisplays) { quota in
                        XlyraOAuthQuotaBar(
                            title: quota.title,
                            usedPercent: quota.usedPercent,
                            remainingPercent: quota.remainingPercent,
                            resetText: resetText(for: quota),
                            resetHelpText: resetHelpText,
                            onToggleResetTime: onToggleResetTime,
                            tint: quotaTint(for: quota.usedPercent),
                            theme: theme
                        )
                    }
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
                        .strokeBorder(account.isHealthy ? theme.separator : theme.red.opacity(0.45), lineWidth: 1)
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

    private var compactResetText: String {
        let parts = account.quotaDisplays.prefix(2).map { quota in
            "\(quota.title) \(compactResetValue(for: quota))"
        }
        return parts.isEmpty ? "--" : parts.joined(separator: " · ")
    }

    private var resetHelpText: String {
        showsRemainingResetTime ? "显示具体重置时间" : "显示剩余重置时间"
    }

    private func compactResetValue(for quota: XlyraOAuthQuotaDisplay) -> String {
        showsRemainingResetTime ? XlyraFormat.resetRemainingTime(quota.resetAt) : XlyraFormat.resetTime(quota.resetAt)
    }

    private func resetText(for quota: XlyraOAuthQuotaDisplay) -> String {
        if showsRemainingResetTime {
            return "剩余 \(XlyraFormat.resetRemainingTime(quota.resetAt))"
        }
        return "重置 \(XlyraFormat.resetTime(quota.resetAt))"
    }

    private func quotaTint(for usedPercent: Double?) -> Color {
        theme.color(forRiskName: account.quotaProgressColorName(usedPercent: usedPercent))
    }
}

private struct XlyraOAuthQuotaBar: View {
    let title: String
    let usedPercent: Double?
    let remainingPercent: Double?
    let resetText: String
    let resetHelpText: String
    let onToggleResetTime: () -> Void
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

                Button(action: onToggleResetTime) {
                    Text(resetText)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.plain)
                .help(resetHelpText)
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
                        .strokeBorder(site.isHealthy ? theme.separator : theme.red.opacity(0.45), lineWidth: 1)
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
    @ObservedObject var updateCoordinator: XlyraAppUpdateCoordinator

    @State private var consoleURLText = ""
    @State private var adminAccessTokenText = ""
    @State private var statusRefreshIntervalText = "30"
    @State private var oauthRefreshIntervalText = "300"
    @State private var themeMode: AppThemeMode = .automatic
    @State private var launchAtLogin = false
    @State private var message: String?
    @State private var savedConsoleURLText = ""
    @State private var savedStatusRefreshIntervalText = "30"
    @State private var savedOAuthRefreshIntervalText = "300"
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

            SettingsTextFieldRow(title: "基础信息刷新") {
                HStack(spacing: 6) {
                    TextField("30", text: $statusRefreshIntervalText)
                    Text("秒")
                        .foregroundStyle(.secondary)
                }
            }

            SettingsTextFieldRow(title: "OAuth 额度刷新") {
                HStack(spacing: 6) {
                    TextField("300", text: $oauthRefreshIntervalText)
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

            Divider()

            softwareUpdateSection

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
            statusRefreshIntervalText = String(Int(preferences.refreshIntervalSeconds))
            oauthRefreshIntervalText = String(Int(preferences.oauthRefreshIntervalSeconds))
            themeMode = preferences.themeMode
            launchAtLogin = loginItem.isEnabled
            rememberSavedValues()
        }
    }

    private var softwareUpdateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("软件更新")
                        .font(.system(size: 13, weight: .semibold))
                    Text("当前版本 \(XlyraMonitorAppMetadata.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    checkForUpdate()
                } label: {
                    Label(checkUpdateButtonTitle, systemImage: "arrow.down.circle")
                }
                .disabled(updateCoordinator.updateStatus.isBusy)
            }

            if let update = updateForAction {
                HStack(spacing: 8) {
                    Text("发现 \(update.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        updateCoordinator.installAvailableUpdate()
                    } label: {
                        Label(installUpdateButtonTitle, systemImage: "arrow.down.circle.fill")
                    }
                    .disabled(updateCoordinator.updateStatus.isBusy)
                }
            }

            if let updateMessage {
                Text(updateMessage)
                    .font(.caption)
                    .foregroundStyle(updateMessageIsError ? .red : .secondary)
            }
        }
    }

    private var checkUpdateButtonTitle: String {
        if case .checking = updateCoordinator.updateStatus { return "检查中" }
        if case .downloading = updateCoordinator.updateStatus { return "下载中" }
        if case .installing = updateCoordinator.updateStatus { return "安装中" }
        return "检查更新"
    }

    private var installUpdateButtonTitle: String {
        switch updateCoordinator.updateStatus {
        case .downloading:
            return "下载中"
        case .installing:
            return "安装中"
        default:
            return "立即更新"
        }
    }

    private var updateForAction: XlyraAppUpdate? {
        updateCoordinator.updateStatus.availableUpdate
    }

    private var updateMessage: String? {
        switch updateCoordinator.updateStatus {
        case .idle:
            return nil
        case .checking:
            return "正在检查 GitHub Releases"
        case .upToDate:
            return "当前已是最新版本"
        case .available(let update):
            return "\(update.releaseName) 可用"
        case .downloading:
            return "正在下载 DMG"
        case .installing:
            return "正在安装更新，App 将自动重启"
        case .failed(let message):
            return message
        }
    }

    private var updateMessageIsError: Bool {
        if case .failed = updateCoordinator.updateStatus { return true }
        return false
    }

    private func checkForUpdate() {
        Task { @MainActor in
            await updateCoordinator.checkForUpdate()
        }
    }

    private var hasUnsavedChanges: Bool {
        normalizedConsoleURLText != savedConsoleURLText
            || normalizedStatusRefreshIntervalText != savedStatusRefreshIntervalText
            || normalizedOAuthRefreshIntervalText != savedOAuthRefreshIntervalText
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
        guard let statusInterval = Int(normalizedStatusRefreshIntervalText),
              statusInterval >= 10,
              statusInterval <= 3600 else {
            message = "基础信息刷新间隔必须是 10 到 3600 秒"
            return
        }
        guard let oauthInterval = Int(normalizedOAuthRefreshIntervalText),
              oauthInterval >= 10,
              oauthInterval <= 3600 else {
            message = "OAuth 额度刷新间隔必须是 10 到 3600 秒"
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
            refreshIntervalSeconds: TimeInterval(statusInterval),
            oauthRefreshIntervalSeconds: TimeInterval(oauthInterval),
            showsMenuBarNumbers: preferences.showsMenuBarNumbers,
            themeMode: themeMode
        )
        try? loginItem.setEnabled(launchAtLogin)
        monitor.start(
            statusInterval: TimeInterval(statusInterval),
            oauthInterval: TimeInterval(oauthInterval)
        )
        Task { await monitor.refresh() }
        message = "已保存"
        rememberSavedValues()
    }

    private var normalizedConsoleURLText: String {
        consoleURLText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedStatusRefreshIntervalText: String {
        statusRefreshIntervalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedOAuthRefreshIntervalText: String {
        oauthRefreshIntervalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rememberSavedValues() {
        savedConsoleURLText = normalizedConsoleURLText
        savedStatusRefreshIntervalText = normalizedStatusRefreshIntervalText
        savedOAuthRefreshIntervalText = normalizedOAuthRefreshIntervalText
        savedThemeMode = themeMode
        savedLaunchAtLogin = launchAtLogin
    }
}

struct XlyraOAuthImportWindowView: View {
    @ObservedObject var preferences: AppPreferences
    let monitor: XlyraMonitor

    @State private var selectedFileURL: URL?
    @State private var selectedFileName = "未选择文件"
    @State private var priorityText = ""
    @State private var isImportingOAuth = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("导入 OAuth 账号")
                .font(.title2.weight(.semibold))

            HStack(spacing: 10) {
                Button {
                    selectImportFile()
                } label: {
                    Label("选择文件", systemImage: "doc.badge.plus")
                }
                .disabled(isImportingOAuth)

                Text(selectedFileName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            SettingsTextFieldRow(title: "优先级") {
                TextField("默认", text: $priorityText)
                    .disabled(isImportingOAuth)
            }

            Text("选择 xLyra `/api/v1/oauth/import` 支持的 JSON 文件。填写优先级后会写入导入内容；留空则使用 xLyra 默认值。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button {
                    selectedFileURL = nil
                    selectedFileName = "未选择文件"
                    priorityText = ""
                    message = nil
                } label: {
                    Label("清空", systemImage: "xmark.circle")
                }
                .disabled((selectedFileURL == nil && priorityText.isEmpty) || isImportingOAuth)

                Button {
                    Task { await importOAuthAccounts() }
                } label: {
                    Label(isImportingOAuth ? "导入中" : "导入", systemImage: "tray.and.arrow.down")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isImportingOAuth || selectedFileURL == nil)
            }
        }
        .padding(20)
        .frame(width: 520)
        .frame(minHeight: 300)
    }

    private func selectImportFile() {
        let panel = NSOpenPanel()
        panel.title = "选择 OAuth 导入文件"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: preferences.importDirectoryPath, isDirectory: true)
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        selectedFileURL = url
        selectedFileName = url.lastPathComponent
        preferences.updateImportDirectoryPath(url.deletingLastPathComponent().path)
        message = nil
    }

    private func importOAuthAccounts() async {
        message = nil
        guard let selectedFileURL else {
            message = "请先选择 OAuth 导入文件"
            return
        }
        guard let priority = normalizedPriority else {
            message = "优先级必须是整数"
            return
        }

        let payload: Data
        do {
            let data = try Data(contentsOf: selectedFileURL)
            payload = try Self.payload(from: data, priority: priority)
        } catch {
            message = "OAuth 导入文件必须是合法 JSON"
            return
        }

        isImportingOAuth = true
        defer { isImportingOAuth = false }

        switch await monitor.importOAuthAccounts(payload: payload) {
        case .success(let result):
            self.selectedFileURL = nil
            selectedFileName = "未选择文件"
            priorityText = ""
            message = result.message
        case .failure(let error):
            message = error.message
        }
    }

    private var normalizedPriority: Int? {
        let text = priorityText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return 0 }
        return Int(text)
    }

    private static func payload(from data: Data, priority: Int) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)
        guard priority > 0 else {
            return data
        }
        let updatedObject = applyPriority(priority, to: object)
        return try JSONSerialization.data(withJSONObject: updatedObject, options: [])
    }

    private static func applyPriority(_ priority: Int, to object: Any) -> Any {
        if var dictionary = object as? [String: Any] {
            if let items = dictionary["items"] as? [[String: Any]] {
                dictionary["items"] = items.map { item in
                    var item = item
                    item["priority"] = priority
                    return item
                }
                return dictionary
            }
            if let accounts = dictionary["accounts"] as? [[String: Any]] {
                dictionary["accounts"] = accounts.map { account in
                    var account = account
                    account["priority"] = priority
                    return account
                }
                return dictionary
            }
            dictionary["priority"] = priority
            return dictionary
        }
        if let array = object as? [[String: Any]] {
            return array.map { item in
                var item = item
                item["priority"] = priority
                return item
            }
        }
        return object
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

    static func resetRemainingTime(_ epochSeconds: Double?, now: Date = Date()) -> String {
        guard let epochSeconds else {
            return "--"
        }
        let remaining = Date(timeIntervalSince1970: epochSeconds).timeIntervalSince(now)
        guard remaining > 0 else {
            return "已到"
        }

        let totalMinutes = Int(ceil(remaining / 60))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(1, minutes))m"
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
