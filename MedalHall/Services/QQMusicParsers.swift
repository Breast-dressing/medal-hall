import Foundation

/// 把 QQ 音乐接口返回的 JSON 映射成 App 模型。
/// 全部是纯函数，便于单元测试（原 Web 版的 parseMemberItem / parseSSRData 等逻辑在这里）。
enum QQMusicParsers {
    // MARK: - 通用

    static func firstNonEmpty(_ values: [String]) -> String {
        for value in values where !value.isEmpty {
            return value
        }
        return ""
    }

    static func normalizeImageURL(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") {
            return "https://" + String(trimmed.dropFirst("http://".count))
        }
        return trimmed
    }

    static func formatDate(timestamp: Double) -> String {
        guard timestamp > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    // MARK: - 家族

    static func familyID(fromHTML html: String) -> String? {
        if let value = RegexTool.firstMatch(pattern: #"family_id=([^&"'<\s]+)"#, in: html), !value.isEmpty {
            return value
        }
        if let value = RegexTool.firstMatch(pattern: #""family_id"\s*:\s*"([^"]+)""#, in: html), !value.isEmpty {
            return value
        }
        return nil
    }

    static func familyID(fromURL url: String) -> String? {
        guard let value = RegexTool.firstMatch(pattern: #"family_id=([^&#]+)"#, in: url), !value.isEmpty else {
            return nil
        }
        return value.removingPercentEncoding ?? value
    }

    static func family(from data: [String: Any], id: String, rawURL: String) -> Family {
        var honor = "0"
        var rank = "--"
        var pkWins = "--"
        var members = "0"
        for item in data.dictArray("DetailItemList") {
            let desc = item.string("Desc")
            let title = item.string("Title")
            guard !title.isEmpty else { continue }
            if desc.contains("总荣誉") { honor = title }
            if desc.contains("周排名") { rank = title }
            if desc.contains("PK胜场") { pkWins = title }
            if desc.contains("成员") { members = title }
        }
        return Family(
            id: id,
            name: data.nonEmpty("Name", fallback: id),
            avatar: normalizeImageURL(data.string("Avatar")),
            sign: data.nonEmpty("Announcement", fallback: "暂无"),
            honor: honor,
            rank: rank,
            pkWins: pkWins,
            members: members.isEmpty ? "0" : members,
            rawURL: rawURL
        )
    }

    // MARK: - 成员

    static func member(from item: [String: Any], familyID: String?) -> Member {
        let itemID = item.string("ItemID")
        let title = item.nonEmpty("Title", fallback: "未知")
        let pic = normalizeImageURL(item.string("Pic"))

        var medal = ""
        var fanBadge = ""
        var artistName = ""

        for wear in item.dictArray("WearList") {
            let wearTitle = wear.string("Title")
            if wearTitle.contains("V"),
               let level = RegexTool.firstMatch(pattern: #"V\d+"#, in: wearTitle) {
                medal = level
                if let range = wearTitle.range(of: level) {
                    let prefix = String(wearTitle[wearTitle.startIndex..<range.lowerBound])
                        .trimmingCharacters(in: .whitespaces)
                    if !prefix.isEmpty && artistName.isEmpty {
                        artistName = prefix
                    }
                }
            }
            for content in wear.dict("Segment").dictArray("Contents") {
                let text = content.string("Content")
                if text.hasPrefix("NO.") {
                    fanBadge = text
                }
            }
        }

        var honor = ""
        for descItem in item.dictArray("DescList") {
            let desc = descItem.string("Desc")
            if desc.contains("荣誉值"),
               let number = RegexTool.firstMatch(pattern: #"\d+"#, in: desc) {
                honor = number
            }
        }

        return Member(
            itemId: itemID,
            title: title,
            pic: pic,
            medal: medal,
            fanBadge: fanBadge,
            honor: honor,
            artistName: artistName,
            familyId: familyID
        )
    }

    // MARK: - 勋章馆

    static func medalPageBasics(from root: [String: Any]) -> (
        encUin: String,
        desc: String,
        currentTabID: Int,
        tabs: [MedalTab],
        modules: [MedalModule]
    ) {
        let page = root.dict("data")
        let query = root.dict("query")
        var encUin = page.string("EncUin")
        if encUin.isEmpty { encUin = query.string("enc_uin") }
        let tabs = page.dictArray("TabList").map {
            MedalTab(id: $0.int("ID"), name: $0.string("Name"), firstShow: $0.bool("FirstShow"))
        }
        let modules = parseModules(page.dict("TabInfo").dictArray("ModuleList"))
        return (encUin, page.nonEmpty("Desc", fallback: "--"), page.int("CurrTabID"), tabs, modules)
    }

    static func parseModules(_ raw: [[String: Any]]) -> [MedalModule] {
        raw.enumerated().map { index, module in
            let moduleId = module.int("ModuleID")
            var rawItems = module.dictArray("CardList")
            if rawItems.isEmpty {
                rawItems = module.dictArray("MedalList")
            }
            let items = rawItems.enumerated().map { itemIndex, item in
                medalItem(from: item, index: itemIndex)
            }
            return MedalModule(
                moduleId: moduleId,
                moduleName: module.nonEmpty("ModuleName", fallback: "模块 \(moduleId)"),
                items: items,
                index: index
            )
        }
    }

    static func medalItem(from item: [String: Any], index: Int) -> MedalItem {
        let medalId = item.string("MedalID")
        let name = item.nonEmpty("Name", fallback: "未命名")

        var subText = item.dict("NumberInfo").string("Content")
        if subText == "NO.----" {
            subText = ""
        }
        if subText.isEmpty {
            let createTime = item.string("CreateTime")
            if !createTime.isEmpty {
                subText = createTime.split(separator: " ").first.map(String.init) ?? ""
            }
        }
        if subText.isEmpty {
            let cornerTitle = item.dict("Corner").string("Title")
            if RegexTool.matches(pattern: #"^\d{4}-\d{2}-\d{2}"#, in: cornerTitle) {
                subText = cornerTitle.split(separator: " ").first.map(String.init) ?? ""
            }
        }

        return MedalItem(
            uid: "\(medalId)-\(index)-\(name)",
            medalId: medalId,
            name: name,
            picURL: normalizeImageURL(item.string("PicURL")),
            scheme: item.string("Scheme"),
            level: item.int("Level"),
            state: item.int("State"),
            subText: subText
        )
    }

    static func moduleItems(from data: [String: Any]) -> (items: [MedalItem], lastPos: String, hasNext: Bool) {
        var rawItems = data.dictArray("CardList")
        if rawItems.isEmpty {
            rawItems = data.dictArray("MedalList")
        }
        let items = rawItems.enumerated().map { index, item in
            medalItem(from: item, index: index)
        }
        return (items, data.string("LastPos"), data.bool("HasNext"))
    }

    static func medalLevels(from data: [String: Any]) -> [MedalLevel] {
        let candidates: [[String: Any]] = [
            data.dict("OldMedalDetail"),
            data.dict("FanMedalDetail"),
            data
        ]
        for candidate in candidates {
            let list = candidate.dictArray("MedalList")
            if !list.isEmpty {
                return list.enumerated().map { index, item in
                    let level = item.int("Level")
                    return MedalLevel(
                        uid: "\(item.string("MedalID"))-\(index)",
                        level: level,
                        state: item.int("State"),
                        name: item.nonEmpty("Name", fallback: "未命名"),
                        picURL: normalizeImageURL(item.string("PicURL")),
                        medalId: item.string("MedalID"),
                        createTime: item.string("CreateTime"),
                        badgeText: "Lv.\(level)",
                        isCenter: false
                    )
                }
            }
        }

        let centerItems = data.dict("FanMedalDetail").dict("Center").dictArray("ItemList")
        return centerItems.enumerated().map { index, item in
            let section = item.dict("Section")
            let corner = item.dict("Corner")
            let sectionText = section.string("Section")
            let level = Int(sectionText.replacingOccurrences(of: "V", with: "")) ?? 0
            let obtained = corner.string("Desc") == "获得"
            return MedalLevel(
                uid: "center-\(sectionText)-\(index)",
                level: level,
                state: obtained ? 2 : 1,
                name: section.string("Alias"),
                picURL: normalizeImageURL(section.string("PicURL")),
                medalId: "center_\(sectionText)",
                createTime: obtained ? corner.string("Title") : "",
                badgeText: sectionText.isEmpty ? "Lv.\(level)" : sectionText,
                isCenter: true
            )
        }
    }

    static func fanOverview(from data: [String: Any]) -> FanOverview? {
        let fan = data.dict("FanMedalDetail")
        guard !fan.isEmpty else { return nil }
        let section = fan.dict("Section")
        let corner = fan.dict("Corner")
        let proportion = fan.dict("Proportion")
        let current = proportion.int("Current")
        let upper = proportion.int("UpperLimit")
        let name = fan.string("Name")
        if name.isEmpty && current == 0 && upper == 0 {
            return nil
        }
        return FanOverview(
            name: name,
            picURL: normalizeImageURL(fan.string("PicURL")),
            section: section.string("Section"),
            alias: section.string("Alias"),
            rankTitle: corner.string("Title"),
            rankDesc: corner.string("Desc"),
            current: current,
            upperLimit: upper
        )
    }

    // MARK: - 排行榜

    static func isStarDetailURL(_ url: String) -> Bool {
        url.contains("medal_collection_v3/star_detail.html")
    }

    static func starDetailParams(from url: String) -> (medalId: String, encUin: String) {
        guard let components = URLComponents(string: url) else { return ("", "") }
        let items = components.queryItems ?? []
        let medalId = items.first(where: { $0.name == "medal_id" })?.value ?? ""
        let encUin = items.first(where: { $0.name == "enc_uin" })?.value ?? ""
        return (medalId, encUin)
    }

    static func starDetailModule(from response: [String: Any]) -> (
        tabs: [RankTab],
        firstTabID: Int,
        firstTabDetail: [String: Any]
    ) {
        let data = response.dict("data")
        let firstTabDetail = data.dict("FirstTabDetail")
        var tabs: [RankTab] = []
        for group in data.dictArray("GroupList") {
            for tab in group.dictArray("Tabs") {
                tabs.append(RankTab(
                    name: tab.string("Name"),
                    type: tab.int("Type"),
                    firstShow: tab.bool("FirstShow")
                ))
            }
        }
        return (tabs, firstTabDetail.int("TabID"), firstTabDetail)
    }

    static func rankTabDetail(
        tab: RankTab,
        detail: [String: Any],
        success: Bool = true,
        errorMessage: String? = nil
    ) -> RankTabDetail {
        let fixed = detail.dict("FixedInfo")
        let empty = detail.dict("EmptyInfo")
        let banner = detail.dict("Banner")

        var rawItems = detail.dictArray("FirstPageInfo")
        if rawItems.isEmpty {
            rawItems = detail.dictArray("ItemList")
        }

        let entries = rawItems.enumerated().map { index, item -> RankEntry in
            let parsedPosition = item.int("Position")
            let position = parsedPosition > 0 ? parsedPosition : index + 1
            let title = firstNonEmpty([item.string("Title"), item.string("Nick"), item.string("Name")])
            let pic = normalizeImageURL(firstNonEmpty([
                item.string("Pic"), item.string("PicURL"), item.string("Avatar"), item.string("HeadPic")
            ]))

            var wearTexts: [String] = []
            for wear in item.dictArray("WearList") {
                let text = wear.dict("Segment").dictArray("Contents")
                    .map { $0.string("Content") }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if !text.isEmpty { wearTexts.append(text) }
            }
            let descTexts = item.dictArray("DescList").map { $0.string("Desc") }.filter { !$0.isEmpty }

            return RankEntry(
                uid: "\(item.string("ItemID"))-\(index)",
                position: position,
                title: title,
                pic: pic,
                itemId: item.string("ItemID"),
                wear: wearTexts,
                desc: descTexts,
                praiseNum: item.int("PraiseNum"),
                isPraised: item.bool("IsPraised")
            )
        }

        let bannerText = firstNonEmpty([banner.string("Title"), banner.string("Text")])
        let bannerLink = firstNonEmpty([banner.string("Url"), banner.string("Scheme")])
        let fixedTitle = fixed.string("Title")
        let emptyText = empty.string("Text")

        return RankTabDetail(
            tab: tab,
            success: success,
            errorMessage: errorMessage,
            entries: entries,
            bannerText: bannerText.isEmpty ? nil : bannerText,
            bannerLink: bannerLink.isEmpty ? nil : bannerLink,
            fixedTitle: fixedTitle.isEmpty ? nil : fixedTitle,
            emptyText: emptyText.isEmpty ? nil : emptyText
        )
    }

    // MARK: - 皮肤

    static func skinPage(from response: [String: Any], medalId: String) -> SkinPage {
        let data = response.dict("data")
        let list = data.dictArray("SkinList").enumerated().map { index, item in
            skin(from: item, medalId: medalId, index: index)
        }
        return SkinPage(
            total: data.int("SkinTotal"),
            list: list,
            medalName: data.string("MedalName"),
            hasMore: data.bool("HasMore"),
            nextCursor: data.string("NextCursor")
        )
    }

    static func skin(from item: [String: Any], medalId: String, index: Int) -> Skin {
        let seq = item.int("Seq")
        var identifier = item.string("ID")
        if identifier.isEmpty {
            identifier = "\(medalId)-\(seq > 0 ? seq : index + 1)"
        }

        let levels = item.dictArray("LevelList")
        let level = levels.first.map { JSONValue.dict($0) } ?? [:]
        var pic = item.string("Pic")
        if pic.isEmpty { pic = level.string("Pic") }

        let unlockedTimestamp = item.double("UnlockedTs")
        let isUnlocked = level.int("State") == 2 || unlockedTimestamp > 0
        var unlockTask = ""
        if let task = level.dict("LevelUnlockGuide").dictArray("TaskList").first {
            unlockTask = task.string("Title")
        }
        var date = item.string("UnlockedDate")
        if date.isEmpty && unlockedTimestamp > 0 {
            date = formatDate(timestamp: unlockedTimestamp)
        }
        let seqNo = firstNonEmpty([item.string("SeqNo"), level.string("SeqNo")])
        let unlockedUserCount = item.int("UnlockedUserCnt")
        let fallbackUserCount = item.int("UserCnt")

        return Skin(
            id: identifier,
            seq: seq,
            seqNo: seqNo,
            name: item.nonEmpty("Name", fallback: "(未命名)"),
            pic: normalizeImageURL(pic),
            categId: item.string("CategID"),
            unlockedDate: date,
            userCount: unlockedUserCount > 0 ? unlockedUserCount : fallbackUserCount,
            isUnlocked: isUnlocked,
            stateText: isUnlocked ? "已解锁" : "未解锁",
            unlockTask: unlockTask,
            bgColor: level.nonEmpty("BGColor", fallback: "#fafafa")
        )
    }

    /// 原版：SKIN_CATEGORY_MAP 为空表，因此退回「其他系列 / 系列 N」。
    static func skinCategoryName(_ identifier: String) -> String {
        if identifier.isEmpty || identifier == "other" {
            return "其他系列"
        }
        return "系列 \(identifier)"
    }
}
