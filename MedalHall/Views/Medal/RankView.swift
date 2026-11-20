import SwiftUI

/// 排行榜（对应原 Web 版 renderRankView）：Tab + Banner + 名次列表。
struct RankView: View {
    @Environment(MemberMedalModel.self) private var model
    let scheme: String
    let title: String
    let preferredTab: String

    @State private var data: RankData?
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading && data == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if let errorMessage, data == nil {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else if let data {
                    let index = min(max(selectedTab, 0), max(data.tabs.count - 1, 0))

                    if data.tabs.count > 1 {
                        Picker("排行榜分类", selection: $selectedTab) {
                            ForEach(Array(data.tabs.enumerated()), id: \.offset) { tabIndex, result in
                                Text(result.tab.name.isEmpty ? "Tab \(tabIndex + 1)" : result.tab.name)
                                    .tag(tabIndex)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if let result = data.tabs[safe: index] {
                        tabContent(result)
                    }
                } else {
                    EmptyStateCard(text: "暂无数据")
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !didLoad {
                didLoad = true
                await load()
            }
        }
    }

    private var navigationTitle: String {
        if !title.isEmpty { return title }
        if let name = data?.title, !name.isEmpty { return name }
        return "排行榜"
    }

    @ViewBuilder
    private func tabContent(_ result: RankTabDetail) -> some View {
        if let bannerText = result.bannerText {
            if let link = result.bannerLink, let url = URL(string: link) {
                Link(destination: url) {
                    bannerLabel(bannerText)
                }
            } else {
                bannerLabel(bannerText)
            }
        }

        if let fixed = result.fixedTitle {
            Text(fixed)
                .font(.system(size: 13))
                .foregroundStyle(Theme.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }

        if !result.success {
            EmptyStateCard(text: "请求失败：\(result.errorMessage ?? "未知错误")")
        } else if result.entries.isEmpty {
            EmptyStateCard(text: result.emptyText ?? "暂无数据")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(result.entries.enumerated()), id: \.element.id) { index, entry in
                    rankRow(entry)
                    if index < result.entries.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .cardStyle()
        }
    }

    private func bannerLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Theme.blue)
        .padding(10)
        .background(Theme.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func rankRow(_ entry: RankEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.position)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(entry.position <= 3 ? Theme.orange : Theme.secondaryText)
                .frame(width: 26)

            RemoteAvatar(url: entry.pic, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title.isEmpty ? "未命名" : entry.title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                if !entry.wear.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(entry.wear.prefix(3)), id: \.self) { text in
                            TagPill(
                                text: text,
                                color: Color(red: 0.72, green: 0.53, blue: 0.12),
                                background: Theme.orange.opacity(0.1)
                            )
                        }
                    }
                }

                if !entry.desc.isEmpty {
                    Text(entry.desc.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: entry.isPraised ? "heart.fill" : "hand.thumbsup")
                    .font(.system(size: 12))
                Text("\(entry.praiseNum)")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rankData = try await QQMusicClient.shared.fetchStarDetailRanking(url: scheme)
            data = rankData
            errorMessage = nil
            selectedTab = preferredIndex(in: rankData)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preferredIndex(in rankData: RankData) -> Int {
        if !preferredTab.isEmpty {
            if let exact = rankData.tabs.firstIndex(where: { $0.tab.name == preferredTab }) {
                return exact
            }
            if let partial = rankData.tabs.firstIndex(where: { $0.tab.name.contains(preferredTab) }) {
                return partial
            }
        }
        if let firstShow = rankData.tabs.firstIndex(where: { $0.tab.firstShow }) {
            return firstShow
        }
        return 0
    }
}

extension Array {
    /// 越界安全的读取。
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
