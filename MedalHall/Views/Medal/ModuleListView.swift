import SwiftUI

/// 模块内全部勋章（对应原 Web 版 renderModuleView + 加载更多）。
struct ModuleListView: View {
    @Environment(MemberMedalModel.self) private var model
    let moduleId: Int
    let moduleName: String
    let tabName: String

    @State private var items: [MedalItem] = []
    @State private var lastPos = ""
    @State private var hasNext = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading && items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if let errorMessage, items.isEmpty {
                    ErrorStateView(message: errorMessage) {
                        Task { await load(reset: true) }
                    }
                } else if items.isEmpty {
                    EmptyStateCard(text: "暂无数据")
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            MedalCell(item: item, tabName: tabName)
                        }
                    }

                    if hasNext {
                        Button {
                            Task { await load(reset: false) }
                        } label: {
                            Text(isLoading ? "加载中…" : "加载更多")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .cardStyle()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle(moduleName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !didLoad {
                didLoad = true
                await load(reset: true)
            }
        }
    }

    private func load(reset: Bool) async {
        guard !isLoading else { return }
        if reset {
            items = []
            lastPos = ""
            hasNext = false
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await QQMusicClient.shared.fetchModule(
                encUin: model.encUin,
                moduleId: moduleId,
                lastPos: lastPos,
                pageSize: reset ? 50 : 21
            )
            items.append(contentsOf: result.items)
            lastPos = result.lastPos
            hasNext = result.hasNext
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
