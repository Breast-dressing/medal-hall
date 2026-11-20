import SwiftUI

/// 巅峰制作人 / 乐迷灯牌 / 星光发电站（原 Web 版 featureStatPage，深色页面）。
struct FeatureStatView: View {
    let kind: FeatureKind

    @State private var range: FeatureRange = .day

    /// 数据接口还未接入：与原版一致，展示「暂无数据」空态。
    private var payload: FeatureStatPayload {
        FeatureStatPayload(series: [], total: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(kind.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Picker("时间范围", selection: $range) {
                    ForEach(FeatureRange.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .colorScheme(.dark)

                Text("总计")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkSecondary)
                    .padding(.top, 2)

                totalView

                Text(range.period)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.darkSecondary)

                chart
                    .padding(.top, 10)

                Text("数据接入后，此处将按日 / 周 / 月 / 年展示趋势")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            .padding(20)
        }
        .background(Theme.darkBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.darkBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    // MARK: - 总计

    @ViewBuilder
    private var totalView: some View {
        if let total = payload.total {
            Text(Fmt.groupedInt(Int(total.rounded())))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        } else {
            HStack(spacing: 4) {
                Capsule()
                    .fill(Theme.darkGridSoft)
                    .frame(width: 12, height: 4)
                Capsule()
                    .fill(Theme.darkGridSoft)
                    .frame(width: 12, height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("总计 --")
        }
    }

    // MARK: - 图表

    private var chart: some View {
        let ticks = range.yTicks(series: payload.series)
        return VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    FeatureGridCanvas(lineCount: ticks.count)
                    if !payload.hasData {
                        Text("暂无数据")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.darkSecondary)
                    }
                }
                .frame(height: 280)

                VStack(alignment: .trailing) {
                    ForEach(Array(ticks.enumerated()), id: \.offset) { pair in
                        Text(tickText(pair.element))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.darkSecondary)
                        if pair.offset < ticks.count - 1 {
                            Spacer()
                        }
                    }
                }
                .frame(width: 30, height: 280, alignment: .trailing)
            }

            axisLabels
                .padding(.trailing, 38)
        }
    }

    private var axisLabels: some View {
        GeometryReader { proxy in
            ForEach(range.axisLabels) { label in
                Text(label.text)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkSecondary)
                    .position(
                        x: min(max(proxy.size.width * label.at, 12), proxy.size.width - 12),
                        y: 8
                    )
            }
        }
        .frame(height: 16)
    }

    private func tickText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

/// 深色坐标网格：竖向虚线 + 横向实线。
struct FeatureGridCanvas: View {
    var lineCount: Int

    var body: some View {
        Canvas { context, size in
            for index in 0...4 {
                let x = size.width * CGFloat(index) / 4
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(
                    path,
                    with: .color(Theme.darkGrid),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 6])
                )
            }

            let rows = max(lineCount - 1, 1)
            for index in 0...rows {
                let y = size.height * CGFloat(index) / CGFloat(rows)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Theme.darkGridSoft), lineWidth: 1)
            }
        }
    }
}
