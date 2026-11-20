import XCTest

/// 关键流程 + 无障碍审计。UI 测试以条件等待为主，不写 sleep。
final class MedalHallUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        return app
    }

    func testHomeShowsEmptyStatesAndSettings() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["我的"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["添加家族后显示家族荣誉环"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["选择成员，在设置中选择当前归属成员"].waitForExistence(timeout: 5))

        let settings = app.buttons["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        let close = app.buttons["关闭"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        XCTAssertTrue(app.staticTexts["我的"].waitForExistence(timeout: 5))
    }

    func testTabsAreReachable() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["我的"].waitForExistence(timeout: 15))

        let musicTab = app.buttons["音乐"].firstMatch
        XCTAssertTrue(musicTab.waitForExistence(timeout: 5))
        musicTab.tap()
        XCTAssertTrue(app.staticTexts["QQ 音乐的音乐数据尚未接入"].waitForExistence(timeout: 5))

        let profileTab = app.buttons["我的"].firstMatch
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        XCTAssertTrue(app.buttons["添加家族后显示家族荣誉环"].waitForExistence(timeout: 5))
    }

    /// 用示例数据（-demo-data）跑通三个主要页面并留截图：我的 / 家族详情 / 成员详情。
    /// 同时验证「已获得奖章」入口可以返回并关闭，不会卡在成员详情页。
    func testDemoPagesRenderAndExit() {
        let app = XCUIApplication()
        app.launchArguments += ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.staticTexts["我的"].waitForExistence(timeout: 20))
        attach(app.screenshot(), name: "01-home")

        let familyCard = app.buttons["打开石榴花"]
        XCTAssertTrue(familyCard.waitForExistence(timeout: 10))
        familyCard.tap()
        XCTAssertTrue(app.staticTexts["不达标成员"].waitForExistence(timeout: 20))
        attach(app.screenshot(), name: "02-family-detail")

        swipeBack(in: app)
        XCTAssertTrue(app.staticTexts["我的"].waitForExistence(timeout: 10))

        let medalStat = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "已获得奖章"))
            .firstMatch
        XCTAssertTrue(medalStat.waitForExistence(timeout: 10))
        medalStat.tap()
        XCTAssertTrue(app.navigationBars["全部勋章"].waitForExistence(timeout: 20))

        swipeBack(in: app)
        XCTAssertTrue(app.navigationBars["成员详情"].waitForExistence(timeout: 20))
        attach(app.screenshot(), name: "03-member-detail")

        let close = app.buttons["关闭"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(app.staticTexts["我的"].waitForExistence(timeout: 10))
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func swipeBack(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// 无障碍审计：收集问题写进附件。配置里 accessibility_audit 为 warn，不阻断流水线。
    func testAccessibilityAuditOfHome() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["我的"].waitForExistence(timeout: 15))

        var issues: [String] = []
        try app.performAccessibilityAudit(for: .all) { issue in
            issues.append(issue.compactDescription)
            return true
        }

        let report = issues.isEmpty ? "No accessibility issues found." : issues.joined(separator: "\n")
        let attachment = XCTAttachment(string: report)
        attachment.name = "Accessibility audit report"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertFalse(report.isEmpty)
    }
}
