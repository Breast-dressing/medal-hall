import XCTest
@testable import MedalHall

/// SSR 抓取与各接口 JSON 的映射（原 Web 版 parseSSRData / parseMemberItem 等逻辑）。
final class SSRAndParserTests: XCTestCase {
    func testSSRCaptureAndUnescape() {
        let html = #"<script>window.__ssrFirstPageData__ = "{\"code\":0,\"data\":{\"Name\":\"石榴花\",\"Url\":\"https:\/\/y.qq.com\/a\"}}";</script>"#
        guard let root = SSR.firstPageData(from: html) as? [String: Any] else {
            return XCTFail("SSR 没有解析出来")
        }
        let data = JSONValue.dict(root["data"])
        XCTAssertEqual(data.string("Name"), "石榴花")
        XCTAssertEqual(data.string("Url"), "https://y.qq.com/a")
    }

    func testSSRReturnsNilWhenMissing() {
        XCTAssertNil(SSR.firstPageData(from: "<html></html>"))
    }

    func testMemberParsing() {
        let contents: [[String: Any]] = [
            ["Content": "NO.0001"]
        ]
        let segment: [String: Any] = ["Contents": contents]
        let wearList: [[String: Any]] = [
            ["Title": "虞书欣V91", "Segment": segment],
            ["Title": "铁粉", "Segment": segment]
        ]
        let descList: [[String: Any]] = [
            ["Desc": "荣誉值 12345"]
        ]
        let item: [String: Any] = [
            "ItemID": "oABC123",
            "Title": "红颜虞",
            "Pic": "http://thirdqq.qlogo.cn/x.jpg",
            "WearList": wearList,
            "DescList": descList
        ]

        let member = QQMusicParsers.member(from: item, familyID: "3069960_1")
        XCTAssertEqual(member.itemId, "oABC123")
        XCTAssertEqual(member.title, "红颜虞")
        XCTAssertEqual(member.medal, "V91")
        XCTAssertEqual(member.artistName, "虞书欣")
        XCTAssertEqual(member.medalText, "虞书欣V91")
        XCTAssertEqual(member.fanBadge, "NO.0001")
        XCTAssertEqual(member.honor, "12345")
        XCTAssertEqual(member.pic, "https://thirdqq.qlogo.cn/x.jpg")
        XCTAssertEqual(member.familyId, "3069960_1")
    }

    func testMemberWithoutWearFallsBackToTitle() {
        let item: [String: Any] = ["ItemID": "o1", "Title": "无名"]
        let member = QQMusicParsers.member(from: item, familyID: nil)
        XCTAssertEqual(member.medalText, "")
        XCTAssertEqual(member.honorValue, 0)
    }

    func testMedalItemNumberInfoAndDateFallbacks() {
        let numberInfo: [String: Any] = ["Content": "NO.----"]
        let withPlaceholder: [String: Any] = [
            "MedalID": "3069960",
            "Name": "石榴花",
            "PicURL": "http://p1.qpic.cn/a.jpg",
            "NumberInfo": numberInfo,
            "CreateTime": "2026-11-01 12:00:00",
            "Level": 3,
            "State": 2
        ]
        let item = QQMusicParsers.medalItem(from: withPlaceholder, index: 0)
        XCTAssertEqual(item.subText, "2026-11-01")
        XCTAssertTrue(item.isObtained)
        XCTAssertEqual(item.picURL, "https://p1.qpic.cn/a.jpg")
        XCTAssertEqual(item.uid, "3069960-0-石榴花")

        let corner: [String: Any] = ["Title": "2026-10-05 获得"]
        let withCorner: [String: Any] = [
            "MedalID": "1",
            "Name": "灯牌",
            "Corner": corner
        ]
        let cornerItem = QQMusicParsers.medalItem(from: withCorner, index: 1)
        XCTAssertEqual(cornerItem.subText, "2026-10-05")
        XCTAssertFalse(cornerItem.isObtained)
    }

    func testMedalLevelsFromList() {
        let list: [[String: Any]] = [
            ["MedalID": "m1", "Level": 3, "State": 2, "Name": "黄金", "PicURL": "http://a/b.png"],
            ["MedalID": "m1", "Level": 4, "State": 1, "Name": "铂金", "CreateTime": "2026-01-01"]
        ]
        let fanMedalDetail: [String: Any] = ["MedalList": list]
        let data: [String: Any] = ["FanMedalDetail": fanMedalDetail]

        let levels = QQMusicParsers.medalLevels(from: data)
        XCTAssertEqual(levels.count, 2)
        XCTAssertEqual(levels[0].badgeText, "Lv.3")
        XCTAssertTrue(levels[0].isObtained)
        XCTAssertFalse(levels[1].isObtained)
    }

    func testMedalLevelsFromCenterItems() {
        let section: [String: Any] = ["Section": "V7", "Alias": "乐迷", "PicURL": "http://a/c.png"]
        let corner: [String: Any] = ["Desc": "获得", "Title": "2026-02-02"]
        let itemList: [[String: Any]] = [
            ["Section": section, "Corner": corner]
        ]
        let center: [String: Any] = ["ItemList": itemList]
        let fanMedalDetail: [String: Any] = ["Center": center]
        let data: [String: Any] = ["FanMedalDetail": fanMedalDetail]

        let levels = QQMusicParsers.medalLevels(from: data)
        XCTAssertEqual(levels.count, 1)
        XCTAssertEqual(levels[0].level, 7)
        XCTAssertEqual(levels[0].badgeText, "V7")
        XCTAssertTrue(levels[0].isCenter)
        XCTAssertTrue(levels[0].isObtained)
    }

    func testFanOverview() {
        let section: [String: Any] = ["Section": "V9", "Alias": "石榴花"]
        let corner: [String: Any] = ["Title": "乐迷榜第 1 名", "Desc": "本周"]
        let proportion: [String: Any] = ["Current": 120, "UpperLimit": 400]
        let fanMedalDetail: [String: Any] = [
            "Name": "虞书欣",
            "PicURL": "http://a/d.png",
            "Section": section,
            "Corner": corner,
            "Proportion": proportion
        ]
        let data: [String: Any] = ["FanMedalDetail": fanMedalDetail]

        let fan = QQMusicParsers.fanOverview(from: data)
        XCTAssertEqual(fan?.name, "虞书欣")
        XCTAssertEqual(fan?.section, "V9")
        XCTAssertEqual(fan?.alias, "石榴花")
        XCTAssertEqual(fan?.current, 120)
        XCTAssertEqual(fan?.upperLimit, 400)
        XCTAssertEqual(fan?.progress ?? 0, 0.3, accuracy: 0.0001)
    }

    func testRankTabDetailParsing() {
        let contents: [[String: Any]] = [
            ["Content": "NO.0001"],
            ["Content": "V91"]
        ]
        let segment: [String: Any] = ["Contents": contents]
        let wear: [String: Any] = ["Segment": segment]
        let desc: [String: Any] = ["Desc": "荣誉 123"]
        let entry: [String: Any] = [
            "Position": 1,
            "Title": "红颜虞",
            "Pic": "http://a/e.png",
            "ItemID": "o1",
            "WearList": [wear],
            "DescList": [desc],
            "PraiseNum": 8,
            "IsPraised": true
        ]
        let fixedInfo: [String: Any] = ["Title": "本周榜"]
        let emptyInfo: [String: Any] = ["Text": "暂无数据"]
        let banner: [String: Any] = ["Text": "去参加活动", "Scheme": "https://y.qq.com/act"]
        let detail: [String: Any] = [
            "FixedInfo": fixedInfo,
            "EmptyInfo": emptyInfo,
            "Banner": banner,
            "FirstPageInfo": [entry]
        ]

        let result = QQMusicParsers.rankTabDetail(
            tab: RankTab(name: "周榜", type: 1, firstShow: true),
            detail: detail
        )
        XCTAssertEqual(result.fixedTitle, "本周榜")
        XCTAssertEqual(result.emptyText, "暂无数据")
        XCTAssertEqual(result.bannerText, "去参加活动")
        XCTAssertEqual(result.bannerLink, "https://y.qq.com/act")
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].position, 1)
        XCTAssertEqual(result.entries[0].wear, ["NO.0001 V91"])
        XCTAssertEqual(result.entries[0].desc, ["荣誉 123"])
        XCTAssertEqual(result.entries[0].praiseNum, 8)
        XCTAssertTrue(result.entries[0].isPraised)
    }

    func testSkinParsing() {
        let unlockTask: [String: Any] = ["Title": "完成任务"]
        let levelUnlockGuide: [String: Any] = ["TaskList": [unlockTask]]
        let level: [String: Any] = [
            "State": 2,
            "BGColor": "#ffffff",
            "LevelUnlockGuide": levelUnlockGuide
        ]
        let item: [String: Any] = [
            "ID": "3069960-12",
            "Seq": 12,
            "Name": "星光皮肤",
            "Pic": "http://a/f.png",
            "CategID": "3",
            "SeqNo": "NO.12",
            "LevelList": [level]
        ]

        let skin = QQMusicParsers.skin(from: item, medalId: "3069960", index: 0)
        XCTAssertEqual(skin.id, "3069960-12")
        XCTAssertEqual(skin.seq, 12)
        XCTAssertTrue(skin.isUnlocked)
        XCTAssertEqual(skin.stateText, "已解锁")
        XCTAssertEqual(skin.subText, "NO.12")
        XCTAssertEqual(skin.categId, "3")
        XCTAssertEqual(skin.unlockTask, "完成任务")
        XCTAssertEqual(skin.pic, "https://a/f.png")
    }

    func testSkinPageParsing() {
        let skin: [String: Any] = ["ID": "1-1", "Seq": 1, "Name": "皮一", "Pic": "https://a/1.png"]
        let data: [String: Any] = [
            "SkinTotal": 3,
            "MedalName": "石榴花",
            "HasMore": true,
            "NextCursor": "next",
            "SkinList": [skin]
        ]
        let response: [String: Any] = ["code": 0, "data": data]

        let page = QQMusicParsers.skinPage(from: response, medalId: "1")
        XCTAssertEqual(page.total, 3)
        XCTAssertEqual(page.medalName, "石榴花")
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.nextCursor, "next")
        XCTAssertEqual(page.list.count, 1)
    }

    func testFamilyParsing() {
        let detailItems: [[String: Any]] = [
            ["Desc": "总荣誉", "Title": "944.3万+"],
            ["Desc": "周排名", "Title": "1"],
            ["Desc": "PK胜场", "Title": "46"],
            ["Desc": "成员数", "Title": "30"]
        ]
        let data: [String: Any] = [
            "Name": "石榴花",
            "Avatar": "http://a/g.png",
            "Announcement": "如繁花涌向天边",
            "DetailItemList": detailItems
        ]

        let family = QQMusicParsers.family(
            from: data,
            id: "3069960_1",
            rawURL: "https://i2.y.qq.com/?family_id=3069960_1"
        )
        XCTAssertEqual(family.displayName, "石榴花")
        XCTAssertEqual(family.honor, "944.3万+")
        XCTAssertEqual(family.rank, "1")
        XCTAssertEqual(family.pkWins, "46")
        XCTAssertEqual(family.members, "30")
        XCTAssertEqual(family.sign, "如繁花涌向天边")
        XCTAssertEqual(family.avatar, "https://a/g.png")
    }

    func testFamilyIDExtraction() {
        XCTAssertEqual(
            QQMusicParsers.familyID(fromHTML: "<a href=\"https://i2.y.qq.com/?family_id=3069960_1&x=1\">"),
            "3069960_1"
        )
        XCTAssertEqual(
            QQMusicParsers.familyID(fromURL: "https://i2.y.qq.com/?family_id=3069960_1"),
            "3069960_1"
        )
        XCTAssertNil(QQMusicParsers.familyID(fromURL: "https://i2.y.qq.com/"))
    }

    func testStarDetailParams() {
        let params = QQMusicParsers.starDetailParams(
            from: "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3/star_detail.html?medal_id=3069960&enc_uin=o123&level=3"
        )
        XCTAssertEqual(params.medalId, "3069960")
        XCTAssertEqual(params.encUin, "o123")
        XCTAssertTrue(QQMusicParsers.isStarDetailURL(
            "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3/star_detail.html?medal_id=1"
        ))
    }

    func testMedalPageBasics() {
        let tabList: [[String: Any]] = [
            ["ID": 1, "Name": "勋章"],
            ["ID": 2, "Name": "乐迷", "FirstShow": true]
        ]
        let cardList: [[String: Any]] = [
            ["MedalID": "m1", "Name": "石榴花", "Scheme": "https://a"]
        ]
        let module: [String: Any] = [
            "ModuleID": 11,
            "ModuleName": "我的勋章",
            "CardList": cardList
        ]
        let tabInfo: [String: Any] = ["ModuleList": [module]]
        let data: [String: Any] = [
            "EncUin": "o999",
            "Desc": "30",
            "CurrTabID": 2,
            "TabList": tabList,
            "TabInfo": tabInfo
        ]
        let root: [String: Any] = ["data": data]

        let basics = QQMusicParsers.medalPageBasics(from: root)
        XCTAssertEqual(basics.encUin, "o999")
        XCTAssertEqual(basics.desc, "30")
        XCTAssertEqual(basics.currentTabID, 2)
        XCTAssertEqual(basics.tabs.count, 2)
        XCTAssertEqual(basics.modules.count, 1)
        XCTAssertEqual(basics.modules[0].items.count, 1)
        XCTAssertEqual(basics.modules[0].items[0].name, "石榴花")
    }

    func testFormattingHelpers() {
        XCTAssertEqual(Fmt.honorNumber("+944.3"), 944.3)
        XCTAssertEqual(Fmt.honorNumber("1,234"), 1234)
        XCTAssertEqual(Fmt.honorNumber("--"), 0)
        XCTAssertEqual(QQMusicParsers.normalizeImageURL("http://a/b.png"), "https://a/b.png")
        XCTAssertEqual(QQMusicParsers.normalizeImageURL("https://a/b.png"), "https://a/b.png")
        XCTAssertEqual(QQMusicParsers.skinCategoryName("other"), "其他系列")
        XCTAssertEqual(QQMusicParsers.skinCategoryName("3"), "系列 3")
    }
}
