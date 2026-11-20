import SwiftUI

/// 设计令牌，对应原 Web 版 CSS 变量（--bg-primary / --sys-blue 等）。
enum Theme {
    static let background = Color(red: 0.949, green: 0.949, blue: 0.969)
    static let card = Color.white

    /// 次要文字。原版 #8E8E93 在浅灰背景上对比度不足，这里加深到 #6B6B72。
    static let secondaryText = Color(red: 0.420, green: 0.420, blue: 0.447)
    static let tertiaryText = Color(red: 0.557, green: 0.557, blue: 0.576)
    static let separator = Color(red: 0.898, green: 0.898, blue: 0.918)

    static let red = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let green = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let blue = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let purple = Color(red: 0.686, green: 0.322, blue: 0.871)

    static let ringColors: [Color] = [red, green, blue, orange]

    static let barTrack = Color(red: 0.925, green: 0.925, blue: 0.937)
    static let barFillTop = Color(red: 1.0, green: 0.373, blue: 0.310)
    static let barFillBottom = Color(red: 1.0, green: 0.231, blue: 0.188)

    static let darkBackground = Color.black
    static let darkSecondary = Color(red: 0.557, green: 0.557, blue: 0.576)
    static let darkGrid = Color(white: 0.24)
    static let darkGridSoft = Color(white: 0.34)

    /// 原版卡片：白底 + 24pt 圆角 + 极轻阴影。
    static func cardBackground(cornerRadius: CGFloat = 22) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(card)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

extension View {
    /// 白卡片样式。
    func cardStyle(cornerRadius: CGFloat = 22) -> some View {
        background(Theme.cardBackground(cornerRadius: cornerRadius))
    }

    /// 小圆角标签（勋章等级、编号等）。
    func pillStyle(color: Color, background: Color = Color.black.opacity(0.05)) -> some View {
        padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .foregroundStyle(color)
    }
}
