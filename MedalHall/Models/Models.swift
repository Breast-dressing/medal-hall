import Foundation

// MARK: - 家族

/// 家族（对应原 Web 版 localStorage 里的 family 对象）。
struct Family: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var avatar: String
    var sign: String
    var honor: String
    var rank: String
    var pkWins: String
    var members: String
    var rawURL: String
    var weekHonor: String

    init(
        id: String,
        name: String,
        avatar: String = "",
        sign: String = "暂无",
        honor: String = "0",
        rank: String = "--",
        pkWins: String = "--",
        members: String = "0",
        rawURL: String = "",
        weekHonor: String = ""
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.sign = sign
        self.honor = honor
        self.rank = rank
        self.pkWins = pkWins
        self.members = members
        self.rawURL = rawURL
        self.weekHonor = weekHonor
    }

    var displayName: String {
        name.isEmpty ? id : name
    }

    var honorText: String {
        let value = Fmt.honorNumber(honor)
        return value > 0 ? Fmt.groupedInt(Int(value)) : "--"
    }

    var weekHonorText: String {
        let value = Fmt.honorNumber(weekHonor)
        return value > 0 ? Fmt.groupedInt(Int(value)) : "--"
    }
}

// MARK: - 成员

/// 家族成员（对应原 Web 版的 member 对象）。
struct Member: Codable, Identifiable, Hashable {
    var itemId: String
    var title: String
    var pic: String
    var medal: String
    var fanBadge: String
    var honor: String
    var artistName: String
    var familyId: String?

    init(
        itemId: String,
        title: String,
        pic: String = "",
        medal: String = "",
        fanBadge: String = "",
        honor: String = "",
        artistName: String = "",
        familyId: String? = nil
    ) {
        self.itemId = itemId
        self.title = title
        self.pic = pic
        self.medal = medal
        self.fanBadge = fanBadge
        self.honor = honor
        self.artistName = artistName
        self.familyId = familyId
    }

    var id: String { itemId }

    /// 原版 memberMedalText：艺人名 + 勋章等级，已包含则不重复。
    var medalText: String {
        let level = medal.trimmingCharacters(in: .whitespaces)
        guard !level.isEmpty else { return "" }
        let artist = artistName.trimmingCharacters(in: .whitespaces)
        if artist.isEmpty || level.contains(artist) {
            return level
        }
        return artist + level
    }

    var honorValue: Double { Fmt.honorNumber(honor) }

    var displayName: String {
        title.isEmpty ? "未知成员" : title
    }
}

// MARK: - 勋章馆

struct MedalTab: Hashable {
    var id: Int
    var name: String
    var firstShow: Bool
}

struct MedalItem: Hashable, Identifiable {
    var uid: String
    var medalId: String
    var name: String
    var picURL: String
    var scheme: String
    var level: Int
    var state: Int
    var subText: String

    var id: String { uid }
    var isObtained: Bool { level >= 3 || state == 2 }
}

struct MedalModule: Hashable, Identifiable {
    var moduleId: Int
    var moduleName: String
    var items: [MedalItem]
    /// 同一页里 ModuleID 可能重复或缺失，用页内序号保证唯一。
    var index: Int

    var id: String { "\(moduleId)-\(index)" }
}

struct MedalTabResult: Hashable, Identifiable {
    var tab: MedalTab
    var success: Bool
    var errorMessage: String?
    var modules: [MedalModule]

    var id: Int { tab.id }
}

/// 成员勋章馆首页数据（/api/parse 的等价物）。
struct MedalPageData: Hashable {
    var encUin: String
    var desc: String
    var tabs: [MedalTabResult]
}

struct MedalLevel: Hashable, Identifiable {
    var uid: String
    var level: Int
    var state: Int
    var name: String
    var picURL: String
    var medalId: String
    var createTime: String
    var badgeText: String
    var isCenter: Bool

    var id: String { uid }
    var isObtained: Bool { state == 2 }
}

/// 乐迷概览（勋章详情里的 FanMedalDetail）。
struct FanOverview: Hashable {
    var name: String
    var picURL: String
    var section: String
    var alias: String
    var rankTitle: String
    var rankDesc: String
    var current: Int
    var upperLimit: Int

    var progress: Double {
        guard upperLimit > 0 else { return 0 }
        return min(1, Double(current) / Double(upperLimit))
    }
}

/// 勋章皮肤。
struct Skin: Hashable, Identifiable {
    var id: String
    var seq: Int
    var seqNo: String
    var name: String
    var pic: String
    var categId: String
    var unlockedDate: String
    var userCount: Int
    var isUnlocked: Bool
    var stateText: String
    var unlockTask: String
    var bgColor: String

    var subText: String {
        if !seqNo.isEmpty { return seqNo }
        return unlockedDate
    }
}

struct SkinPage: Hashable {
    var total: Int
    var list: [Skin]
    var medalName: String
    var hasMore: Bool
    var nextCursor: String
}

/// 成员详情页顶部四项统计里「勋章皮肤」入口需要的勋章信息。
struct MedalTarget: Hashable {
    var medalId: String
    var name: String
    var scheme: String
}

// MARK: - 排行榜

struct RankTab: Hashable, Identifiable {
    var name: String
    var type: Int
    var firstShow: Bool

    var id: Int { type }
}

struct RankEntry: Hashable, Identifiable {
    var uid: String
    var position: Int
    var title: String
    var pic: String
    var itemId: String
    var wear: [String]
    var desc: [String]
    var praiseNum: Int
    var isPraised: Bool

    var id: String { uid }
}

struct RankTabDetail: Hashable, Identifiable {
    var tab: RankTab
    var success: Bool
    var errorMessage: String?
    var entries: [RankEntry]
    var bannerText: String?
    var bannerLink: String?
    var fixedTitle: String?
    var emptyText: String?

    var id: Int { tab.type }
}

/// 排行榜页面数据（/api/parse 对 star_detail 页的等价物）。
struct RankData: Hashable {
    var title: String
    var tabs: [RankTabDetail]
}

// MARK: - 轻量错误

enum QQMusicError: LocalizedError, Equatable {
    case invalidURL(String)
    case network(String)
    case decoding(String)
    case server(String)
    case empty(String)

    var errorDescription: String? {
        switch self {
        case let .invalidURL(value): return "链接无效：\(value)"
        case let .network(message): return "网络请求失败：\(message)"
        case let .decoding(message): return "数据解析失败：\(message)"
        case let .server(message): return message.isEmpty ? "接口返回异常" : message
        case let .empty(message): return message
        }
    }
}
