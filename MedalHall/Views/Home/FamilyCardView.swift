import SwiftUI

/// 首页家族卡片（石榴花 / 石榴枝 ...）。
struct FamilyCardView: View {
    let family: Family
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(family.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(family.honorText)
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if family.honorText != "--" {
                    Text("荣誉值")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Text("本周新增\(family.weekHonorText)荣誉值")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
