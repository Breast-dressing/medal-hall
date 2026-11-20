import SwiftUI

/// 全部勋章（对应原 Web 版 renderMedalsListView）：Tab 切换 + 模块卡片。
struct MedalsListView: View {
    @Environment(MemberMedalModel.self) private var model
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let page = model.page, !page.tabs.isEmpty {
                    let index = min(max(selectedTab, 0), page.tabs.count - 1)

                    if page.tabs.count > 1 {
                        Picker("勋章分类", selection: $selectedTab) {
                            ForEach(Array(page.tabs.enumerated()), id: \.offset) { pair in
                                Text(tabTitle(pair.element, index: pair.offset)).tag(pair.offset)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if let result = page.tabs[safe: index] {
                        if result.success {
                            if result.modules.isEmpty {
                                EmptyStateCard(text: "暂无模块")
                            } else {
                                ForEach(result.modules) { module in
                                    moduleCard(module, tabName: result.tab.name)
                                }
                            }
                        } else {
                            EmptyStateCard(text: "请求失败：\(result.errorMessage ?? "未知错误")")
                        }
                    }
                } else if model.isInitialLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if let failure = model.failureMessage {
                    ErrorStateView(message: failure) {
                        Task {
                            await model.load(url: QQMusicClient.medalURL(forItemID: model.member.itemId))
                        }
                    }
                } else {
                    EmptyStateCard(text: "暂无奖章数据")
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("全部勋章")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tabTitle(_ result: MedalTabResult, index: Int) -> String {
        result.tab.name.isEmpty ? "Tab \(index + 1)" : result.tab.name
    }

    private func moduleCard(_ module: MedalModule, tabName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(module.moduleName)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if module.moduleId != 0 {
                    NavigationLink(value: MedalRoute.module(
                        moduleId: module.moduleId,
                        moduleName: module.moduleName,
                        tabName: tabName
                    )) {
                        Text("更多")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }

            if module.items.isEmpty {
                Text("暂无")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(module.items.prefix(3))) { item in
                        MedalCell(item: item, tabName: tabName)
                    }
                    if module.items.count < 3 {
                        ForEach(0..<(3 - module.items.count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

/// 单个勋章格子（点击进入勋章详情，「乐迷」Tab 下同时扫描皮肤）。
struct MedalCell: View {
    let item: MedalItem
    let tabName: String

    var body: some View {
        NavigationLink(value: MedalRoute.medal(
            medalId: item.medalId,
            medalName: item.name,
            scheme: item.scheme,
            enableSkins: tabName.contains("乐迷")
        )) {
            VStack(spacing: 6) {
                MedalThumb(url: item.picURL, locked: !item.isObtained, size: 76)
                Text(item.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                if !item.subText.isEmpty {
                    Text(item.subText)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(item.medalId.isEmpty)
    }
}
