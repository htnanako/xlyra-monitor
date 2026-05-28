import SwiftUI
import Sub2APIQuotaCore

struct StatusWindowView: View {
    @ObservedObject var state: AppState

    var body: some View {
        let model = StatusViewModel(
            status: state.status,
            snapshot: state.quotaSnapshot,
            lastError: state.lastError,
            lastRequestDuration: state.lastRequestDuration
        )

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                StatusBadge(colorName: model.colorName)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title)
                        .font(.title2.weight(.semibold))
                    Text(model.subtitle)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if state.quotaSnapshot?.poolSummary != nil {
                AccountPoolProgressView(model: model)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("服务更新时间")
                        .foregroundStyle(.secondary)
                    Text(model.lastUpdatedText.replacingOccurrences(of: "服务更新 ", with: ""))
                }
                GridRow {
                    Text("本机刷新时间")
                        .foregroundStyle(.secondary)
                    Text(model.clientRefreshedText.replacingOccurrences(of: "本机刷新 ", with: ""))
                }
                GridRow {
                    Text("请求耗时")
                        .foregroundStyle(.secondary)
                    Text(model.requestDurationText.replacingOccurrences(of: "请求耗时 ", with: ""))
                }
                GridRow {
                    Text("连续失败")
                        .foregroundStyle(.secondary)
                    Text("\(state.consecutiveFailureCount)")
                }
                GridRow {
                    Text("最近错误")
                        .foregroundStyle(.secondary)
                    Text(state.lastError == nil ? "--" : model.lastErrorText.replacingOccurrences(of: "最近错误 ", with: ""))
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 440, minHeight: 260)
    }
}

struct AccountPoolProgressView: View {
    let model: StatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuotaWindowProgressRow(
                title: "5h",
                remainingText: model.fiveHourRemainingText,
                percentText: model.fiveHourUsedPercentText,
                progress: model.fiveHourUsedFraction,
                tint: Color(nsColor: MenuBarQuotaImageRenderer.color(for: model.fiveHourRiskColorName))
            )
            QuotaWindowProgressRow(
                title: "7d",
                remainingText: model.sevenDayRemainingText,
                percentText: model.sevenDayUsedPercentText,
                progress: model.sevenDayUsedFraction,
                tint: Color(nsColor: MenuBarQuotaImageRenderer.color(for: model.sevenDayRiskColorName))
            )

            HStack(spacing: 14) {
                Label(model.accountPoolText.replacingOccurrences(of: "账号池 ", with: ""), systemImage: "person.2")
                Label(model.concurrencyText.replacingOccurrences(of: "并发 ", with: ""), systemImage: "bolt.horizontal")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct QuotaWindowProgressRow: View {
    let title: String
    let remainingText: String
    let percentText: String
    let progress: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 28, alignment: .leading)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(tint)
                .accessibilityLabel(title)
                .accessibilityValue("\(remainingText)，已用 \(percentText)")
                .frame(width: 86)

            Text(percentText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)

            Text(remainingText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

struct SettingsWindowView: View {
    @ObservedObject var model: SettingsViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsTextFieldRow(title: "服务地址") {
                    TextField("http://127.0.0.1:18032", text: $model.serviceURLText)
                }
                SettingsTextFieldRow(title: "登录邮箱") {
                    TextField("email@example.com", text: $model.emailText)
                }
                SettingsTextFieldRow(title: "登录密码") {
                    SecureField(model.passwordPlaceholder, text: $model.apiKeyText)
                }
                SettingsTextFieldRow(title: "检查 Key") {
                    SecureField(model.inspectedAPIKeyPlaceholder, text: $model.inspectedAPIKeyText)
                }
                SettingsTextFieldRow(title: "低额度阈值") {
                    TextField("10", text: $model.thresholdText)
                }
                SettingsTextFieldRow(title: "刷新间隔") {
                    TextField("60", text: $model.refreshIntervalText)
                }

                Toggle("状态栏显示账号数", isOn: $model.showsMenuBarNumbers)
                Picker("主题", selection: $model.themeMode) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 340)
                .onChange(of: model.themeMode) { _, newThemeMode in
                    model.updateThemeMode(newThemeMode)
                }
                Toggle("开机自启动", isOn: $model.launchAtLogin)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Label("模型降智检测", systemImage: "cpu")
                    .font(.system(size: 12.5, weight: .semibold))

                SettingsTextFieldRow(title: "默认模型") {
                    TextField("gpt-4.1", text: $model.modelCheckModelText)
                }
            }

            Divider()

            HStack {
                Label("账号导入", systemImage: "tray.and.arrow.down")
                Spacer()
                Button {
                    openWindow(id: "account-import")
                    WindowFocusHelper.focusWindow(title: "Sub2API 账号导入")
                } label: {
                    Label("打开导入", systemImage: "arrow.up.doc")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                if let successMessage = model.successMessage {
                    Text(successMessage)
                        .foregroundStyle(.green)
                }
                if let hint = model.notificationDeniedHint {
                    HStack(spacing: 10) {
                        Label(hint, systemImage: "bell.slash")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("请求通知权限") {
                            Task { await model.requestNotificationPermission() }
                        }
                        .disabled(model.isRefreshingNotificationPermission)
                        Button("打开通知设置") {
                            Task { await model.openNotificationSettings() }
                        }
                        .disabled(model.isRefreshingNotificationPermission)
                    }
                    .font(.caption)
                }
            }
            .font(.caption)

            HStack {
                Spacer()
                Button {
                    Task { await model.save() }
                } label: {
                    Label(model.isSaving ? "保存中" : "保存", systemImage: model.isSaving ? "hourglass" : "checkmark.circle")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isSaving)
                .frame(width: 82, height: 28)
            }
        }
        .padding(20)
        .frame(width: 460)
        .frame(minHeight: 430)
    }
}

struct SettingsTextFieldRow<Field: View>: View {
    let title: String
    @ViewBuilder let field: () -> Field

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)

            field()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
                .frame(width: 260, alignment: .leading)
        }
    }
}
