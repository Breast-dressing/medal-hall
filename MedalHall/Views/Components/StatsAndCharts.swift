import SwiftUI
import Charts

/// 一项统计（数值 + 标签，可带箭头）。
struct StatItem {
    var value: String
    var label: String
    var showsArrow: Bool = false
    var action: (() -> Void)?
}

/// 四项统计横向排列（周榜排名 / 月榜排名 / 勋章皮肤 / 已获得奖章）。
struct StatsRowView: View {
    var items: [StatItem]
    var spacing: CGFloat = 4

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { pair in
                let item = pair.element
                if let action = item.action {
                    Button(action: action) {
                        cell(item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.label) \(item.value)")
                    .accessibilityAddTraits(.isButton)
                } else {
                    cell(item)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.label) \(item.value)")
                }
            }
        }
    }

    private func cell(_ item: StatItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.value)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.primary)
            HStack(spacing: 2) {
                Text(item.label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
                if item.showsArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

/// 三环进度里的一项（图例用）。
struct RingItem: Identifiable {
    var label: String
    var color: Color
    var text: String
    var percent: Double

    var id: String { "\(label)-\(text)-\(percent)" }
}

/// 三环进度：系统 `HKActivityRingView` + 图例。
///
/// 圆环完全由系统控件绘制；`HKActivityRingView` 自带深色底片，所以用一块深色圆角卡片承载它，
/// 图例也放在卡片里，避免深色底片直接落在浅色页面上。
struct RingHeroView: View {
    var items: [RingItem]
    var showsLegend: Bool = true
    var size: CGFloat = 180

    var body: some View {
        HStack(spacing: 16) {
            ActivityRingsView(items: items)
                .frame(width: size, height: size)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)

            if showsLegend && !items.isEmpty {
                legend
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(white: 0.05))
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
    }

    private var accessibilityText: String {
        items.map { "\($0.label) \($0.text)" }.joined(separator: "，")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(items, id: \.id) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Text(item.text)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(item.color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 近 7 天荣誉条形图。使用系统 Swift Charts（`Chart` + `BarMark`），不手绘条形。
///
/// Swift Charts 会把同一 X 位置的多个 BarMark 默认堆叠，所以轨道和填充拆成两张参数完全一致的
/// 图表叠放：底层是灰色满高轨道，上层是荣誉值填充，两者的绘图区严格对齐。
struct BarChartView: View {
    var title: String
    /// 真实数据（周一…周日）；为空或全 0 时使用原 Web 版的占位高度。
    var values: [Double]?

    private let labels = ["一", "二", "三", "四", "五", "六", "日"]
    private let placeholder: [Double] = [72, 45, 88, 60, 78, 38, 66]

    private struct DayBar: Identifiable {
        var index: Int
        var fraction: Double

        var id: Int { index }
    }

    private var bars: [DayBar] {
        let fractions: [Double]
        if let values, values.count == 7, values.contains(where: { $0 > 0 }) {
            let maxValue = max(values.max() ?? 1, 1)
            fractions = values.map { min(1, max(0, $0 / maxValue)) }
        } else {
            fractions = placeholder.map { $0 / 100 }
        }
        return fractions.enumerated().map { index, fraction in
            DayBar(index: index, fraction: max(fraction, 0.02))
        }
    }

    private var fill: LinearGradient {
        LinearGradient(
            colors: [Theme.barFillTop, Theme.barFillBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            ZStack {
                trackChart
                valueChart
            }
            .frame(height: 150)

            labelsRow
        }
    }

    private var trackChart: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("星期", bar.index),
                    y: .value("轨道", 1.0),
                    width: .fixed(22)
                )
                .foregroundStyle(Theme.barTrack)
                .cornerRadius(11)
            }
        }
        .chartXScale(domain: -0.5...6.5)
        .chartYScale(domain: 0.0...1.0)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private var valueChart: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("星期", bar.index),
                    y: .value("荣誉", bar.fraction),
                    width: .fixed(22)
                )
                .foregroundStyle(fill)
                .cornerRadius(11)
            }
        }
        .chartXScale(domain: -0.5...6.5)
        .chartYScale(domain: 0.0...1.0)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private var labelsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { pair in
                Text(pair.element)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}
