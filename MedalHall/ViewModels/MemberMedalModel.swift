import Foundation
import Observation

/// 成员勋章馆的数据模型：勋章 Tab、周/月榜排名、勋章皮肤数、乐迷值、荣誉记录。
@MainActor
@Observable
final class MemberMedalModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let member: Member

    private(set) var phase: Phase = .idle
    private(set) var page: MedalPageData?
    private(set) var desc: String = "--"
    private(set) var weekRank: Int?
    private(set) var monthRank: Int?
    private(set) var weekTabName = "周榜"
    private(set) var monthTabName = "月榜"
    private(set) var skinCount: Int?
    private(set) var skinMedal: MedalTarget?
    private(set) var fan: FanOverview?
    private(set) var rankScheme: String?
    private(set) var isRefreshingDetails = false
    private(set) var honorRecords: [HonorRecord] = []

    private let client: QQMusicClient

    init(member: Member, client: QQMusicClient = .shared) {
        self.member = member
        self.client = client
        self.honorRecords = Persistence.honorRecords(for: member.title)
    }

    // MARK: - 派生状态

    var encUin: String { page?.encUin ?? "" }
    var weekRankText: String { weekRank.map { String($0) } ?? "--" }
    var monthRankText: String { monthRank.map { String($0) } ?? "--" }
    var skinCountText: String { skinCount.map { String($0) } ?? "--" }

    var weeklyValues: [Double] {
        HonorAggregator.weeklyValues(honorRecords)
    }

    var artistDisplayName: String {
        let artist = artistName
        return artist.isEmpty ? member.displayName : artist
    }

    var familyName: String {
        guard let familyID = member.familyId else { return "" }
        return Persistence.families.first(where: { $0.id == familyID })?.displayName ?? ""
    }

    var fanText: String {
        guard let fan else { return "--" }
        return "\(Fmt.groupedInt(fan.current)) / \(Fmt.groupedInt(fan.upperLimit))"
    }

    var isInitialLoading: Bool {
        page == nil && (phase == .idle || phase == .loading)
    }

    var failureMessage: String? {
        if case let .failed(message) = phase { return message }
        return nil
    }

    var needsLoad: Bool {
        switch phase {
        case .idle, .failed:
            return true
        case .loading, .loaded:
            return false
        }
    }

    private var artistName: String {
        let direct = member.artistName.trimmingCharacters(in: .whitespaces)
        if !direct.isEmpty { return direct }
        if let familyID = member.familyId,
           let scoped = Persistence.familyArtistName(familyID),
           !scoped.isEmpty {
            return scoped
        }
        return Persistence.globalArtistName ?? ""
    }

    // MARK: - 加载

    func reset() {
        phase = .idle
    }

    func reloadHonorRecords() {
        honorRecords = Persistence.honorRecords(for: member.title)
    }

    func load(url: String) async {
        if DemoSupport.isEnabled {
            applyDemoData()
            return
        }
        if case .loading = phase { return }
        phase = .loading
        do {
            let page = try await client.fetchMedalPage(url: url)
            self.page = page
            self.desc = page.desc
            self.honorRecords = Persistence.honorRecords(for: member.title)
            phase = .loaded
            await loadArtistDetails(page: page)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// 截图/UI 测试用的示例数据（`-demo-data` 启动时生效）。
    private func applyDemoData() {
        let page = DemoSupport.medalPage
        self.page = page
        desc = page.desc
        weekRank = 1
        monthRank = 2
        weekTabName = "周榜"
        monthTabName = "月榜"
        skinCount = 272
        skinMedal = DemoSupport.skinMedal
        fan = DemoSupport.fan
        rankScheme = DemoSupport.medalScheme
        honorRecords = Persistence.honorRecords(for: member.title)
        phase = .loaded
    }

    /// 对应原版 fetchArtistRankInfo：在「乐迷」Tab 里按艺人名找勋章，
    /// 再查排行榜周/月名次、皮肤总数、乐迷值。
    private func loadArtistDetails(page: MedalPageData) async {
        let artist = artistName.trimmingCharacters(in: .whitespaces)
        guard !artist.isEmpty else { return }
        guard let fanTab = page.tabs.first(where: { $0.tab.name.contains("乐迷") && $0.success }) else { return }

        var target: MedalItem?
        var loose: MedalItem?
        for module in fanTab.modules {
            for item in module.items {
                guard !item.scheme.isEmpty, !item.name.isEmpty else { continue }
                if item.name == artist {
                    target = item
                    break
                }
                if loose == nil && item.name.contains(artist) {
                    loose = item
                }
            }
            if target != nil { break }
        }
        guard let medal = target ?? loose else { return }

        let scheme = medal.scheme
        let params = QQMusicParsers.starDetailParams(from: scheme)
        let finalMedalID = medal.medalId.isEmpty ? params.medalId : medal.medalId
        let skinEncUin = params.encUin.isEmpty ? member.itemId : params.encUin

        rankScheme = scheme
        if !finalMedalID.isEmpty {
            skinMedal = MedalTarget(medalId: finalMedalID, name: medal.name, scheme: scheme)
        }

        isRefreshingDetails = true
        defer { isRefreshingDetails = false }

        if let rankData = try? await client.fetchStarDetailRanking(url: scheme) {
            applyRank(rankData)
        }
        if !finalMedalID.isEmpty {
            if let total = try? await client.fetchSkinTotal(medalId: finalMedalID, encUin: skinEncUin) {
                skinCount = total
            }
            if let medalData = try? await client.fetchMedalDetail(encUin: page.encUin, medalId: finalMedalID) {
                fan = QQMusicParsers.fanOverview(from: medalData)
            }
        }
    }

    private func applyRank(_ data: RankData) {
        var week: Int?
        var month: Int?
        var weekName = ""
        var monthName = ""

        for result in data.tabs where result.success {
            guard let matched = result.entries.first(where: { matches(member.itemId, candidate: $0.itemId) }) else {
                continue
            }
            let name = result.tab.name
            if name.contains("周"), week == nil {
                week = matched.position
                weekName = name
            } else if name.contains("月"), month == nil {
                month = matched.position
                monthName = name
            }
        }

        weekRank = week
        monthRank = month
        weekTabName = weekName.isEmpty ? "周榜" : weekName
        monthTabName = monthName.isEmpty ? "月榜" : monthName
    }

    private func matches(_ target: String, candidate: String) -> Bool {
        guard !candidate.isEmpty else { return false }
        if candidate == target { return true }
        let decoded = candidate.removingPercentEncoding ?? candidate
        return decoded == target
    }
}
