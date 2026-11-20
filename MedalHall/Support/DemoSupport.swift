import Foundation

/// 只在通过 `-demo-data` 启动时生效的示例数据。
/// 用途：UI 测试与 CI 截图（模拟器里没有真实家族链接时的可视化验证），不影响正常使用。
enum DemoSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-data")
    }

    static let familyID = "3069960_1"
    static let memberItemID = "oDemoUin0001"
    static let artistName = "虞书欣"

    static var medalScheme: String {
        "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3/star_detail.html?medal_id=3069960&enc_uin=\(memberItemID)&level=3"
    }

    static var medalURL: String {
        "https://i2.y.qq.com/n3/client/pages/medal_collection_new/index.html?_hidehd=1&_fontscale=1&_miniplayer=1&enc_uin=\(memberItemID)&entry=profile&_button=1&max_age=1782752162"
    }

    static let families: [Family] = [
        Family(
            id: familyID,
            name: "石榴花",
            avatar: "",
            sign: "如繁花涌向天边 如彩霞铺成诗篇 | 加入私信：空白",
            honor: "944.3万+",
            rank: "1",
            pkWins: "46",
            members: "30",
            rawURL: "https://i2.y.qq.com/?family_id=3069960_1",
            weekHonor: "12800"
        ),
        Family(
            id: "3069960_2",
            name: "石榴枝",
            avatar: "",
            sign: "石榴枝 · 每周一起涨荣誉",
            honor: "725.9",
            rank: "3",
            pkWins: "21",
            members: "26",
            rawURL: "https://i2.y.qq.com/?family_id=3069960_2",
            weekHonor: "9600"
        ),
        Family(
            id: "3069960_3",
            name: "石榴盼",
            avatar: "",
            sign: "石榴盼 · 新人友好",
            honor: "286.5",
            rank: "8",
            pkWins: "12",
            members: "18",
            rawURL: "https://i2.y.qq.com/?family_id=3069960_3",
            weekHonor: "4200"
        )
    ]

    static let member = Member(
        itemId: memberItemID,
        title: "红颜虞",
        pic: "",
        medal: "V91",
        fanBadge: "NO.2026",
        honor: "196",
        artistName: artistName,
        familyId: familyID
    )

    static let members: [Member] = [
        member,
        Member(
            itemId: "oDemoUin0002",
            title: "星野",
            pic: "",
            medal: "V80",
            fanBadge: "NO.0312",
            honor: "320",
            artistName: artistName,
            familyId: familyID
        ),
        Member(
            itemId: "oDemoUin0003",
            title: "小满",
            medal: "V42",
            honor: "80",
            artistName: artistName,
            familyId: familyID
        ),
        Member(
            itemId: "oDemoUin0004",
            title: "阿絮",
            medal: "V33",
            honor: "60",
            artistName: artistName,
            familyId: familyID
        ),
        Member(
            itemId: "oDemoUin0005",
            title: "花见",
            medal: "V27",
            honor: "55",
            artistName: artistName,
            familyId: familyID
        )
    ]

    static var medalPage: MedalPageData {
        let medal = MedalItem(
            uid: "demo-medal",
            medalId: "3069960",
            name: artistName,
            picURL: "",
            scheme: medalScheme,
            level: 3,
            state: 2,
            subText: "NO.2026"
        )
        let medalModule = MedalModule(moduleId: 11, moduleName: "我的勋章", items: [medal], index: 0)
        let fanModule = MedalModule(moduleId: 21, moduleName: "乐迷灯牌", items: [medal], index: 1)
        return MedalPageData(
            encUin: memberItemID,
            desc: "196",
            tabs: [
                MedalTabResult(
                    tab: MedalTab(id: 1, name: "勋章", firstShow: true),
                    success: true,
                    errorMessage: nil,
                    modules: [medalModule]
                ),
                MedalTabResult(
                    tab: MedalTab(id: 2, name: "乐迷", firstShow: false),
                    success: true,
                    errorMessage: nil,
                    modules: [fanModule]
                )
            ]
        )
    }

    static let fan = FanOverview(
        name: artistName,
        picURL: "",
        section: "V9",
        alias: "石榴花",
        rankTitle: "乐迷榜第 1 名",
        rankDesc: "本周",
        current: 120,
        upperLimit: 400
    )

    static let skinMedal = MedalTarget(medalId: "3069960", name: artistName, scheme: medalScheme)

    /// 本周（周一到今天）的示例荣誉记录，保证「近 7 天」条形图有数据。
    static var honorStore: [HonorMemberStore] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7

        return members.enumerated().map { index, member in
            var records: [HonorRecord] = []
            for offset in 0...daysFromMonday {
                guard let day = calendar.date(byAdding: .day, value: offset - daysFromMonday, to: today) else {
                    continue
                }
                let value = 120 + offset * 65 + index * 30
                records.append(HonorRecord(
                    taskName: "超话签到",
                    date: dateText(day, hour: min(9 + offset, 22)),
                    value: "+\(value)"
                ))
            }
            return HonorMemberStore(name: member.title, records: records)
        }
    }

    static func dateText(_ date: Date, hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:00"
        return formatter.string(from: date)
    }

    static func seed() {
        Persistence.reset()
        Persistence.families = families
        Persistence.medalURL = medalURL
        Persistence.saveFamilyMembers(members, familyId: familyID)
        for member in members {
            Persistence.saveMemberInfo(member)
        }
        Persistence.honorStore = honorStore
        Persistence.saveFamilyArtistName(artistName, familyId: familyID)
        Persistence.globalArtistName = artistName
    }
}
