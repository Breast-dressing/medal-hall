import SwiftUI

/// 头像（异步加载，失败时用系统占位图标）。
struct RemoteAvatar: View {
    var url: String
    var size: CGFloat = 56
    var placeholderSystemImage: String = "person.crop.circle.fill"

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case let .success(image):
                image.resizable().scaledToFill()
            default:
                Image(systemName: placeholderSystemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.separator)
                    .padding(2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.separator.opacity(0.6), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    private var imageURL: URL? {
        let normalized = QQMusicParsers.normalizeImageURL(url)
        guard normalized.hasPrefix("http") else { return nil }
        return URL(string: normalized)
    }
}

/// 勋章 / 皮肤缩略图。
struct MedalThumb: View {
    var url: String
    var locked: Bool = false
    var size: CGFloat = 78
    var cornerRadius: CGFloat = 14

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case let .success(image):
                image.resizable().scaledToFill()
            default:
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.barTrack)
                    .overlay(
                        Image(systemName: "rosette")
                            .font(.system(size: size * 0.28))
                            .foregroundStyle(Theme.tertiaryText)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .center) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.2))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
        }
        .accessibilityHidden(true)
    }

    private var imageURL: URL? {
        let normalized = QQMusicParsers.normalizeImageURL(url)
        guard normalized.hasPrefix("http") else { return nil }
        return URL(string: normalized)
    }
}

/// 小圆角标签：勋章等级、编号等。
struct TagPill: View {
    var text: String
    var color: Color = Theme.secondaryText
    var background: Color = Color.black.opacity(0.05)

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .foregroundStyle(color)
    }
}

/// 页面里的错误态 + 重试。
struct ErrorStateView: View {
    var message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Theme.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            if let retry {
                Button("重试", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .cardStyle()
    }
}

/// 空态卡片。
struct EmptyStateCard: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .cardStyle()
    }
}
