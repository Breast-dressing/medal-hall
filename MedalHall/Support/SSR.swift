import Foundation

/// 解析 QQ 音乐页面里的 `window.__ssrFirstPageData__`（原 Web 版的 `parseSSRData`）。
enum SSR {
    static let pattern = #"window\.__ssrFirstPageData__\s*=\s*"((?:[^"\\]|\\.)*)""#

    /// 从 HTML 里抓取 SSR JSON 并解析成对象。
    static func firstPageData(from html: String) -> Any? {
        guard let raw = capture(from: html) else { return nil }
        let text = unescape(raw)
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// 抓取 SSR 赋值的原始转义字符串。
    static func capture(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let capturedRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[capturedRange])
    }

    /// 还原 JS 字符串转义（与原实现的 replace 顺序一致）。
    static func unescape(_ raw: String) -> String {
        var text = raw
        text = text.replacingOccurrences(of: "\\\"", with: "\"")
        text = text.replacingOccurrences(of: "\\\\", with: "\\")
        text = text.replacingOccurrences(of: "\\u002F", with: "/")
        text = text.replacingOccurrences(of: "\\u0026", with: "&")
        return text
    }

    /// 抓取页面后解析为字典；失败时抛错。
    static func root(fromHTML html: String) throws -> [String: Any] {
        guard let root = firstPageData(from: html) as? [String: Any] else {
            throw QQMusicError.decoding("页面数据解析失败")
        }
        return root
    }

    /// 皮肤详情页的 SSR 是「JSON 字符串里再套 JSON」，需要解析两次。
    static func doubleEncoded(from html: String) -> [String: Any]? {
        guard let raw = capture(from: html) else { return nil }
        let unescaped = unescape(raw)
        guard let outerData = unescaped.data(using: .utf8),
              let outer = try? JSONSerialization.jsonObject(with: outerData),
              let innerString = outer as? String,
              let innerData = innerString.data(using: .utf8),
              let inner = try? JSONSerialization.jsonObject(with: innerData),
              let dictionary = inner as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}
