import XCTest
@testable import MedalHall

/// 荣誉记录：HAR 解析、按日折叠、近 7 天聚合。
final class HonorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NSTimeZone.default = TimeZone(identifier: "UTC")!
    }

    override func tearDown() {
        NSTimeZone.resetSystemTimeZone()
        super.tearDown()
    }

    func testParseHAR() throws {
        let inner = """
        [{"Title":"完成任务@石榴花。","Date":"2026年11月01日 12:34","Value":"+12.5"},{"Title":"充值@石榴枝","Date":"2026年11月02日 09:00","Value":"+30"}]
        """
        let honorRequest: [String: Any] = [
            "url": "https://u6.y.qq.com/cgi-bin/musics.fcg?_webcgikey=GetFamilyHonorRecord&_=123"
        ]
        let honorContent: [String: Any] = ["text": inner]
        let honorResponse: [String: Any] = ["content": honorContent]
        let honorEntry: [String: Any] = ["request": honorRequest, "response": honorResponse]

        let otherRequest: [String: Any] = ["url": "https://other.example.com/api"]
        let otherContent: [String: Any] = ["text": "[]"]
        let otherResponse: [String: Any] = ["content": otherContent]
        let otherEntry: [String: Any] = ["request": otherRequest, "response": otherResponse]

        let entries: [[String: Any]] = [honorEntry, otherEntry]
        let har: [String: Any] = ["log": ["entries": entries]]
        let data = try JSONSerialization.data(withJSONObject: har)
        let result = try HonorImporter.parse(data: data, fileName: "honor.har")

        XCTAssertEqual(result.responseCount, 1)
        XCTAssertEqual(result.recordCount, 2)
        XCTAssertEqual(result.memberCount, 2)
        XCTAssertEqual(result.groups.first(where: { $0.name == "石榴花" })?.records.first?.taskName, "完成任务")
        XCTAssertEqual(result.records.first?.value, "+12.5")
    }

    func testParseHARMissingEntriesThrows() throws {
        let entries: [[String: Any]] = []
        let har: [String: Any] = ["log": ["entries": entries]]
        let data = try JSONSerialization.data(withJSONObject: har)
        XCTAssertThrowsError(try HonorImporter.parse(data: data, fileName: "empty.har"))
    }

    func testExtractHonorArrayAndBlocks() {
        let text = "prefix[{\"A\":1}]suffix"
        XCTAssertEqual(HonorImporter.extractHonorArray(text), "[{\"A\":1}]")
        XCTAssertEqual(HonorImporter.blocks(in: "[{\"A\":1},{\"B\":2}]").count, 2)
    }

    func testDecodeBase64Content() {
        let raw = "[{\"Title\":\"a@b\",\"Date\":\"2026年11月01日\",\"Value\":\"+1\"}]"
        let encoded = Data(raw.utf8).base64EncodedString()
        let content: [String: Any] = ["text": encoded, "encoding": "base64"]
        XCTAssertEqual(HonorImporter.decodeContent(content), raw)
    }

    func testGroupingAndTotals() {
        let records = [
            HonorRecord(taskName: "a", date: "2026年11月01日 10:00", value: "+10"),
            HonorRecord(taskName: "b", date: "2026年11月01日 12:00", value: "+5"),
            HonorRecord(taskName: "c", date: "2026年11月02日 09:00", value: "-2.5"),
            HonorRecord(taskName: "d", date: "2026-11-03 08:00", value: "3")
        ]
        let groups = HonorAggregator.groups(from: records)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].dateKey, "2026-11-03")
        XCTAssertEqual(groups[1].dateKey, "2026年11月02日")
        XCTAssertEqual(groups[1].records.first?.taskName, "c")
        let firstDay = groups.first(where: { $0.dateKey == "2026年11月01日" })
        XCTAssertEqual(firstDay?.records.count, 2)
        XCTAssertEqual(firstDay?.records.first?.taskName, "b")
        XCTAssertEqual(firstDay?.total ?? 0, 15, accuracy: 0.001)
        XCTAssertEqual(groups.first(where: { $0.dateKey == "2026-11-03" })?.total ?? 0, 3, accuracy: 0.001)
    }

    func testWeekGroupsFiltering() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let now = formatter.date(from: "2026-11-18") else {
            return XCTFail("日期构造失败")
        }
        let records = [
            HonorRecord(taskName: "a", date: "2026年11月12日 10:00", value: "+1"),
            HonorRecord(taskName: "b", date: "2026年11月17日 10:00", value: "+2"),
            HonorRecord(taskName: "c", date: "2026年11月18日 10:00", value: "+4")
        ]
        let groups = HonorAggregator.groups(from: records)
        let week = HonorAggregator.weekGroups(groups, now: now)
        XCTAssertEqual(week.count, 3)
        XCTAssertEqual(week.first?.dateKey, "2026年11月18日")
    }

    func testWeeklyValuesMondayToSunday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let now = formatter.date(from: "2026-11-18") else {
            return XCTFail("日期构造失败")
        }

        let records = [
            HonorRecord(taskName: "a", date: "2026年11月16日 10:00", value: "+10"),
            HonorRecord(taskName: "b", date: "2026年11月18日 12:00", value: "+5"),
            HonorRecord(taskName: "c", date: "2026年11月22日 12:00", value: "-2"),
            HonorRecord(taskName: "d", date: "2026年11月23日 12:00", value: "+99")
        ]
        let values = HonorAggregator.weeklyValues(records, now: now, calendar: calendar)
        XCTAssertEqual(values.count, 7)
        XCTAssertEqual(values[0], 10, accuracy: 0.001)
        XCTAssertEqual(values[2], 5, accuracy: 0.001)
        XCTAssertEqual(values[6], -2, accuracy: 0.001)
        XCTAssertEqual(HonorAggregator.total(records), 112, accuracy: 0.001)
    }

    func testDayLabel() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let now = formatter.date(from: "2026-11-18") else {
            return XCTFail("日期构造失败")
        }
        XCTAssertEqual(HonorDate.dayLabel("2026年11月18日", now: now, calendar: calendar), "今天")
        XCTAssertEqual(HonorDate.dayLabel("2026年11月17日", now: now, calendar: calendar), "昨天")
        XCTAssertEqual(HonorDate.dayLabel("2026年11月01日", now: now, calendar: calendar), "11月1日 · 周日")
        XCTAssertEqual(HonorDate.dayLabel("未知日期", now: now, calendar: calendar), "未知日期")
    }

    func testDateKeyAndTimeText() {
        XCTAssertEqual(HonorDate.dateKey("2026年11月01日 12:34"), "2026年11月01日")
        XCTAssertEqual(HonorDate.dateKey("2026-11-01 12:34"), "2026-11-01")
        XCTAssertEqual(HonorDate.timeText("2026年11月01日 12:34"), "12:34")
        XCTAssertEqual(HonorDate.timeText("2026年11月01日"), "11月01日")
    }
}

/// 统计页的时间范围配置。
final class FeatureRangeTests: XCTestCase {
    func testSlots() {
        XCTAssertEqual(FeatureRange.day.slots, 24)
        XCTAssertEqual(FeatureRange.week.slots, 7)
        XCTAssertEqual(FeatureRange.month.slots, 30)
        XCTAssertEqual(FeatureRange.year.slots, 12)
    }

    func testPeriodAndAxis() {
        XCTAssertEqual(FeatureRange.day.period, "今天")
        XCTAssertEqual(FeatureRange.week.period, "本周")
        XCTAssertEqual(FeatureRange.month.period, "本月")
        XCTAssertEqual(FeatureRange.year.period, "今年")
        XCTAssertEqual(FeatureRange.day.axisLabels.first?.text, "0时")
        XCTAssertEqual(FeatureRange.week.axisLabels.count, 7)
        XCTAssertEqual(FeatureRange.month.axisLabels.count, 7)
    }

    func testYTicks() {
        XCTAssertEqual(FeatureRange.day.yTicks(series: []), [40, 20, 0])
        XCTAssertEqual(FeatureRange.day.yTicks(series: [25]), [40, 20, 0])
        XCTAssertEqual(FeatureRange.day.yTicks(series: [100]), [100, 50, 0])
        XCTAssertEqual(FeatureRange.day.yTicks(series: [61]), [80, 40, 0])
    }
}
