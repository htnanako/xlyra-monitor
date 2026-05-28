import SwiftUI
import AppKit
import Sub2APIQuotaCore

private enum MenuLayout {
    static let width: CGFloat = 460
    static let contentWidth: CGFloat = 436
}

struct StatusMenuView: View {
    @ObservedObject var state: AppState
    @ObservedObject var preferences: AppPreferences
    let monitor: QuotaMonitor
    let runModelCheck: (AccountQuotaRowViewModel) async -> Void
    let updatePriority: (AccountQuotaRowViewModel, Int) async -> Void

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDetailTab: MenuDetailTab = .oauth

    var body: some View {
        let model = StatusViewModel(
            status: state.status,
            snapshot: state.quotaSnapshot,
            lastError: state.lastError,
            lastRequestDuration: state.lastRequestDuration
        )
        let theme = MenuTheme(mode: preferences.themeMode, systemColorScheme: colorScheme)

        VStack(alignment: .leading, spacing: 10) {
            MenuSummaryView(
                model: model,
                poolSummary: state.quotaSnapshot?.poolSummary,
                isRequestInFlight: state.isRequestInFlight,
                theme: theme
            )

            if model.accountRows.isEmpty == false || model.inspectedAPIKeyRow != nil {
                MenuDetailsTabsView(
                    selectedTab: $selectedDetailTab,
                    rows: model.accountRows,
                    apiKeyRow: model.inspectedAPIKeyRow,
                    results: state.modelCheckResultsByAccountID,
                    errors: state.modelCheckErrorsByAccountID,
                    inFlightAccountIDs: state.modelCheckInFlightAccountIDs,
                    priorityErrors: state.priorityUpdateErrorsByAccountID,
                    priorityInFlightAccountIDs: state.priorityUpdateInFlightAccountIDs,
                    keyAvailabilitySamples: state.keyAvailabilitySamplesByAccountID,
                    keyAvailabilityInFlightAccountIDs: state.keyAvailabilityInFlightAccountIDs,
                    theme: theme,
                    updatePriority: updatePriority,
                    runModelCheck: runModelCheck
                )
            }

            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)

            HStack(spacing: 8) {
                Button {
                    Task { await monitor.refresh(source: .manual) }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(state.isRequestInFlight)
                .buttonStyle(MenuToolButtonStyle(theme: theme))

                Button {
                    openWindow(id: "account-import")
                    WindowFocusHelper.focusWindow(title: "Sub2API 账号导入")
                } label: {
                    Label("导入", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(MenuToolButtonStyle(theme: theme))

                Button {
                    openWindow(id: "settings")
                    WindowFocusHelper.focusWindow(title: "Sub2API 设置")
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

            MenuFooterInfoView(model: model, lastError: state.lastError, theme: theme)
        }
        .padding(12)
        .frame(width: MenuLayout.width)
        .background(theme.background)
        .preferredColorScheme(preferences.themeMode.preferredColorScheme)
    }
}

struct MenuTheme {
    let mode: AppThemeMode
    let systemColorScheme: ColorScheme

    var isDark: Bool {
        mode.resolvesToDark(systemColorScheme: systemColorScheme)
    }

    var background: Color { isDark ? Color(red: 0.09, green: 0.095, blue: 0.10) : Color(red: 0.965, green: 0.958, blue: 0.94) }
    var card: Color { isDark ? Color(red: 0.14, green: 0.145, blue: 0.15) : Color.white }
    var elevatedCard: Color { isDark ? Color(red: 0.17, green: 0.17, blue: 0.18) : Color.white }
    var text: Color { isDark ? Color.white.opacity(0.94) : Color.black.opacity(0.90) }
    var secondary: Color { isDark ? Color.white.opacity(0.58) : Color.black.opacity(0.64) }
    var tertiary: Color { isDark ? Color.white.opacity(0.34) : Color.black.opacity(0.46) }
    var separator: Color { isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.14) }
    var control: Color { isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.075) }
    var controlPressed: Color { isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.12) }
    var green: Color { isDark ? Color(red: 0.11, green: 0.80, blue: 0.45) : Color(red: 0.00, green: 0.58, blue: 0.30) }
    var mint: Color { isDark ? Color(red: 0.70, green: 0.95, blue: 0.82) : Color(red: 0.72, green: 0.91, blue: 0.79) }
    var blue: Color { Color(red: 0.30, green: 0.34, blue: 1.0) }
    var blueSoft: Color { isDark ? Color(red: 0.22, green: 0.24, blue: 0.48) : Color(red: 0.84, green: 0.85, blue: 1.0) }
    var orange: Color { isDark ? Color.orange : Color(red: 0.78, green: 0.43, blue: 0.00) }
    var red: Color { isDark ? Color(red: 1.0, green: 0.35, blue: 0.35) : Color(red: 0.78, green: 0.12, blue: 0.12) }
    var warningBackground: Color { isDark ? Color.orange.opacity(0.12) : Color.orange.opacity(0.08) }
    var shadow: Color { isDark ? Color.black.opacity(0.0) : Color.black.opacity(0.07) }
}

private struct MenuThemeKey: EnvironmentKey {
    static let defaultValue = MenuTheme(mode: .automatic, systemColorScheme: .light)
}

private extension EnvironmentValues {
    var menuTheme: MenuTheme {
        get { self[MenuThemeKey.self] }
        set { self[MenuThemeKey.self] = newValue }
    }
}

struct MenuToolButtonStyle: ButtonStyle {
    let theme: MenuTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.text)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? theme.controlPressed : theme.control)
            )
    }
}

private enum MenuDetailTab: String, CaseIterable, Identifiable {
    case oauth = "OAuth"
    case key = "Key"
    case other = "其他"
    case inspectedKey = "检查 Key"

    var id: String { rawValue }
}

private struct MenuDetailsTabsView: View {
    @Binding var selectedTab: MenuDetailTab
    let rows: [AccountQuotaRowViewModel]
    let apiKeyRow: APIKeyUsageRowViewModel?
    let results: [Int: ModelDegradationCheckResult]
    let errors: [Int: String]
    let inFlightAccountIDs: Set<Int>
    let priorityErrors: [Int: String]
    let priorityInFlightAccountIDs: Set<Int>
    let keyAvailabilitySamples: [Int: [KeyAvailabilitySample]]
    let keyAvailabilityInFlightAccountIDs: Set<Int>
    let theme: MenuTheme
    let updatePriority: (AccountQuotaRowViewModel, Int) async -> Void
    let runModelCheck: (AccountQuotaRowViewModel) async -> Void

    var body: some View {
        let tabs = availableTabs
        let activeTab = tabs.contains(selectedTab) ? selectedTab : tabs.first ?? .oauth

        VStack(alignment: .leading, spacing: 8) {
            if tabs.count > 1 {
                MenuDetailTabStrip(tabs: tabs, selectedTab: $selectedTab, theme: theme)
            }

            switch activeTab {
            case .oauth:
                AccountDetailsListView(
                    title: "OAuth",
                    systemImage: "person.crop.circle.badge.checkmark",
                    rows: oauthRows,
                    results: results,
                    errors: errors,
                    inFlightAccountIDs: inFlightAccountIDs,
                    priorityErrors: priorityErrors,
                    priorityInFlightAccountIDs: priorityInFlightAccountIDs,
                    keyAvailabilitySamples: keyAvailabilitySamples,
                    keyAvailabilityInFlightAccountIDs: keyAvailabilityInFlightAccountIDs,
                    theme: theme,
                    updatePriority: updatePriority,
                    runModelCheck: runModelCheck
                )
            case .key:
                AccountDetailsListView(
                    title: "Key",
                    systemImage: "key",
                    rows: keyRows,
                    results: results,
                    errors: errors,
                    inFlightAccountIDs: inFlightAccountIDs,
                    priorityErrors: priorityErrors,
                    priorityInFlightAccountIDs: priorityInFlightAccountIDs,
                    keyAvailabilitySamples: keyAvailabilitySamples,
                    keyAvailabilityInFlightAccountIDs: keyAvailabilityInFlightAccountIDs,
                    theme: theme,
                    updatePriority: updatePriority,
                    runModelCheck: runModelCheck
                )
            case .other:
                AccountDetailsListView(
                    title: "其他渠道",
                    systemImage: "square.stack.3d.up",
                    rows: otherRows,
                    results: results,
                    errors: errors,
                    inFlightAccountIDs: inFlightAccountIDs,
                    priorityErrors: priorityErrors,
                    priorityInFlightAccountIDs: priorityInFlightAccountIDs,
                    keyAvailabilitySamples: keyAvailabilitySamples,
                    keyAvailabilityInFlightAccountIDs: keyAvailabilityInFlightAccountIDs,
                    theme: theme,
                    updatePriority: updatePriority,
                    runModelCheck: runModelCheck
                )
            case .inspectedKey:
                if let apiKeyRow {
                    APIKeyUsageView(row: apiKeyRow, theme: theme)
                }
            }
        }
        .onAppear {
            normalizeSelection(tabs)
        }
        .onChange(of: tabs) { _, newTabs in
            normalizeSelection(newTabs)
        }
    }

    private var availableTabs: [MenuDetailTab] {
        var tabs: [MenuDetailTab] = []
        if oauthRows.isEmpty == false {
            tabs.append(.oauth)
        }
        if keyRows.isEmpty == false {
            tabs.append(.key)
        }
        if otherRows.isEmpty == false {
            tabs.append(.other)
        }
        if apiKeyRow != nil {
            tabs.append(.inspectedKey)
        }
        return tabs
    }

    private var oauthRows: [AccountQuotaRowViewModel] {
        rows.filter { $0.channelKind == .oauth }
    }

    private var keyRows: [AccountQuotaRowViewModel] {
        rows.filter { $0.channelKind == .apiKey }
    }

    private var otherRows: [AccountQuotaRowViewModel] {
        rows.filter {
            if case .other = $0.channelKind {
                return true
            }
            return false
        }
    }

    private func normalizeSelection(_ tabs: [MenuDetailTab]) {
        guard tabs.contains(selectedTab) == false,
              let firstTab = tabs.first else {
            return
        }

        selectedTab = firstTab
    }
}

private struct MenuDetailTabStrip: View {
    let tabs: [MenuDetailTab]
    @Binding var selectedTab: MenuDetailTab
    let theme: MenuTheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(selectedTab == tab ? Color.white : theme.text)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.accentColor : theme.control)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedTab == tab ? Color.accentColor : theme.separator,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MenuSummaryView: View {
    let model: StatusViewModel
    let poolSummary: AccountPoolSummary?
    let isRequestInFlight: Bool
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(model.title.replacingOccurrences(of: "Sub2API ", with: ""))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let poolSummary {
                    Text("并发 \(poolSummary.currentConcurrency)/\(poolSummary.concurrencyLimit)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(theme.green)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Capsule().fill(theme.green.opacity(theme.isDark ? 0.16 : 0.12)))
                }

                if isRequestInFlight {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }

            if let poolSummary {
                VStack(alignment: .leading, spacing: 7) {
                    MenuQuotaProgressRow(
                        label: "5h",
                        progress: 1 - model.fiveHourUsedFraction,
                        tint: quotaTint(usedFraction: model.fiveHourUsedFraction),
                        percentText: availabilityText(usedFraction: model.fiveHourUsedFraction),
                        theme: theme
                    )
                    MenuQuotaProgressRow(
                        label: "7d",
                        progress: 1 - model.sevenDayUsedFraction,
                        tint: quotaTint(usedFraction: model.sevenDayUsedFraction),
                        percentText: availabilityText(usedFraction: model.sevenDayUsedFraction),
                        theme: theme
                    )
                }

                HStack(spacing: 8) {
                    SummaryStatCard(value: "\(poolSummary.schedulableCount)", label: "可用账号", theme: theme)
                    SummaryStatCard(value: "\(poolSummary.rateLimitedCount)", label: "限流", theme: theme)
                    SummaryStatCard(value: "\(errorCount(poolSummary))", label: "错误", theme: theme)
                }
            }
        }
    }

    private var statusColor: Color {
        switch model.colorName {
        case "red":
            return theme.red
        case "orange", "yellow":
            return theme.orange
        default:
            return theme.green
        }
    }

    private func quotaTint(usedFraction: Double) -> Color {
        AccountUsageTint.color(progress: usedFraction, isAvailable: model.colorName != "red", isRateLimited: false)
    }

    private func availabilityText(usedFraction: Double) -> String {
        String(format: "%.1f%%", max(0, min(1, 1 - usedFraction)) * 100)
    }

    private func errorCount(_ poolSummary: AccountPoolSummary) -> Int {
        max(0, poolSummary.accountCount - poolSummary.schedulableCount - poolSummary.rateLimitedCount)
    }
}

private struct SummaryStatCard: View {
    let value: String
    let label: String
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.text)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.elevatedCard)
                .shadow(color: theme.shadow, radius: 8, y: 3)
        )
    }
}

private struct MenuFooterInfoView: View {
    let model: StatusViewModel
    let lastError: QuotaErrorKind?
    let theme: MenuTheme

    var body: some View {
        HStack(spacing: 0) {
            Text(footerText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(lastError == nil ? theme.secondary : theme.red)
    }

    private var footerText: String {
        if lastError != nil {
            return model.lastErrorText
        }

        let serviceTime = model.lastUpdatedText.replacingOccurrences(of: "服务更新 ", with: "")
        let clientTime = model.clientRefreshedText.replacingOccurrences(of: "本机刷新 ", with: "")
        let duration = model.requestDurationText.replacingOccurrences(of: "请求耗时 ", with: "")
        return "更新 \(serviceTime) · 本机 \(clientTime) · \(duration)"
    }
}

private struct MenuQuotaProgressRow: View {
    let label: String
    let progress: Double
    let tint: Color
    let percentText: String
    let theme: MenuTheme

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondary)
                .frame(width: 24, alignment: .leading)

            CompactUsageBar(progress: progress, tint: tint, track: theme.control)
                .frame(maxWidth: .infinity)
                .frame(height: 6)

            Text(percentText)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text)
                .frame(width: 54, alignment: .trailing)
        }
    }
}

private struct AccountDetailsListView: View {
    let title: String
    let systemImage: String
    let rows: [AccountQuotaRowViewModel]
    let results: [Int: ModelDegradationCheckResult]
    let errors: [Int: String]
    let inFlightAccountIDs: Set<Int>
    let priorityErrors: [Int: String]
    let priorityInFlightAccountIDs: Set<Int>
    let keyAvailabilitySamples: [Int: [KeyAvailabilitySample]]
    let keyAvailabilityInFlightAccountIDs: Set<Int>
    let theme: MenuTheme
    let updatePriority: (AccountQuotaRowViewModel, Int) async -> Void
    let runModelCheck: (AccountQuotaRowViewModel) async -> Void

    @State private var showsFullInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("账号明细", systemImage: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondary)
                Text("\(rows.count) 个")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.tertiary)
                Spacer()
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.control))
                Button {
                    showsFullInfo.toggle()
                } label: {
                    Label(showsFullInfo ? "精简" : "完整信息", systemImage: showsFullInfo ? "line.3.horizontal.decrease" : "list.bullet.rectangle")
                }
                .buttonStyle(MenuToolButtonStyle(theme: theme))
                .controlSize(.small)
            }
            .padding(.top, 2)

            MenuAccountScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rows) { row in
                        AccountDetailRow(
                            row: row,
                            modelCheckResult: results[row.id],
                            modelCheckError: errors[row.id],
                            isModelCheckRunning: inFlightAccountIDs.contains(row.id),
                            priorityUpdateError: priorityErrors[row.id],
                            isPriorityUpdateRunning: priorityInFlightAccountIDs.contains(row.id),
                            keyAvailabilitySummary: KeyAvailabilitySummary(
                                accountID: row.id,
                                samples: keyAvailabilitySamples[row.id] ?? []
                            ),
                            isKeyAvailabilityRunning: keyAvailabilityInFlightAccountIDs.contains(row.id),
                            showsFullInfo: showsFullInfo,
                            theme: theme,
                            updatePriority: { priority in Task { await updatePriority(row, priority) } },
                            runModelCheck: { Task { await runModelCheck(row) } }
                        )
                    }
                }
                .frame(width: MenuLayout.contentWidth, alignment: .leading)
            }
            .frame(height: listViewportHeight)
        }
    }

    private var listViewportHeight: CGFloat {
        let contentHeight = rows.reduce(CGFloat(0)) { partialHeight, row in
            partialHeight + estimatedRowHeight(row)
        } + max(0, CGFloat(rows.count - 1) * 6)
        let maxHeight: CGFloat = showsFullInfo ? 520 : 260
        return min(maxHeight, max(1, contentHeight))
    }

    private func estimatedRowHeight(_ row: AccountQuotaRowViewModel) -> CGFloat {
        if showsFullInfo {
            return row.supportsUsageWindows ? 210 : 126
        }

        return row.supportsUsageWindows ? 66 : 44
    }
}

private struct MenuAccountScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: MenuLayout.contentWidth, height: 1)
        scrollView.documentView = hostingView
        context.coordinator.hostingView = hostingView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let hostingView = context.coordinator.hostingView else {
            return
        }

        hostingView.rootView = content
        DispatchQueue.main.async {
            let width = max(1, scrollView.contentSize.width)
            hostingView.frame.size.width = width
            let fittingSize = hostingView.fittingSize
            hostingView.frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: max(fittingSize.height, scrollView.contentSize.height)
            )
        }
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
    }
}

private struct AccountDetailRow: View {
    let row: AccountQuotaRowViewModel
    let modelCheckResult: ModelDegradationCheckResult?
    let modelCheckError: String?
    let isModelCheckRunning: Bool
    let priorityUpdateError: String?
    let isPriorityUpdateRunning: Bool
    let keyAvailabilitySummary: KeyAvailabilitySummary
    let isKeyAvailabilityRunning: Bool
    let showsFullInfo: Bool
    let theme: MenuTheme
    let updatePriority: (Int) -> Void
    let runModelCheck: () -> Void

    @State private var draftPriority = 1

    var body: some View {
        Group {
            if showsFullInfo {
                AccountRichCard(
                    row: row,
                    statusColor: statusColor,
                    draftPriority: $draftPriority,
                    modelCheckResult: modelCheckResult,
                    modelCheckError: modelCheckError,
                    isModelCheckRunning: isModelCheckRunning,
                    priorityUpdateError: priorityUpdateError,
                    isPriorityUpdateRunning: isPriorityUpdateRunning,
                    keyAvailabilitySummary: keyAvailabilitySummary,
                    isKeyAvailabilityRunning: isKeyAvailabilityRunning,
                    updatePriority: updatePriority,
                    runModelCheck: runModelCheck
                )
                .environment(\.menuTheme, theme)
            } else {
                AccountCompactRow(
                    row: row,
                    statusColor: statusColor,
                    keyAvailabilitySummary: keyAvailabilitySummary,
                    isKeyAvailabilityRunning: isKeyAvailabilityRunning,
                    isCondensed: false,
                    theme: theme
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, row.supportsUsageWindows ? 9 : 7)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
            }
        }
        .onAppear {
            draftPriority = row.priority ?? 1
        }
        .onChange(of: row.priority) { _, newPriority in
            draftPriority = newPriority ?? 1
        }
    }

    private var statusColor: Color {
        if row.isRateLimited {
            return theme.orange
        }

        return row.isAvailable ? theme.green : theme.red
    }

    private var borderColor: Color {
        if row.isRateLimited {
            return theme.orange.opacity(0.36)
        }
        if row.isAvailable == false {
            return theme.red.opacity(0.40)
        }
        return theme.separator
    }
}

private struct AccountRichCard: View {
    @Environment(\.menuTheme) private var theme
    let row: AccountQuotaRowViewModel
    let statusColor: Color
    @Binding var draftPriority: Int
    let modelCheckResult: ModelDegradationCheckResult?
    let modelCheckError: String?
    let isModelCheckRunning: Bool
    let priorityUpdateError: String?
    let isPriorityUpdateRunning: Bool
    let keyAvailabilitySummary: KeyAvailabilitySummary
    let isKeyAvailabilityRunning: Bool
    let updatePriority: (Int) -> Void
    let runModelCheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: row.supportsUsageWindows ? 8 : 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: row.supportsUsageWindows ? 5 : 4) {
                    HStack(spacing: 6) {
                        Text(row.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Text(row.priorityText)
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(theme.secondary)
                    }

                    HStack(spacing: 6) {
                        InfoPill(text: row.accountTypeText, theme: theme)
                        Text(row.stateText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(statusColor)
                        if row.metadataText.isEmpty == false {
                            Text(row.metadataText)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 8)

                Button {
                    runModelCheck()
                } label: {
                    if isModelCheckRunning {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 14, height: 14)
                    } else {
                        Label("检测", systemImage: "cpu")
                    }
                }
                .buttonStyle(MenuToolButtonStyle(theme: theme))
                .help("手动检测模型")
                .disabled(isModelCheckRunning)
            }

            if row.supportsUsageWindows {
                HStack(spacing: 8) {
                    AccountUsageCard(
                        label: "5h",
                        progress: row.fiveHourFraction,
                        tint: AccountUsageTint.color(
                            progress: row.fiveHourFraction,
                            isAvailable: row.isAvailable,
                            isRateLimited: row.isRateLimited
                        ),
                        usedText: row.fiveHourPercentText,
                        remainingText: row.fiveHourRemainingText,
                        resetText: row.fiveHourResetText,
                        statsText: row.fiveHourStatsText,
                        theme: theme
                    )
                    AccountUsageCard(
                        label: "7d",
                        progress: row.sevenDayFraction,
                        tint: AccountUsageTint.color(
                            progress: row.sevenDayFraction,
                            isAvailable: row.isAvailable,
                            isRateLimited: row.isRateLimited
                        ),
                        usedText: row.sevenDayPercentText,
                        remainingText: row.sevenDayRemainingText,
                        resetText: row.sevenDayResetText,
                        statsText: row.sevenDayStatsText,
                        theme: theme
                    )
                }
            } else {
                KeyAvailabilityDetailView(
                    summary: keyAvailabilitySummary,
                    isRunning: isKeyAvailabilityRunning
                )
            }

            HStack(spacing: 8) {
                Text("分组 \(row.supportsUsageWindows ? groupValue(row.groupText) : "--")")
                Text("并发 \(row.concurrencyText)")
                Spacer(minLength: 6)
                AccountPriorityEditor(
                    priority: $draftPriority,
                    currentPriority: row.priority,
                    isRunning: isPriorityUpdateRunning,
                    error: priorityUpdateError,
                    updatePriority: updatePriority
                )
                .environment(\.menuTheme, theme)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.secondary)

            if row.isRateLimited || row.isAvailable == false {
                HStack(spacing: 8) {
                    Image(systemName: row.isRateLimited ? "pause.circle" : "exclamationmark.circle")
                    Text(row.isRateLimited ? "账号额度用尽，暂不判断降智" : "账号不可用，请检查账号状态")
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(row.isRateLimited ? theme.orange : theme.red)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(row.isRateLimited ? theme.warningBackground : theme.red.opacity(0.10))
                )
            }

            if isModelCheckRunning || modelCheckResult != nil || modelCheckError != nil {
                AccountModelDegradationCheckView(
                    result: modelCheckResult,
                    error: modelCheckError,
                    isRunning: isModelCheckRunning
                )
            }
        }
        .padding(row.supportsUsageWindows ? 10 : 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }

    private var borderColor: Color {
        if row.isRateLimited {
            return theme.orange.opacity(0.36)
        }
        if row.isAvailable == false {
            return theme.red.opacity(0.40)
        }
        return theme.separator
    }

    private func groupValue(_ text: String) -> String {
        text.replacingOccurrences(of: "分组 ", with: "")
    }
}

private struct AccountFullInfoView: View {
    let row: AccountQuotaRowViewModel
    let statusColor: Color
    @Binding var draftPriority: Int
    let modelCheckResult: ModelDegradationCheckResult?
    let modelCheckError: String?
    let isModelCheckRunning: Bool
    let priorityUpdateError: String?
    let isPriorityUpdateRunning: Bool
    let keyAvailabilitySummary: KeyAvailabilitySummary
    let isKeyAvailabilityRunning: Bool
    let updatePriority: (Int) -> Void
    let runModelCheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                InfoPill(text: row.accountTypeText)
                Text(row.stateText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(statusColor)
                Spacer(minLength: 6)
                Button {
                    runModelCheck()
                } label: {
                    if isModelCheckRunning {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 14, height: 14)
                    } else {
                        Label("检测", systemImage: "cpu")
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("手动检测模型")
                .disabled(isModelCheckRunning)
            }

            VStack(alignment: .leading, spacing: 5) {
                if row.metadataText.isEmpty == false {
                    DetailLine(label: "账号", value: row.metadataText)
                }
                DetailLine(label: "并发", value: row.concurrencyText)
                if row.supportsUsageWindows {
                    DetailLine(label: "分组", value: groupValue(row.groupText))
                }
                AccountPriorityEditor(
                    priority: $draftPriority,
                    currentPriority: row.priority,
                    isRunning: isPriorityUpdateRunning,
                    error: priorityUpdateError,
                    updatePriority: updatePriority
                )
            }

            if row.supportsUsageWindows {
                VStack(alignment: .leading, spacing: 6) {
                    AccountUsageMiniBar(
                    label: "5h",
                    progress: row.fiveHourFraction,
                    tint: AccountUsageTint.color(
                        progress: row.fiveHourFraction,
                        isAvailable: row.isAvailable,
                        isRateLimited: row.isRateLimited
                    ),
                    usedText: row.fiveHourPercentText,
                    remainingText: row.fiveHourRemainingText,
                    resetText: row.fiveHourResetText,
                    statsText: row.fiveHourStatsText
                    )
                    AccountUsageMiniBar(
                    label: "7d",
                    progress: row.sevenDayFraction,
                    tint: AccountUsageTint.color(
                        progress: row.sevenDayFraction,
                        isAvailable: row.isAvailable,
                        isRateLimited: row.isRateLimited
                    ),
                    usedText: row.sevenDayPercentText,
                    remainingText: row.sevenDayRemainingText,
                    resetText: row.sevenDayResetText,
                    statsText: row.sevenDayStatsText
                    )
                }
            } else {
                KeyAvailabilityDetailView(
                    summary: keyAvailabilitySummary,
                    isRunning: isKeyAvailabilityRunning
                )
            }

            if isModelCheckRunning || modelCheckResult != nil || modelCheckError != nil {
                AccountModelDegradationCheckView(
                    result: modelCheckResult,
                    error: modelCheckError,
                    isRunning: isModelCheckRunning
                )
            }
        }
    }

    private func groupValue(_ text: String) -> String {
        text.replacingOccurrences(of: "分组 ", with: "")
    }

}

private struct InfoPill: View {
    let text: String
    let theme: MenuTheme?

    init(text: String, theme: MenuTheme? = nil) {
        self.text = text
        self.theme = theme
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme?.text ?? .secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(theme?.elevatedCard ?? Color(nsColor: .controlBackgroundColor))
            )
    }
}

private struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .leading)
            Text(value.isEmpty ? "--" : value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
    }
}

private struct AccountPriorityEditor: View {
    @Environment(\.menuTheme) private var theme
    @Binding var priority: Int
    let currentPriority: Int?
    let isRunning: Bool
    let error: String?
    let updatePriority: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("优先级")
                HStack(spacing: 4) {
                    Button {
                        priority = max(1, priority - 1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(theme.control))
                    }
                    .buttonStyle(.borderless)
                    .disabled(priority <= 1 || isRunning)

                    Text("\(priority)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.primary)
                        .frame(minWidth: 24)

                    Button {
                        priority = min(1000, priority + 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(theme.control))
                    }
                    .buttonStyle(.borderless)
                    .disabled(priority >= 1000 || isRunning)
                }
                .help("Sub2API 调度优先级，数字越小越优先")

                Button {
                    updatePriority(priority)
                } label: {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 14, height: 14)
                    } else {
                        Label("保存", systemImage: "checkmark")
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(isRunning || priority == (currentPriority ?? 1))

                Spacer(minLength: 0)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
}

private struct AccountCompactRow: View {
    let row: AccountQuotaRowViewModel
    let statusColor: Color
    let keyAvailabilitySummary: KeyAvailabilitySummary
    let isKeyAvailabilityRunning: Bool
    let isCondensed: Bool
    let theme: MenuTheme

    var body: some View {
        if row.supportsUsageWindows {
            HStack(alignment: .top, spacing: 10) {
                AccountCompactIdentity(
                    name: row.name,
                    priorityText: row.priorityText,
                    stateText: row.stateText,
                    statusColor: statusColor,
                    theme: theme
                )
                .frame(width: 86, alignment: .leading)

                HStack(spacing: 10) {
                    AccountCompactUsagePair(
                        label: "5h",
                        progress: row.fiveHourFraction,
                        tint: AccountUsageTint.color(
                            progress: row.fiveHourFraction,
                            isAvailable: row.isAvailable,
                            isRateLimited: row.isRateLimited
                        ),
                        percentText: row.fiveHourPercentText,
                        resetText: compactResetText(row.fiveHourResetText),
                        theme: theme
                    )
                    AccountCompactUsagePair(
                        label: "7d",
                        progress: row.sevenDayFraction,
                        tint: AccountUsageTint.color(
                            progress: row.sevenDayFraction,
                            isAvailable: row.isAvailable,
                            isRateLimited: row.isRateLimited
                        ),
                        percentText: row.sevenDayPercentText,
                        resetText: compactResetText(row.sevenDayResetText),
                        theme: theme
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(spacing: 8) {
                AccountCompactIdentity(
                    name: row.name,
                    priorityText: row.priorityText,
                    stateText: row.stateText,
                    statusColor: statusColor,
                    theme: theme
                )
                .frame(width: 120, alignment: .leading)

                if isCondensed {
                    Text(keyCondensedText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    CompactKeyAvailabilityView(
                        summary: keyAvailabilitySummary,
                        isRunning: isKeyAvailabilityRunning,
                        theme: theme
                    )
                }
            }
        }
    }

    private func compactResetText(_ text: String) -> String {
        text.replacingOccurrences(of: "重置 ", with: "")
    }

    private var keyCondensedText: String {
        guard let percent = keyAvailabilitySummary.availabilityPercent else {
            return "等待检测"
        }

        return String(format: "24h %.1f%%", percent)
    }
}

private struct AccountCompactIdentity: View {
    let name: String
    let priorityText: String
    let stateText: String
    let statusColor: Color
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            HStack(spacing: 5) {
                Text(priorityText)
                    .font(.system(size: 11.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(
                        Capsule()
                            .fill(theme.control)
                    )

                Text(stateText)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }
}

private struct CompactKeyAvailabilityView: View {
    let summary: KeyAvailabilitySummary
    let isRunning: Bool
    let theme: MenuTheme

    var body: some View {
        HStack(spacing: 6) {
            UptimeSparkline(samples: displaySamples(limit: 24), barWidth: 2.5, height: 14)
                .frame(width: 83, height: 14, alignment: .leading)

            Text(percentText)
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(theme.secondary)
                .frame(width: 44, alignment: .leading)

            Text(latencyText)
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(theme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRunning {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var percentText: String {
        guard let percent = summary.availabilityPercent else {
            return "--"
        }

        return String(format: "%.0f%%", percent)
    }

    private var latencyText: String {
        guard let latency = summary.latestLatency else {
            return "--"
        }

        return String(format: "%.2fs", latency)
    }

    private func displaySamples(limit: Int) -> [KeyAvailabilitySample?] {
        let samples = Array(summary.samples.suffix(limit))
        return Array(repeating: nil, count: max(0, limit - samples.count)) + samples.map(Optional.some)
    }
}

private struct KeyAvailabilityDetailView: View {
    let summary: KeyAvailabilitySummary
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                UptimeSparkline(samples: displaySamples(limit: 48), barWidth: 2.7, height: 14)
                    .frame(width: 174, height: 14, alignment: .leading)

                Text("24h \(percentText)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(latencyText)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 12, height: 12)
                }
            }

            Text(detailText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var percentText: String {
        guard let percent = summary.availabilityPercent else {
            return "--"
        }

        return String(format: "%.1f%%", percent)
    }

    private var latencyText: String {
        guard let latency = summary.latestLatency else {
            return "延迟 --"
        }

        return String(format: "延迟 %.2fs", latency)
    }

    private var detailText: String {
        guard summary.sampleCount > 0 else {
            return "等待检测 · 每 5 分钟采样一次"
        }

        return "近 \(summary.windowHours) 小时 \(summary.availableCount)/\(summary.sampleCount) 次成功"
    }

    private func displaySamples(limit: Int) -> [KeyAvailabilitySample?] {
        let samples = Array(summary.samples.suffix(limit))
        return Array(repeating: nil, count: max(0, limit - samples.count)) + samples.map(Optional.some)
    }
}

private struct UptimeSparkline: View {
    let samples: [KeyAvailabilitySample?]
    let barWidth: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 1) {
            ForEach(samples.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color(for: samples[index]))
                    .frame(width: barWidth, height: height)
            }
        }
    }

    private func color(for sample: KeyAvailabilitySample?) -> Color {
        guard let sample else {
            return Color.secondary.opacity(0.18)
        }

        return sample.isAvailable ? Color.green.opacity(0.86) : Color.red.opacity(0.86)
    }
}

private struct AccountCompactUsagePair: View {
    let label: String
    let progress: Double
    let tint: Color
    let percentText: String
    let resetText: String
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.text)
                    .frame(width: 20, alignment: .leading)
                Spacer(minLength: 0)
                Text(percentText)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(width: 46, alignment: .trailing)
            }

            CompactUsageBar(progress: progress, tint: tint, track: theme.control)
                .frame(height: 6)

            Text(resetText)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(width: 148, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.elevatedCard.opacity(theme.isDark ? 0.72 : 0.86))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.separator, lineWidth: 1)
                )
        )
    }
}

private enum AccountUsageTint {
    static func color(progress: Double, isAvailable: Bool, isRateLimited: Bool) -> Color {
        if isRateLimited {
            return Color(red: 0.82, green: 0.46, blue: 0.02)
        }
        if isAvailable == false {
            return Color(red: 0.78, green: 0.12, blue: 0.12)
        }

        switch progress {
        case 0.95...:
            return Color(red: 0.78, green: 0.12, blue: 0.12)
        case 0.80..<0.95:
            return Color(red: 0.82, green: 0.46, blue: 0.02)
        case 0.60..<0.80:
            return Color(red: 0.68, green: 0.54, blue: 0.02)
        default:
            return Color(red: 0.00, green: 0.48, blue: 0.27)
        }
    }
}

private struct AccountUsageMiniBar: View {
    let label: String
    let progress: Double
    let tint: Color
    let usedText: String
    let remainingText: String
    let resetText: String
    let statsText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .leading)

                CompactUsageBar(progress: progress, tint: tint, track: Color.primary.opacity(0.13))
                    .frame(width: 58, height: 5)

                Text("已用 \(usedText)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(width: 82, alignment: .leading)
                Text(remainingText)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 74, alignment: .leading)
                Text(resetText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                Text("")
                    .frame(width: 16)
                Text(statsText)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }
}

private struct AccountUsageCard: View {
    let label: String
    let progress: Double
    let tint: Color
    let usedText: String
    let remainingText: String
    let resetText: String
    let statsText: String
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(label == "5h" ? theme.blue : Color(red: 0.0, green: 0.48, blue: 0.36))
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(label == "5h" ? theme.blueSoft : theme.mint)
                    )

                Text(availableText)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(availablePercent <= 0 ? theme.red : tint)

                Spacer()

                Text(usedText)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theme.secondary)
            }

            CompactUsageBar(progress: availableFraction, tint: tint, track: theme.control)
                .frame(height: 6)

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    AccountUsageMetric(label: "已用", value: usedText, theme: theme)
                    AccountUsageMetric(label: "重置", value: resetValue, theme: theme)
                    AccountUsageMetric(label: "Req", value: statPart(index: 0), theme: theme)
                }
                GridRow {
                    AccountUsageMetric(label: "Token", value: statPart(index: 1), theme: theme)
                    AccountUsageMetric(label: "A", value: costValue(prefix: "A"), theme: theme)
                    AccountUsageMetric(label: "U", value: costValue(prefix: "U"), theme: theme)
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(theme.elevatedCard.opacity(theme.isDark ? 0.75 : 0.72))
        )
    }

    private var availablePercent: Double {
        availableFraction * 100
    }

    private var availableFraction: Double {
        max(0, min(1, 1 - progress))
    }

    private var availableText: String {
        String(format: "可用 %.1f%%", availablePercent)
    }

    private var resetValue: String {
        resetText.replacingOccurrences(of: "重置 ", with: "")
    }

    private func statPart(index: Int) -> String {
        let parts = statsText.components(separatedBy: " · ")
        guard parts.indices.contains(index) else {
            return "--"
        }
        if index == 0 {
            return parts[index].replacingOccurrences(of: " req", with: "")
        }
        return parts[index]
    }

    private func costValue(prefix: String) -> String {
        statsText.components(separatedBy: " · ")
            .first { $0.hasPrefix("\(prefix) ") }?
            .replacingOccurrences(of: "\(prefix) ", with: "") ?? "$0.00"
    }
}

private struct AccountUsageMetric: View {
    let label: String
    let value: String
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 54, alignment: .leading)
    }
}

private struct APIKeyUsageView: View {
    let row: APIKeyUsageRowViewModel
    let theme: MenuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label("API Key 检查", systemImage: "key")
                    .font(.system(size: 12.5, weight: .semibold))
                Spacer(minLength: 6)
                Text(row.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(row.isActive ? .green : .red)
            }

            HStack(spacing: 6) {
                Text(row.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(row.keyPreview)
                    .font(.system(size: 12).monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(row.groupText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(row.usageText)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: 10) {
                Text(row.quotaText)
                Text(row.expiresText)
                Text(row.lastUsedText)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
    }
}

private struct AccountModelDegradationCheckView: View {
    let result: ModelDegradationCheckResult?
    let error: String?
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isRunning {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    ModelCheckMetric(label: "状态", value: "检测中", color: .secondary)
                    ModelCheckMetric(label: "降智", value: "--", color: .secondary)
                    ModelCheckMetric(label: "模型", value: "--", color: .secondary)
                    ModelCheckMetric(label: "延迟", value: "--", color: .secondary)
                }
            } else if let error {
                HStack(spacing: 8) {
                    ModelCheckMetric(label: "状态", value: "检测失败", color: .red)
                    ModelCheckMetric(label: "降智", value: "--", color: .secondary)
                    ModelCheckMetric(label: "模型", value: "--", color: .secondary)
                    ModelCheckMetric(label: "延迟", value: "--", color: .secondary)
                }
                .help(error)
            } else if let result {
                HStack(spacing: 8) {
                    ModelCheckMetric(label: "状态", value: availabilityText(result.status), color: availabilityColor(result.status))
                    ModelCheckMetric(label: "降智", value: result.status.rawValue, color: statusColor(result.status))
                    ModelCheckMetric(label: "模型", value: result.responseModel ?? result.targetModel, color: .secondary)
                    ModelCheckMetric(label: "延迟", value: latencyText(result.latency), color: .secondary)
                }
                .font(.system(size: 12))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            }
        }
    }

    private func availabilityText(_ status: ModelDegradationStatus) -> String {
        switch status {
        case .unavailable, .failed:
            return "不可用"
        default:
            return "可用"
        }
    }

    private func availabilityColor(_ status: ModelDegradationStatus) -> Color {
        switch status {
        case .unavailable, .failed:
            return .red
        default:
            return .green
        }
    }

    private func latencyText(_ latency: TimeInterval?) -> String {
        guard let latency else {
            return "--"
        }

        return String(format: "%.2fs", latency)
    }

    private func statusColor(_ status: ModelDegradationStatus) -> Color {
        switch status {
        case .normal:
            return .green
        case .watch:
            return .yellow
        case .suspicious:
            return .orange
        case .modelMismatch, .unavailable, .highRisk, .failed:
            return .red
        }
    }
}

private struct ModelCheckMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(color)
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }
}

private struct CompactUsageBar: View {
    let progress: Double
    let tint: Color
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, min(1, progress)) * proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.10), lineWidth: 0.7)
                    )
                Capsule()
                    .fill(tint)
                    .frame(width: max(width, progress > 0 ? 3 : 0))
            }
        }
        .accessibilityHidden(true)
    }
}
