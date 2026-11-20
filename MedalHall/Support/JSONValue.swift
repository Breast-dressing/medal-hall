import Foundation

/// 安全读取 `[String: Any]` 形式的 JSON 数据。
enum JSONValue {
    static func dict(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    static func array(_ value: Any?) -> [Any] {
        value as? [Any] ?? []
    }

    static func dictArray(_ value: Any?) -> [[String: Any]] {
        array(value).compactMap { $0 as? [String: Any] }
    }

    static func string(_ value: Any?) -> String {
        switch value {
        case let text as String:
            return text
        case let number as NSNumber:
            return number.stringValue
        case let flag as Bool:
            return flag ? "true" : "false"
        default:
            return ""
        }
    }

    static func nonEmpty(_ value: Any?, fallback: String) -> String {
        let text = string(value)
        return text.isEmpty ? fallback : text
    }

    static func int(_ value: Any?) -> Int {
        switch value {
        case let number as Int:
            return number
        case let number as Double:
            return Int(number)
        case let flag as Bool:
            return flag ? 1 : 0
        case let number as NSNumber:
            return number.intValue
        case let text as String:
            if let parsed = Int(text) { return parsed }
            if let parsed = Double(text) { return Int(parsed) }
            return 0
        default:
            return 0
        }
    }

    static func double(_ value: Any?) -> Double {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let flag as Bool:
            return flag ? 1 : 0
        case let number as NSNumber:
            return number.doubleValue
        case let text as String:
            return Double(text) ?? 0
        default:
            return 0
        }
    }

    static func bool(_ value: Any?) -> Bool {
        switch value {
        case let flag as Bool:
            return flag
        case let number as NSNumber:
            return number.boolValue
        case let text as String:
            return text == "true" || text == "1"
        default:
            return false
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    func dict(_ key: String) -> [String: Any] {
        JSONValue.dict(self[key])
    }

    func dictArray(_ key: String) -> [[String: Any]] {
        JSONValue.dictArray(self[key])
    }

    func array(_ key: String) -> [Any] {
        JSONValue.array(self[key])
    }

    func string(_ key: String) -> String {
        JSONValue.string(self[key])
    }

    func nonEmpty(_ key: String, fallback: String) -> String {
        JSONValue.nonEmpty(self[key], fallback: fallback)
    }

    func int(_ key: String) -> Int {
        JSONValue.int(self[key])
    }

    func double(_ key: String) -> Double {
        JSONValue.double(self[key])
    }

    func bool(_ key: String) -> Bool {
        JSONValue.bool(self[key])
    }
}
