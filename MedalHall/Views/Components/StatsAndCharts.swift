import SwiftUI

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
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
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

/// 三环进度（外 → 内），对应原 Web 版的 renderRingHero。
struct RingItem: Identifiable {
    var label: String
    var color: Color
    var text: String
    var percent: Double

    var id: String { "\(label)-\(text)-\(percent)" }
}

struct RingHeroView: View {
    var items: [RingItem]
    var showsLegend: Bool = true
    var size: CGFloat = 200

    private let radii: [CGFloat] = [84, 62, 40, 22]
    private let lineWidth: CGFloat = 13

    var body: some View {
        HStack(spacing: 20) {
            rings
            if showsLegend && !items.isEmpty {
                legend
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        items.map { "\($0.label) \($0.text)" }.joined(separator: "，")
    }

    private var rings: some View {
        ZStack {
            Circle()
                .fill(Theme.card)
                .frame(width: 32, height: 32)
            ForEach(Array(items.prefix(4).enumerated()), id: \.offset) { index, item in
                let radius = radii[min(index, radii.count - 1)]
                Circle()
                    .stroke(item.color.opacity(0.16), lineWidth: lineWidth)
                    .frame(width: radius * 2, height: radius * 2)
                Circle()
                    .trim(from: 0, to: min(max(item.percent, 0.004), 1))
                    .stroke(item.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
        .frame(width: size, height: size)
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
                            .foregroundStyle(item.color)
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

/// 近 7 天荣誉条形图（Apple 健身风）。
struct BarChartView: View {
    var title: String
    /// 真实数据（周一…周日）；为空或全 0 时使用原 Web 版的占位高度。
    var values: [Double]?

    private let labels = ["一", "二", "三", "四", "五", "六", "日"]
    private let placeholder: [Double] = [72, 45, 88, 60, 78, 38, 66]
    private let chartHeight: CGFloat = 132
    private let barWidth: CGFloat = 22

    private var fractions: [Double] {
        if let values, values.count == 7, values.contains(where: { $0 > 0 }) {
            let maxValue = max(values.max() ?? 1, 1)
            return values.map { min(1, max(0, $0 / maxValue)) }
        }
        return placeholder.map { $0 / 100 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Theme.barTrack)
                                .frame(width: barWidth, height: chartHeight)
                            if fractions[index] > 0 {
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Theme.barFillTop, Theme.barFillBottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    .frame(width: barWidth, height: max(8, chartHeight * fractions[index]))
                            }
                        }
                        .frame(height: chartHeight, alignment: .bottom)

                        Text(labels[index])
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("周\(labels[index])")
                }
            }
        }
    }
}
