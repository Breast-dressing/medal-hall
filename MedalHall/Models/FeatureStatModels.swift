import Foundation

/// 三个特色统计入口（原 Web 版 FEATURE_STAT_CONFIG）。
enum FeatureKind: String, CaseIterable, Identifiable, Hashable {
    case producer
    case fan
    case station

    var id: String { rawValue }

    var title: String {
        switch self {
        case .producer: return "巅峰制作人"
        case .fan: return "乐迷灯牌"
        case .station: return "星光发电站"
        }
    }
}

/// 统计页时间范围（原 Web 版 FEATURE_STAT_RANGES）。
enum FeatureRange: String, CaseIterable, Identifiable, Hashable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        }
    }

    var period: String {
        switch self {
        case .day: return "今天"
        case .week: return "本周"
        case .month: return "本月"
        case .year: return "今年"
        }
    }

    /// 横轴槽位数量，决定柱状图的宽度。
    var slots: Int {
        switch self {
        case .day: return 24
        case .week: return 7
        case .month: return 30
        case .year: return 12
        }
    }

    var axisLabels: [FeatureAxisLabel] {
        switch self {
        case .day:
            return [
                FeatureAxisLabel(at: 0, text: "0时"),
                FeatureAxisLabel(at: 0.25, text: "6时"),
                FeatureAxisLabel(at: 0.5, text: "12时"),
                FeatureAxisLabel(at: 0.75, text: "18时")
            ]
        case .week:
            let names = ["一", "二", "三", "四", "五", "六", "日"]
            return names.enumerated().map { index, name in
                FeatureAxisLabel(at: (Double(index) + 0.5) / 7.0, text: name)
            }
        case .month:
            return [
                FeatureAxisLabel(at: 0.02, text: "1"),
                FeatureAxisLabel(at: 0.17, text: "5"),
                FeatureAxisLabel(at: 0.34, text: "10"),
                FeatureAxisLabel(at: 0.5, text: "15"),
                FeatureAxisLabel(at: 0.67, text: "20"),
                FeatureAxisLabel(at: 0.84, text: "25"),
                FeatureAxisLabel(at: 0.98, text: "30")
            ]
        case .year:
            return [
                FeatureAxisLabel(at: 0.04, text: "1月"),
                FeatureAxisLabel(at: 0.29, text: "4月"),
                FeatureAxisLabel(at: 0.54, text: "7月"),
                FeatureAxisLabel(at: 0.79, text: "10月")
            ]
        }
    }

    /// 纵轴刻度（上 / 中 / 下），与 Web 版一致：最高值不足 40 时按 40 计算。
    func yTicks(series: [Double]) -> [Double] {
        let maxValue = series.max() ?? 0
        let top = maxValue > 40 ? (maxValue / 20).rounded(.up) * 20 : 40
        return [top, top / 2, 0]
    }
}

struct FeatureAxisLabel: Identifiable, Hashable {
    var at: Double
    var text: String

    var id: String { "\(text)-\(at)" }
}

/// 统计页数据载荷：series 为空即「暂无数据」。
struct FeatureStatPayload: Hashable {
    var series: [Double]
    var total: Double?

    var hasData: Bool { series.contains { $0 > 0 } }
}
