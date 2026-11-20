import Foundation

/// 单条荣誉值记录（localStorage: member_honor_records_v1）。
struct HonorRecord: Codable, Identifiable, Hashable {
    var id: String
    var taskName: String
    var date: String
    var value: String

    init(id: String = UUID().uuidString, taskName: String, date: String, value: String) {
        self.id = id
        self.taskName = taskName
        self.date = date
        self.value = value
    }

    var numericValue: Double { Fmt.honorNumber(value) }
    var timeText: String { HonorDate.timeText(date) }
    var dayKey: String { HonorDate.dateKey(date) }
}

/// 按成员归并的荣誉记录。
struct HonorMemberStore: Codable, Identifiable, Hashable {
    var name: String
    var records: [HonorRecord]

    init(name: String, records: [HonorRecord] = []) {
        self.name = name
        self.records = records
    }

    var id: String { name }
}

/// 某一日折叠后的记录（对应原版 groupHonorRecords 的结果）。
struct HonorDayGroup: Identifiable, Hashable {
    var dateKey: String
    var records: [HonorRecord]
    var total: Double

    var id: String { dateKey }
    var countText: String { "\(records.count) 条 · 合计 \(Fmt.groupedInt(Int(total.rounded()))) 荣誉值" }
}

/// HAR 里抽出来的一条待导入记录。
struct ImportedHonorRecord: Hashable {
    var taskName: String
    var memberName: String
    var date: String
    var value: String
}

/// HAR 预览里按成员分组。
struct HARMemberGroup: Identifiable, Hashable {
    var name: String
    var avatar: String
    var medalText: String
    var fanBadge: String
    var records: [ImportedHonorRecord]

    var id: String { name }
}

/// HAR 解析结果（预览用）。
struct HARImportResult: Identifiable, Hashable {
    var id = UUID()
    var fileName: String
    var responseCount: Int
    var extractedCount: Int
    var keptCount: Int
    var records: [ImportedHonorRecord]
    var groups: [HARMemberGroup]

    var recordCount: Int { records.count }
    var memberCount: Int { groups.count }

    var summaryText: String {
        "共 \(recordCount) 条记录 · \(memberCount) 位成员"
    }
}
