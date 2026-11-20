import Foundation

/// 荣誉记录的折叠、周区间与近 7 天聚合。
enum HonorAggregator {
    /// 按日期折叠，日期倒序；同一天内按时间倒序。
    static func groups(from records: [HonorRecord]) -> [HonorDayGroup] {
        var map: [String: [HonorRecord]] = [:]
        for record in records {
            map[HonorDate.dateKey(record.date), default: []].append(record)
        }
        let result = map.map { key, list -> HonorDayGroup in
            let sorted = list.sorted { lhs, rhs in
                let left = HonorDate.parse(lhs.date)?.timeIntervalSince1970 ?? 0
                let right = HonorDate.parse(rhs.date)?.timeIntervalSince1970 ?? 0
                return left > right
            }
            let total = sorted.reduce(0) { $0 + $1.numericValue }
            return HonorDayGroup(dateKey: key, records: sorted, total: total)
        }
        return result.sorted { lhs, rhs in
            let left = HonorDate.parse(lhs.dateKey)?.timeIntervalSince1970 ?? 0
            let right = HonorDate.parse(rhs.dateKey)?.timeIntervalSince1970 ?? 0
            if left != right {
                return left > right
            }
            return lhs.dateKey > rhs.dateKey
        }
    }

    /// 最近 7 天（含今天）的分组。
    static func weekGroups(
        _ groups: [HonorDayGroup],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [HonorDayGroup] {
        groups.filter { isWithinLastWeek($0.dateKey, now: now, calendar: calendar) }
    }

    static func isWithinLastWeek(
        _ dateKey: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let date = HonorDate.parse(dateKey) else { return false }
        let startOfToday = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -6, to: startOfToday),
              let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return false
        }
        return date >= start && date < end
    }

    /// 本周周一到周日的 7 个值，用于「近 7 天荣誉」柱状图。
    static func weeklyValues(
        _ records: [HonorRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Double] {
        var values = [Double](repeating: 0, count: 7)
        let weekday = calendar.component(.weekday, from: now) // 1 = 周日
        let daysFromMonday = (weekday + 5) % 7
        let startOfToday = calendar.startOfDay(for: now)
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfToday) else {
            return values
        }
        for record in records {
            guard let date = HonorDate.parse(record.date) else { continue }
            let day = calendar.startOfDay(for: date)
            let diff = calendar.dateComponents([.day], from: monday, to: day).day ?? -1
            guard diff >= 0 && diff < 7 else { continue }
            values[diff] += record.numericValue
        }
        return values
    }

    static func total(_ records: [HonorRecord]) -> Double {
        records.reduce(0) { $0 + $1.numericValue }
    }
}
