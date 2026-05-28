import AppKit
import SwiftUI

struct AccountImportView: View {
    @ObservedObject var model: AccountImportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("账号导入")
                    .font(.title2.weight(.semibold))

                HStack(spacing: 8) {
                    TextField("zip/json 文件路径或导入目录", text: $model.pathText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        chooseZipFile()
                    } label: {
                        Label("选择文件", systemImage: "doc.badge.plus")
                    }

                    Button {
                        Task { await model.loadPathText(model.pathText) }
                    } label: {
                        Label("读取", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(model.pathText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isLoading)
                }

                HStack(spacing: 8) {
                    TextField("导入目录", text: $model.importDirectoryText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        chooseDirectory()
                    } label: {
                        Label("选择目录", systemImage: "folder")
                    }

                    Button {
                        Task { await model.scanImportDirectory() }
                    } label: {
                        Label("从目录扫描", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(model.isLoading || model.isImporting)
                }
            }

            Divider()

            if model.items.isEmpty {
                ContentUnavailableView(
                    "还没有待读取文件",
                    systemImage: "tray",
                    description: Text("选择 zip/json 文件，或从导入目录扫描未导入过的 codex_credentials 和 sub2 文件。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.items) { item in
                        AccountImportRow(item: item) { isSelected in
                            model.setSelected(item.id, isSelected: isSelected)
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 220)
            }

            Divider()

            HStack(spacing: 12) {
                if model.isLoading || model.isImporting || model.isCleaningRevokedAccounts {
                    ProgressView()
                        .scaleEffect(0.75)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else if let statusMessage = model.statusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("导入成功后会记录文件名，后续目录扫描会自动跳过。")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)

                Spacer()

                Button("清空导入历史", role: .destructive) {
                    model.clearHistory()
                }
                .disabled(model.isImporting || model.isCleaningRevokedAccounts)

                Button(role: .destructive) {
                    Task { await model.deleteRevoked401Accounts() }
                } label: {
                    Label("删除 401 错误账号", systemImage: "trash")
                }
                .disabled(model.isLoading || model.isImporting || model.isCleaningRevokedAccounts)

                Button {
                    Task { await model.importSelected() }
                } label: {
                    Label("导入选中文件", systemImage: "tray.and.arrow.down.fill")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    model.items.contains(where: \.isSelected) == false ||
                        model.isImporting ||
                        model.isLoading ||
                        model.isCleaningRevokedAccounts
                )
            }
        }
        .padding(24)
        .frame(minWidth: 680, minHeight: 480)
        .onAppear {
            model.refreshFromPreferences()
        }
    }

    private func chooseZipFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip, .json]

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        Task { await model.loadPathText(url.path) }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        model.importDirectoryText = url.path
        Task { await model.scanImportDirectory() }
    }
}

private struct AccountImportRow: View {
    let item: AccountImportItem
    let onSelectionChanged: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: onSelectionChanged
            ))
            .labelsHidden()
            .disabled(item.state == .importing || item.state == .imported)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(item.accountCount) 个账号", systemImage: "person.2")
                    Label("\(item.proxyCount) 个代理", systemImage: "network")
                    if let resultSummary = item.resultSummary {
                        Text(resultSummary)
                    }
                    if let errorMessage = item.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            AccountImportStateBadge(state: item.state)
        }
        .padding(.vertical, 5)
    }
}

private struct AccountImportStateBadge: View {
    let state: AccountImportItemState

    var body: some View {
        switch state {
        case .pending:
            Label("待导入", systemImage: "circle")
                .foregroundStyle(.secondary)
        case .importing:
            Label("导入中", systemImage: "arrow.clockwise")
                .foregroundStyle(.blue)
        case .imported:
            Label("已导入", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Label("失败", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
