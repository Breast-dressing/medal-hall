import SwiftUI

/// HAR 导入预览（对应原 Web 版 harModal）：按成员分组、可折叠、确认导入。
struct HARPreviewSheet: View {
    let result: HARImportResult
    var onImport: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.fileName)
                                .font(.system(size: 15, weight: .medium))
                            Text("解析文件")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Text(result.summaryText)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                }

                ForEach(result.groups) { group in
                    Section {
                        DisclosureGroup(isExpanded: binding(for: group.name)) {
                            ForEach(Array(group.records.enumerated()), id: \.offset) { pair in
                                recordRow(pair.element)
                            }
                        } label: {
                            memberLabel(group)
                        }
                    }
                }
            }
            .navigationTitle("导入荣誉记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        onImport()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
            .onAppear {
                if expanded.isEmpty, let first = result.groups.first {
                    expanded.insert(first.name)
                }
            }
        }
    }

    private func binding(for name: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(name) },
            set: { isOn in
                if isOn {
                    expanded.insert(name)
                } else {
                    expanded.remove(name)
                }
            }
        )
    }

    private func memberLabel(_ group: HARMemberGroup) -> some View {
        HStack(spacing: 10) {
            RemoteAvatar(url: group.avatar, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(size: 15, weight: .medium))
                HStack(spacing: 6) {
                    if !group.medalText.isEmpty {
                        TagPill(text: group.medalText)
                    }
                    if !group.fanBadge.isEmpty {
                        TagPill(
                            text: group.fanBadge,
                            color: Theme.orange,
                            background: Theme.orange.opacity(0.12)
                        )
                    }
                }
            }

            Spacer()

            Text("\(group.records.count) 条")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func recordRow(_ record: ImportedHonorRecord) -> some View {
        HStack(spacing: 8) {
            Text(dateText(record.date))
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 92, alignment: .leading)
            Text(record.taskName.isEmpty ? "未命名任务" : record.taskName)
                .font(.system(size: 14))
                .lineLimit(1)
            Spacer()
            Text(record.value.isEmpty ? "--" : record.value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor(record.value))
        }
    }

    private func dateText(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"^\d{4}年"#, with: "", options: .regularExpression)
    }

    private func valueColor(_ text: String) -> Color {
        let value = Fmt.honorNumber(text)
        if value > 0 { return Theme.green }
        if value < 0 { return Theme.red }
        return .primary
    }
}
