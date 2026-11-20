import Foundation

/// HAR 解析：从浏览器导出的 HAR 里抽出 GetFamilyHonorRecord 的响应（移植自原 Web 版）。
enum HonorImporter {
    static let honorURLFragment = "https://u6.y.qq.com/cgi-bin/musics.fcg?_webcgikey=GetFamilyHonorRecord&_="

    static func parse(
        data: Data,
        fileName: String,
        memberLookup: (String) -> Member? = { _ in nil }
    ) throws -> HARImportResult {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw QQMusicError.decoding("HAR 文件不是有效的 JSON")
        }
        guard let har = root as? [String: Any] else {
            throw QQMusicError.decoding("HAR 文件不是有效的 JSON")
        }

        let entries = har.dict("log").dictArray("entries")
        let responses = entries.filter { $0.dict("request").string("url").contains(honorURLFragment) }
        let extracted = responses.compactMap { entry -> String? in
            let content = entry.dict("response").dict("content")
            let text = decodeContent(content)
            return extractHonorArray(text)
        }.filter { !$0.isEmpty }

        guard !extracted.isEmpty else {
            throw QQMusicError.empty("没有找到 GetFamilyHonorRecord 记录")
        }

        var kept: [String] = []
        for (index, content) in extracted.enumerated() {
            let start = max(0, index - 4)
            let previous = extracted[start..<index]
            if !previous.contains(content) {
                kept.append(content)
            }
        }

        var records: [ImportedHonorRecord] = []
        for content in kept {
            for block in blocks(in: content) {
                guard let raw = block.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: raw),
                      let item = object as? [String: Any] else {
                    continue
                }
                let title = item.string("Title").trimmingCharacters(in: .whitespaces)
                guard let at = title.firstIndex(of: "@") else { continue }
                let taskName = String(title[title.startIndex..<at]).trimmingCharacters(in: .whitespaces)
                var memberName = String(title[title.index(after: at)...]).trimmingCharacters(in: .whitespaces)
                memberName = memberName.replacingOccurrences(
                    of: #"[\s。，、；：！？.!?,;:…·]+$"#,
                    with: "",
                    options: .regularExpression
                )
                guard !memberName.isEmpty else { continue }
                records.append(ImportedHonorRecord(
                    taskName: taskName,
                    memberName: memberName,
                    date: item.string("Date").trimmingCharacters(in: .whitespaces),
                    value: item.string("Value").trimmingCharacters(in: .whitespaces)
                ))
            }
        }

        let grouped = Dictionary(grouping: records) { $0.memberName }
        let groups = grouped.keys.sorted().map { name -> HARMemberGroup in
            let items = grouped[name] ?? []
            let local = memberLookup(name)
            return HARMemberGroup(
                name: name,
                avatar: local?.pic ?? "",
                medalText: local?.medalText ?? "",
                fanBadge: local?.fanBadge ?? "",
                records: items
            )
        }

        return HARImportResult(
            fileName: fileName,
            responseCount: responses.count,
            extractedCount: extracted.count,
            keptCount: kept.count,
            records: records,
            groups: groups
        )
    }

    static func decodeContent(_ content: [String: Any]) -> String {
        let text = content.string("text")
        guard !text.isEmpty else { return "" }
        guard content.string("encoding") == "base64" else { return text }
        guard let data = Data(base64Encoded: text) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// 取文本里第一个 `[` 到最后一个 `]` 之间的内容。
    static func extractHonorArray(_ text: String) -> String {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"),
              start < end else {
            return ""
        }
        return String(text[start...end])
    }

    /// 用 `\{[^{}]*\}` 切出扁平的 JSON 对象（与原版正则一致）。
    static func blocks(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\{[^{}]*\}"#) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}
