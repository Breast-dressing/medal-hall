import Foundation

/// 数字与日期格式化，对应原 Web 版的 `toLocaleString('zh-CN')` 与荣誉记录日期解析。
enum Fmt {
    static func groupedInt(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func groupedNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded) < 1 {
            return value.formatted(.number.precision(.fractionLength(0...1)))
        }
        return Int(rounded).formatted(.number.grouping(.automatic))
    }

    /// 从「+944.3」「-12」「1,234」这类文本里抽出数字。
    static func honorNumber(_ text: String) -> Double {
        let filtered = text.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(filtered) ?? 0
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// 荣誉记录日期：兼容「2026年11月01日 12:34」与 ISO 格式。
enum HonorDate {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = format
        return formatter
    }

    static func parse(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let chinese = chineseComponents(text) {
            return Calendar.current.date(from: chinese)
        }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            if let date = formatter(format).date(from: text) {
                return date
            }
        }
        return nil
    }

    private static func chineseComponents(_ text: String) -> DateComponents? {
        guard let matched = RegexTool.captures(pattern: #"(\d{4})年(\d{1,2})月(\d{1,2})日(?:[\sT]+(\d{1,2}):(\d{2}))?"#, in: text),
              matched.count > 3,
              let yearText = matched[1], let year = Int(yearText),
              let monthText = matched[2], let month = Int(monthText),
              let dayText = matched[3], let day = Int(dayText) else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        var hour = 0
        var minute = 0
        if matched.count > 4, let hourText = matched[4], let parsedHour = Int(hourText) {
            hour = parsedHour
        }
        if matched.count > 5, let minuteText = matched[5], let parsedMinute = Int(minuteText) {
            minute = parsedMinute
        }
        components.hour = hour
        components.minute = minute
        return components
    }

    /// 折叠分组用的日期键：优先「2026年11月01日」，其次「2026-11-01」。
    static func dateKey(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let matched = RegexTool.firstMatch(pattern: #"^\d{4}年\d{1,2}月\d{1,2}日"#, in: text) {
            return matched
        }
        if let matched = RegexTool.firstMatch(pattern: #"^\d{4}-\d{2}-\d{2}"#, in: text) {
            return matched
        }
        let first = text.split(whereSeparator: { $0.isWhitespace }).first
        return first.map(String.init) ?? "未知日期"
    }

    /// 「今天 / 昨天 / 11月1日 · 周六」。与传入的 now 比较，便于测试与缓存。
    static func dayLabel(_ dateKey: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date = parse(dateKey) else { return dateKey }
        let startOfNow = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? 0
        if days == 0 { return "今天" }
        if days == 1 { return "昨天" }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let index = max(0, min(names.count - 1, weekday - 1))
        return "\(month)月\(day)日 · 周\(names[index])"
    }

    /// 记录里的时间：有 HH:mm 就用它，否则去掉年份。
    static func timeText(_ raw: String) -> String {
        if let time = RegexTool.firstMatch(pattern: #"\d{1,2}:\d{2}"#, in: raw) {
            return time
        }
        return raw.replacingOccurrences(of: #"^\d{4}年"#, with: "", options: .regularExpression)
    }
}

/// 轻量正则工具。
enum RegexTool {
    static func captures(pattern: String, in text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        var result: [String?] = []
        for index in 0..<match.numberOfRanges {
            let matchRange = match.range(at: index)
            if matchRange.location == NSNotFound {
                result.append(nil)
            } else if let swiftRange = Range(matchRange, in: text) {
                result.append(String(text[swiftRange]))
            } else {
                result.append(nil)
            }
        }
        return result
    }

    /// 返回第 1 个捕获组（没有分组时返回整体匹配）。
    static func firstMatch(pattern: String, in text: String) -> String? {
        guard let all = captures(pattern: pattern, in: text) else { return nil }
        if all.count > 1 {
            return all[1]
        }
        return all.first ?? nil
    }

    static func matches(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
