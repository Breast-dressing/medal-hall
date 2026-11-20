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
        XCTAssertTrue(app.staticTexts["添加家族后显示家族荣誉环"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["选择成员"].waitForExistence(timeout: 5))

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

        let musicTab = app.tabBars.buttons["音乐"]
        XCTAssertTrue(musicTab.waitForExistence(timeout: 5))
        musicTab.tap()
        XCTAssertTrue(app.staticTexts["QQ 音乐的音乐数据尚未接入"].waitForExistence(timeout: 5))

        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        XCTAssertTrue(app.staticTexts["添加家族后显示家族荣誉环"].waitForExistence(timeout: 5))
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
