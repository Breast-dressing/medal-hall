import XCTest
@testable import MedalHall

/// `-demo-data` 示例数据必须能支撑三页截图（我的 / 家族详情 / 成员详情）。
final class DemoSupportTests: XCTestCase {
    func testDemoFamiliesAndMembers() {
        XCTAssertEqual(DemoSupport.families.count, 3)
        XCTAssertTrue(DemoSupport.families.contains(where: { $0.displayName == "石榴花" }))
        XCTAssertEqual(DemoSupport.members.count, 5)
        XCTAssertEqual(DemoSupport.member.title, "红颜虞")
        XCTAssertFalse(DemoSupport.medalURL.isEmpty)
        XCTAssertTrue(DemoSupport.medalURL.contains(DemoSupport.memberItemID))
    }

    func testDemoMedalPageAndFanProgress() {
        let page = DemoSupport.medalPage
        XCTAssertEqual(page.desc, "196")
        XCTAssertEqual(page.tabs.count, 2)
        XCTAssertTrue(page.tabs.contains(where: { $0.tab.name.contains("乐迷") }))
        XCTAssertEqual(DemoSupport.fan.progress, 0.3, accuracy: 0.0001)
        XCTAssertEqual(DemoSupport.skinMedal.medalId, "3069960")
    }

    func testDemoHonorStoreFeedsWeekChart() {
        let store = DemoSupport.honorStore
        XCTAssertFalse(store.isEmpty)
        XCTAssertTrue(store.allSatisfy { !$0.records.isEmpty })
        let records = store.flatMap { $0.records }
        XCTAssertFalse(HonorAggregator.weeklyValues(records).allSatisfy { $0 == 0 })
    }
}
