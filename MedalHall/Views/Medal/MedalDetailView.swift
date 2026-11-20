import SwiftUI

/// 勋章详情（对应原 Web 版 renderMedalView）：乐迷概览 + 等级 + 皮肤。
struct MedalDetailView: View {
    @Environment(MemberMedalModel.self) private var model
    let medalId: String
    let medalName: String
    let scheme: String
    let enableSkins: Bool

    @State private var levels: [MedalLevel] = []
    @State private var fan: FanOverview?
    @State private var shareLink = ""
    @State private var skins: [Skin] = []
    @State private var isLoading = true
    @State private var skinsLoading = false
    @State private var errorMessage: String?
    @State private var expandedGroups: Set<String> = []
    @State private var selectedSkin: Skin?
    @State private var didLoad = false

    private let skinColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading && levels.isEmpty && skins.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if let errorMessage, levels.isEmpty && skins.isEmpty {
                    ErrorStateView(message: errorMessage) {
                        Task { await load(force: true) }
                    }
                } else if levels.isEmpty && skins.isEmpty {
                    EmptyStateCard(text: "暂无数据")
                } else {
                    if let fan {
                        fanOverview(fan)
                    }
                    levelSections
                    if enableSkins {
                        skinsSection
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle(medalName.isEmpty ? "勋章详情" : medalName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSkin) { skin in
            SkinDetailSheet(skin: skin, memberItemID: model.member.itemId)
        }
        .task {
            if !didLoad {
                didLoad = true
                await load(force: false)
            }
        }
    }

    // MARK: - 乐迷概览

    private func fanOverview(_ fan: FanOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RemoteAvatar(url: fan.picURL, size: 56)
                VStack(alignment: .leading, spacing: 5) {
                    Text(fan.name.isEmpty ? medalName : fan.name)
                        .font(.system(size: 20, weight: .bold))
                    HStack(spacing: 6) {
                        if !fan.section.isEmpty {
                            TagPill(text: fan.section, color: Theme.blue, background: Theme.blue.opacity(0.1))
                        }
                        if !fan.alias.isEmpty {
                            Text(fan.alias)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                Spacer()
            }

            if !fan.rankTitle.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 14))
                    Text(fan.rankTitle)
                        .font(.system(size: 13, weight: .medium))
                    if !fan.rankDesc.isEmpty {
                        Text(fan.rankDesc)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                }
                .foregroundStyle(Theme.orange)
            }

            if !shareLink.isEmpty {
                NavigationLink(value: MedalRoute.rank(
                    scheme: shareLink,
                    title: "\(fan.name.isEmpty ? medalName : fan.name)·排行榜",
                    tabName: ""
                )) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                        Text("查看地区排行榜")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.blue)
                    .padding(10)
                    .background(
                        Theme.blue.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - 等级

    @ViewBuilder
    private var levelSections: some View {
        let centerLevels = levels.filter(\.isCenter).sorted { $0.level < $1.level }
        let medalLevels = levels.filter { !$0.isCenter }.sorted { $0.level < $1.level }

        if !centerLevels.isEmpty {
            levelGroup(title: "乐迷等级", items: centerLevels)
        }
        if !medalLevels.isEmpty {
            levelGroup(title: "勋章等级", items: medalLevels)
        }
    }

    private func levelGroup(title: String, items: [MedalLevel]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, level in
                    levelRow(level)
                    if index < items.count - 1 {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .cardStyle()
        }
    }

    private func levelRow(_ level: MedalLevel) -> some View {
        HStack(spacing: 12) {
            MedalThumb(url: level.picURL, size: 46, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    TagPill(
                        text: level.badgeText,
                        color: level.isObtained ? Theme.green : Theme.secondaryText,
                        background: level.isObtained ? Theme.green.opacity(0.12) : Color.black.opacity(0.05)
                    )
                    Text(level.name.isEmpty ? "未命名" : level.name)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(level.isObtained ? "已获得" : "未获得")
                        .font(.system(size: 12))
                        .foregroundStyle(level.isObtained ? Theme.green : Theme.secondaryText)
                    if !level.createTime.isEmpty {
                        Text(level.createTime)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 皮肤

    private struct SkinGroup: Identifiable {
        var key: String
        var name: String
        var skins: [Skin]

        var id: String { key }
    }

    private var skinGroups: [SkinGroup] {
        let grouped = Dictionary(grouping: skins) { $0.categId.isEmpty ? "other" : $0.categId }
        let keys = grouped.keys.sorted { lhs, rhs in
            if lhs == "other" { return false }
            if rhs == "other" { return true }
            return (Int(lhs) ?? 0) < (Int(rhs) ?? 0)
        }
        return keys.map { key in
            SkinGroup(
                key: key,
                name: QQMusicParsers.skinCategoryName(key),
                skins: (grouped[key] ?? []).sorted { $0.seq < $1.seq }
            )
        }
    }

    @ViewBuilder
    private var skinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("勋章皮肤")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("(\(skins.count))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                if skinsLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }

            if skins.isEmpty {
                if skinsLoading {
                    Text("正在扫描勋章皮肤数据…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .cardStyle()
                } else {
                    EmptyStateCard(text: "未找到此勋章的皮肤数据")
                }
            } else {
                ForEach(skinGroups) { group in
                    skinGroupView(group)
                }
            }
        }
    }

    private func skinGroupView(_ group: SkinGroup) -> some View {
        let expanded = expandedGroups.contains(group.key)
        let visible = expanded ? group.skins : Array(group.skins.prefix(3))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.name)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(group.skins.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }

            LazyVGrid(columns: skinColumns, spacing: 14) {
                ForEach(visible) { skin in
                    Button {
                        selectedSkin = skin
                    } label: {
                        skinCell(skin)
                    }
                    .buttonStyle(.plain)
                }
            }

            if group.skins.count > 3 {
                Button {
                    if expanded {
                        expandedGroups.remove(group.key)
                    } else {
                        expandedGroups.insert(group.key)
                    }
                } label: {
                    Text(expanded ? "收起" : "展开全部（还有 \(group.skins.count - 3) 个）")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func skinCell(_ skin: Skin) -> some View {
        VStack(spacing: 6) {
            MedalThumb(url: skin.pic, locked: !skin.isUnlocked, size: 82)
            Text(skin.name)
                .font(.system(size: 12))
                .lineLimit(1)
            if !skin.subText.isEmpty {
                Text(skin.subText)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 加载

    private func load(force: Bool) async {
        if !force && (!levels.isEmpty || !skins.isEmpty) {
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let data = try await QQMusicClient.shared.fetchMedalDetail(encUin: model.encUin, medalId: medalId)
            levels = QQMusicParsers.medalLevels(from: data)
            fan = QQMusicParsers.fanOverview(from: data)
            let dataScheme = data.string("Scheme")
            shareLink = scheme.isEmpty ? dataScheme : scheme
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        if enableSkins {
            skinsLoading = true
            if let result = try? await QQMusicClient.shared.fetchAllSkins(
                medalId: medalId,
                encUin: model.encUin
            ) {
                skins = result.skins
            }
            skinsLoading = false
        }
    }
}
