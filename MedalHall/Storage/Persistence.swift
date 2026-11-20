import Foundation

/// 原 Web 版 localStorage 的等价实现（UserDefaults + JSON）。
/// 键名与旧版保持一致，方便理解与迁移。
enum Persistence {
    static let defaultMedalURLTemplate = "https://i2.y.qq.com/n3/client/pages/medal_collection_new/index.html?_hidehd=1&_fontscale=1&_miniplayer=1&enc_uin={ENC_UIN}&entry=profile&_button=1&max_age=1782752162"

    private static let familiesKey = "families"
    private static let medalURLKey = "medal_url"
    private static let memberInfoPrefix = "member_info_"
    private static let familyMembersPrefix = "family_members_v2_"
    private static let memberFamiliesPrefix = "member_families_"
    private static let honorRecordsKey = "member_honor_records_v1"
    private static let familyArtistPrefix = "family_artist_"
    private static let globalArtistKey = "family_artist_name"

    private static var defaults: UserDefaults { .standard }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - 家族

    static var families: [Family] {
        get { load([Family].self, key: familiesKey) ?? [] }
        set { save(newValue, key: familiesKey) }
    }

    // MARK: - 当前归属成员

    static var medalURL: String? {
        get { defaults.string(forKey: medalURLKey) }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: medalURLKey)
            } else {
                defaults.removeObject(forKey: medalURLKey)
            }
        }
    }

    static var selectedItemID: String? {
        guard let url = medalURL,
              let value = RegexTool.firstMatch(pattern: #"enc_uin=([^&]+)"#, in: url),
              !value.isEmpty else {
            return nil
        }
        return value.removingPercentEncoding ?? value
    }

    // MARK: - 成员资料缓存

    static func memberInfo(_ itemID: String) -> Member? {
        load(Member.self, key: memberInfoPrefix + itemID)
    }

    static func saveMemberInfo(_ member: Member) {
        guard !member.itemId.isEmpty else { return }
        var merged = member
        if merged.familyId == nil {
            merged.familyId = memberInfo(member.itemId)?.familyId
        }
        save(merged, key: memberInfoPrefix + member.itemId)
    }

    static func familyMembers(_ familyID: String) -> [Member] {
        load([Member].self, key: familyMembersPrefix + familyID) ?? []
    }

    static func saveFamilyMembers(_ members: [Member], familyId: String) {
        save(members, key: familyMembersPrefix + familyId)
    }

    /// 按昵称查本地成员资料（HAR 预览、荣誉记录匹配用）。
    static func member(named name: String) -> Member? {
        let target = name.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return nil }
        var best: Member?
        for family in families {
            for member in familyMembers(family.id) where member.title == target {
                if best == nil { best = member } else { best = merge(best, member) }
            }
        }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(memberInfoPrefix) {
            guard let member = load(Member.self, key: key), member.title == target else { continue }
            best = best == nil ? member : merge(best, member)
        }
        return best
    }

    private static func merge(_ lhs: Member?, _ rhs: Member) -> Member {
        guard var base = lhs else { return rhs }
        if base.pic.isEmpty { base.pic = rhs.pic }
        if base.medal.isEmpty { base.medal = rhs.medal }
        if base.fanBadge.isEmpty { base.fanBadge = rhs.fanBadge }
        if base.artistName.isEmpty { base.artistName = rhs.artistName }
        if base.honor.isEmpty { base.honor = rhs.honor }
        if base.familyId == nil { base.familyId = rhs.familyId }
        return base
    }

    // MARK: - 成员所属家族（历史记录）

    static func recordMemberFamily(familyId: String, itemId: String) {
        guard !familyId.isEmpty, !itemId.isEmpty else { return }
        var ids = memberFamilyIDs(itemId)
        if !ids.contains(familyId) {
            ids.append(familyId)
            defaults.set(ids, forKey: memberFamiliesPrefix + itemId)
        }
    }

    static func memberFamilyIDs(_ itemId: String) -> [String] {
        defaults.stringArray(forKey: memberFamiliesPrefix + itemId) ?? []
    }

    // MARK: - 荣誉记录

    static var honorStore: [HonorMemberStore] {
        get { load([HonorMemberStore].self, key: honorRecordsKey) ?? [] }
        set { save(newValue, key: honorRecordsKey) }
    }

    static func honorRecords(for memberName: String) -> [HonorRecord] {
        let target = memberName.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return [] }
        return honorStore.first(where: { $0.name == target })?.records ?? []
    }

    @discardableResult
    static func addHonorRecords(_ imported: [ImportedHonorRecord]) -> (records: Int, members: Int) {
        var store = honorStore
        var touched = Set<String>()
        for record in imported where !record.memberName.isEmpty {
            let index = store.firstIndex(where: { $0.name == record.memberName })
            let newRecord = HonorRecord(
                taskName: record.taskName,
                date: record.date,
                value: record.value
            )
            if let index {
                store[index].records.append(newRecord)
            } else {
                store.append(HonorMemberStore(name: record.memberName, records: [newRecord]))
            }
            touched.insert(record.memberName)
        }
        if !touched.isEmpty {
            honorStore = store
        }
        return (imported.count, touched.count)
    }

    @discardableResult
    static func deleteHonorRecord(_ recordID: String) -> Bool {
        var store = honorStore
        var removed = false
        for index in store.indices {
            let before = store[index].records.count
            store[index].records.removeAll { $0.id == recordID }
            if store[index].records.count != before { removed = true }
        }
        if removed {
            honorStore = store
        }
        return removed
    }

    // MARK: - 艺人名（乐迷勋章回退匹配）

    static func familyArtistName(_ familyID: String) -> String? {
        let value = defaults.string(forKey: familyArtistPrefix + familyID) ?? ""
        return value.isEmpty ? nil : value
    }

    static func saveFamilyArtistName(_ name: String, familyId: String) {
        guard !familyId.isEmpty, !name.isEmpty else { return }
        defaults.set(name, forKey: familyArtistPrefix + familyId)
    }

    static var globalArtistName: String? {
        get {
            let value = defaults.string(forKey: globalArtistKey) ?? ""
            return value.isEmpty ? nil : value
        }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: globalArtistKey)
            } else {
                defaults.removeObject(forKey: globalArtistKey)
            }
        }
    }

    // MARK: - 测试清理

    static func reset() {
        let keys = Array(defaults.dictionaryRepresentation().keys)
        for key in keys {
            if key == familiesKey
                || key == medalURLKey
                || key == honorRecordsKey
                || key == globalArtistKey
                || key.hasPrefix(memberInfoPrefix)
                || key.hasPrefix(familyMembersPrefix)
                || key.hasPrefix(memberFamiliesPrefix)
                || key.hasPrefix(familyArtistPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
