import SwiftUI

/// 四 tab 容器：动态 / 影视 / 音乐 为占位页，「我的」是主页面。
struct RootView: View {
    enum Tab: Hashable {
        case feed
        case video
        case music
        case profile
    }

    @State private var selection: Tab = .profile

    var body: some View {
        TabView(selection: $selection) {
            PlaceholderPage(title: "动态", systemImage: "bubble.left", message: "QQ 音乐的动态数据尚未接入")
                .tabItem { Label("动态", systemImage: "bubble.left") }
                .tag(Tab.feed)

            PlaceholderPage(title: "影视", systemImage: "play.rectangle", message: "QQ 音乐的影视数据尚未接入")
                .tabItem { Label("影视", systemImage: "play.rectangle") }
                .tag(Tab.video)

            PlaceholderPage(title: "音乐", systemImage: "music.note", message: "QQ 音乐的音乐数据尚未接入")
                .tabItem { Label("音乐", systemImage: "music.note") }
                .tag(Tab.music)

            HomeView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .tint(Theme.blue)
    }
}

private struct PlaceholderPage: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
                .navigationTitle(title)
        }
    }
}
