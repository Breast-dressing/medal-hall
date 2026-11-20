import SwiftUI
import HealthKit
import HealthKitUI

/// 系统健身环 `HKActivityRingView` 的 SwiftUI 桥接。
///
/// 只使用系统控件绘制三环（活动 / 锻炼 / 站立），不自行绘制环的样式；
/// `RingItem.percent` 会映射成对应的完成度：
/// 第 1 环 = 红色活动环，第 2 环 = 绿色锻炼环，第 3 环 = 蓝色站立环。
struct ActivityRingsView: UIViewRepresentable {
    var items: [RingItem]

    func makeUIView(context: Context) -> HKActivityRingView {
        let view = HKActivityRingView(frame: .zero)
        view.backgroundColor = .clear
        view.setActivitySummary(summary, animated: false)
        return view
    }

    func updateUIView(_ view: HKActivityRingView, context: Context) {
        view.setActivitySummary(summary, animated: true)
    }

    /// 把 0…1 的进度换算成 HKActivitySummary 的「当前值 / 目标值」。
    private var summary: HKActivitySummary {
        let values = items.prefix(3).map { min(max($0.percent, 0), 1) }
        let move = values.count > 0 ? values[0] : 0
        let exercise = values.count > 1 ? values[1] : 0
        let stand = values.count > 2 ? values[2] : 0

        let summary = HKActivitySummary()
        summary.activityMoveMode = .activeEnergy
        summary.activeEnergyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: move * 500)
        summary.activeEnergyBurnedGoal = HKQuantity(unit: .kilocalorie(), doubleValue: 500)
        summary.appleExerciseTime = HKQuantity(unit: .minute(), doubleValue: exercise * 30)
        summary.appleExerciseTimeGoal = HKQuantity(unit: .minute(), doubleValue: 30)
        summary.appleStandHours = HKQuantity(unit: .count(), doubleValue: stand * 12)
        summary.appleStandHoursGoal = HKQuantity(unit: .count(), doubleValue: 12)
        return summary
    }
}
