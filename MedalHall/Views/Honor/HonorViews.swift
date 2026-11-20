import SwiftUI

/// 荣誉记录里的一天（折叠行）。
struct HonorDayRowView: View {
    let group: HonorDayGroup

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(HonorDate.dayLabel(group.dateKey))
                    .font(.system(size: 15, weight: .medium))
                Text(group.countText)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// 某个成员的全部荣誉值记录（按日期折叠）。
struct HonorRecordsView: View {
    let memberName: String

    @State private var groups: [HonorDayGroup] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if groups.isEmpty {
                    EmptyStateCard(text: "暂无荣誉值记录")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { pair in
                            NavigationLink(value: MedalRoute.honorDay(
                                memberName: memberName,
                                dateKey: pair.element.dateKey
                            )) {
                                HonorDayRowView(group: pair.element)
                            }
                            .buttonStyle(.plain)

                            if pair.offset < groups.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("\(memberName) · 荣誉值记录")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
    }

    private func reload() {
        groups = HonorAggregator.groups(from: Persistence.honorRecords(for: memberName))
    }
}

/// 某一天的记录（左滑删除，原版为自定义滑动手势）。
struct HonorDayView: View {
    let memberName: String
    let dateKey: String

    @State private var records: [HonorRecord] = []
    @State private var total: Double = 0

    var body: some View {
        List {
            Section {
                if records.isEmpty {
                    Text("当天暂无记录")
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    ForEach(records) { record in
                        recordRow(record)
                    }
                    .onDelete(perform: delete)
                }
            } header: {
                Text(summary)
            } footer: {
                Text("左滑记录可删除")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("\(memberName) · \(HonorDate.dayLabel(dateKey))")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
    }

    private var summary: String {
        "\(records.count) 条 · 合计 \(Fmt.groupedInt(Int(total.rounded()))) 荣誉值"
    }

    private func recordRow(_ record: HonorRecord) -> some View {
        HStack(spacing: 10) {
            Text(record.timeText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 46, alignment: .leading)

            Text(record.taskName.isEmpty ? "未命名任务" : record.taskName)
                .font(.system(size: 15))
                .lineLimit(1)

            Spacer()

            Text(record.value.isEmpty ? "--" : record.value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(valueColor(record))
        }
    }

    private func valueColor(_ record: HonorRecord) -> Color {
        if record.numericValue > 0 { return Theme.green }
        if record.numericValue < 0 { return Theme.red }
        return .primary
    }

    private func delete(_ offsets: IndexSet) {
        let ids = offsets.compactMap { records.indices.contains($0) ? records[$0].id : nil }
        for identifier in ids {
            Persistence.deleteHonorRecord(identifier)
        }
        reload()
    }

    private func reload() {
        let groups = HonorAggregator.groups(from: Persistence.honorRecords(for: memberName))
        let group = groups.first(where: { $0.dateKey == dateKey })
        records = group?.records ?? []
        total = group?.total ?? 0
    }
}
