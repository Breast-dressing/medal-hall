import Foundation
import Observation
import SwiftUI

/// 全局应用状态：家族列表、当前归属成员、成员缓存（对应原 Web 版 localStorage 的那部分状态）。
@MainActor
@Observable
final class AppModel {
    private(set) var families: [Family]
    private(set) var medalURL: String?
    private(set) var selectedMember: Member?
    private(set) var isImportingFamily = false
    /// 有任何会影响首页的数据变化时递增，首页据此重新加载。
    var reloadToken = UUID()

    private let client: QQMusicClient
    private var membersByFamily: [String: [Member]] = [:]
    private var loadingFamilies: Set<String> = []

    init(client: QQMusicClient = .shared) {
        self.client = client

        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            Persistence.reset()
        }

        let storedFamilies = Persistence.families
        families = storedFamilies
        medalURL = Persistence.medalURL

        var cache: [String: [Member]] = [:]
        for family in storedFamilies {
            let members = Persistence.familyMembers(family.id)
            if !members.isEmpty {
                cache[family.id] = members
            }
        }
        membersByFamily = cache
        selectedMember = Self.resolveSelectedMember(families: storedFamilies, cache: cache)
    }

    private static func resolveSelectedMember(families: [Family], cache: [String: [Member]]) -> Member? {
        guard let itemID = Persistence.selectedItemID else { return nil }
        if let info = Persistence.memberInfo(itemID) {
            return info
        }
        for family in families {
            if let found = cache[family.id]?.first(where: { $0.itemId == itemID }) {
                return found
            }
        }
        return Member(itemId: itemID, title: "未知成员")
    }

    // MARK: - 家族

    func addFamily(urlText: String) async throws -> Family {
        guard !isImportingFamily else {
            throw QQMusicError.empty("正在添加家族，请稍候")
        }
        isImportingFamily = true
        defer { isImportingFamily = false }

        let family = try await client.fetchFamily(rawURL: urlText)
        guard !families.contains(where: { $0.id == family.id }) else {
            throw QQMusicError.empty("这个家族已经添加过了")
        }
        families.append(family)
        Persistence.families = families
        reloadToken = UUID()
        return family
    }

    func removeFamilies(at offsets: IndexSet) {
        let removedIDs = offsets.compactMap { families.indices.contains($0) ? families[$0].id : nil }
        families.remove(atOffsets: offsets)
        for identifier in removedIDs {
            membersByFamily[identifier] = nil
        }
        Persistence.families = families
        reloadToken = UUID()
    }

    func moveFamilies(from source: IndexSet, to destination: Int) {
        families.move(fromOffsets: source, toOffset: destination)
        Persistence.families = families
        reloadToken = UUID()
    }

    // MARK: - 成员

    func members(for familyID: String, force: Bool = false) async throws -> [Member] {
        if !force, let cached = membersByFamily[familyID], !cached.isEmpty {
            return cached
        }
        if loadingFamilies.contains(familyID) {
            return membersByFamily[familyID] ?? []
        }
        loadingFamilies.insert(familyID)
        defer { loadingFamilies.remove(familyID) }

        let fetched = try await client.fetchMembers(familyId: familyID)
        var updated: [Member] = []
        for var member in fetched {
            member.familyId = familyID
            Persistence.saveMemberInfo(member)
            Persistence.recordMemberFamily(familyId: familyID, itemId: member.itemId)
            updated.append(member)
        }
        membersByFamily[familyID] = updated
        Persistence.saveFamilyMembers(updated, familyId: familyID)

        if let artist = updated.first(where: { !$0.artistName.isEmpty })?.artistName {
            Persistence.saveFamilyArtistName(artist, familyId: familyID)
            Persistence.globalArtistName = artist
        }
        return updated
    }

    func cachedMembers(for familyID: String) -> [Member] {
        membersByFamily[familyID] ?? Persistence.familyMembers(familyID)
    }

    /// 设置页「当前归属成员」下拉：汇总所有家族成员。
    func allMembers(force: Bool = false) async -> [Member] {
        var result: [Member] = []
        var seen = Set<String>()
        for family in families {
            let list = (try? await members(for: family.id, force: force)) ?? cachedMembers(for: family.id)
            for member in list where !seen.contains(member.itemId) {
                seen.insert(member.itemId)
                result.append(member)
            }
        }
        if let selected = selectedMember, !seen.contains(selected.itemId) {
            result.append(selected)
        }
        return result.sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    func member(itemID: String) -> Member? {
        if let selected = selectedMember, selected.itemId == itemID {
            return selected
        }
        for (_, list) in membersByFamily {
            if let found = list.first(where: { $0.itemId == itemID }) {
                return found
            }
        }
        return Persistence.memberInfo(itemID)
    }

    /// 保存当前归属成员，并生成对应的勋章馆链接（原版 btn-submit-medal 的逻辑）。
    func select(itemID: String) {
        guard let member = member(itemID: itemID) else { return }
        selectedMember = member
        let url = QQMusicClient.medalURL(forItemID: itemID)
        medalURL = url
        Persistence.medalURL = url
        reloadToken = UUID()
    }

    /// 成员详情页回退匹配艺人名的顺序：成员自己的艺人名 → 所属家族的艺人名 → 全局最后的艺人名。
    func artistName(for member: Member) -> String {
        let direct = member.artistName.trimmingCharacters(in: .whitespaces)
        if !direct.isEmpty { return direct }
        if let familyID = member.familyId,
           let scoped = Persistence.familyArtistName(familyID),
           !scoped.isEmpty {
            return scoped
        }
        return Persistence.globalArtistName ?? ""
    }

    // MARK: - 荣誉记录

    func honorRecords(for memberName: String) -> [HonorRecord] {
        Persistence.honorRecords(for: memberName)
    }

    /// 家族「近 7 天总荣誉」：把家族成员的荣誉记录按天累加。
    func weeklyHonorValues(for members: [Member], now: Date = Date()) -> [Double] {
        let names = Set(members.map { $0.title })
        let records = Persistence.honorStore
            .filter { names.contains($0.name) }
            .flatMap { $0.records }
        return HonorAggregator.weeklyValues(records, now: now)
    }
}
