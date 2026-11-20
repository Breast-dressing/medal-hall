import SwiftUI

/// 「我的」首页：家族荣誉环、近 7 天荣誉、当前成员、四项统计、特色入口、家族卡片。
struct HomeView: View {
    @Environment(AppModel.self) private var appModel

    @State private var path: [HomeRoute] = []
    @State private var showSettings = false
    @State private var summary: MemberMedalModel?
    @State private var coverRequest: MedalCoverRequest?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ringSection
                    memberSection
                    familySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(Theme.background)
            .refreshable { await reloadSummary(force: true) }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case let .family(familyID):
                    FamilyDetailView(familyID: familyID)
                case let .feature(kind):
                    FeatureStatView(kind: kind)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(item: $coverRequest) { request in
            MemberMedalFlow(
                member: request.member,
                model: request.model,
                initialRoute: request.initialRoute
            )
        }
        .task(id: appModel.reloadToken) {
            await reloadSummary(force: false)
        }
    }

    // MARK: - 标题

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("我的")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().stroke(Theme.separator, lineWidth: 0.5))
            }
            .accessibilityLabel("设置")
            .padding(.bottom, 4)
        }
        .padding(.top, 14)
    }

    // MARK: - 家族荣誉环

    @ViewBuilder
    private var ringSection: some View {
        if appModel.families.isEmpty {
            Button {
                showSettings = true
            } label: {
                Text("添加家族后显示家族荣誉环")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .cardStyle()
            }
            .buttonStyle(.plain)
        } else {
            RingHeroView(items: ringItems, showsLegend: false)
                .padding(.vertical, 6)
        }
    }

    private var ringItems: [RingItem] {
        let families = Array(appModel.families.prefix(4))
        guard !families.isEmpty else { return [] }
        let added = families.map { Fmt.honorNumber($0.weekHonor) }
        let maxAdded = max(added.max() ?? 0, 1)
        return families.enumerated().map { index, family in
            let value = added[index]
            return RingItem(
                label: family.displayName,
                color: Theme.ringColors[index % Theme.ringColors.count],
                text: "+\(Fmt.groupedInt(Int(value)))荣誉值",
                percent: value > 0 ? value / maxAdded : 0
            )
        }
    }

    // MARK: - 当前成员

    @ViewBuilder
    private var memberSection: some View {
        if let member = appModel.selectedMember {
            VStack(alignment: .leading, spacing: 0) {
                BarChartView(title: "近 7 天荣誉", values: summary?.weeklyValues)
                profileRow(member: member)
                memberStats(member: member)
                Rectangle()
                    .fill(Theme.secondaryText.opacity(0.25))
                    .frame(height: 0.5)
                    .padding(.horizontal, 4)
                    .padding(.top, 14)
                extraStatsRow
            }
        } else {
            Button {
                showSettings = true
            } label: {
                emptyMemberCard
            }
            .buttonStyle(.plain)
            .accessibilityLabel("选择成员，在设置中选择当前归属成员")
        }
    }

    private var emptyMemberCard: some View {
        HStack(spacing: 12) {
            Text("+")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Theme.blue)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.blue.opacity(0.08)))

            VStack(alignment: .leading, spacing: 3) {
                Text("选择成员")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("在设置中选择当前归属成员")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(16)
        .cardStyle()
    }

    private func profileRow(member: Member) -> some View {
        Button {
            openMemberHome(member: member)
        } label: {
            HStack(spacing: 12) {
                RemoteAvatar(url: member.pic, size: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(member.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        if let familyName = familyName(for: member), !familyName.isEmpty {
                            Text(familyName)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        if !member.medalText.isEmpty {
                            TagPill(text: member.medalText)
                        }
                        if !member.fanBadge.isEmpty {
                            TagPill(text: member.fanBadge, color: Theme.orange, background: Theme.orange.opacity(0.12))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.top, 16)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(member.displayName) 的勋章馆")
    }

    private func memberStats(member: Member) -> some View {
        let rankScheme = summary?.rankScheme
        let skinTarget = summary?.skinMedal
        let weekTab = summary?.weekTabName ?? "周榜"
        let monthTab = summary?.monthTabName ?? "月榜"
        let artist = summary?.artistDisplayName ?? member.displayName

        var weekAction: (() -> Void)?
        if rankScheme != nil {
            weekAction = { self.openRank(member: member, tabName: weekTab, artist: artist) }
        }
        var monthAction: (() -> Void)?
        if rankScheme != nil {
            monthAction = { self.openRank(member: member, tabName: monthTab, artist: artist) }
        }
        var skinAction: (() -> Void)?
        if skinTarget != nil {
            skinAction = { self.openSkin(member: member) }
        }

        let weekItem = StatItem(
            value: summary?.weekRankText ?? "--",
            label: "周榜排名",
            showsArrow: rankScheme != nil,
            action: weekAction
        )
        let monthItem = StatItem(
            value: summary?.monthRankText ?? "--",
            label: "月榜排名",
            showsArrow: rankScheme != nil,
            action: monthAction
        )
        let skinItem = StatItem(
            value: summary?.skinCountText ?? "--",
            label: "勋章皮肤",
            showsArrow: skinTarget != nil,
            action: skinAction
        )
        let medalItem = StatItem(
            value: summary?.desc ?? "--",
            label: "已获得奖章",
            showsArrow: true,
            action: { openMedalsList(member: member) }
        )

        return StatsRowView(items: [weekItem, monthItem, skinItem, medalItem])
            .padding(.horizontal, 4)
            .padding(.top, 16)
    }

    private var extraStatsRow: some View {
        StatsRowView(items: [
            StatItem(value: "--", label: "巅峰制作人", showsArrow: true, action: { path.append(.feature(.producer)) }),
            StatItem(value: "--", label: "乐迷灯牌", showsArrow: true, action: { path.append(.feature(.fan)) }),
            StatItem(value: "--", label: "星光发电站", showsArrow: true, action: { path.append(.feature(.station)) })
        ])
        .padding(.horizontal, 4)
        .padding(.top, 12)
    }

    // MARK: - 家族卡片

    @ViewBuilder
    private var familySection: some View {
        if !appModel.families.isEmpty {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(Array(appModel.families.enumerated()), id: \.element.id) { pair in
                    Button {
                        path.append(.family(pair.element.id))
                    } label: {
                        FamilyCardView(
                            family: pair.element,
                            color: Theme.ringColors[pair.offset % Theme.ringColors.count]
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开\(pair.element.displayName)")
                }
            }
        }
    }

    // MARK: - 跳转与加载

    private func familyName(for member: Member) -> String? {
        guard let familyID = member.familyId else { return nil }
        return appModel.families.first(where: { $0.id == familyID })?.displayName
    }

    private func openMemberHome(member: Member) {
        coverRequest = MedalCoverRequest(member: member, model: summary, initialRoute: nil)
    }

    private func openMedalsList(member: Member) {
        coverRequest = MedalCoverRequest(member: member, model: summary, initialRoute: .medalsList)
    }

    private func openSkin(member: Member) {
        guard let target = summary?.skinMedal else { return }
        coverRequest = MedalCoverRequest(
            member: member,
            model: summary,
            initialRoute: .medal(
                medalId: target.medalId,
                medalName: target.name,
                scheme: target.scheme,
                enableSkins: true
            )
        )
    }

    private func openRank(member: Member, tabName: String, artist: String) {
        guard let summary, let scheme = summary.rankScheme else { return }
        coverRequest = MedalCoverRequest(
            member: member,
            model: summary,
            initialRoute: .rank(scheme: scheme, title: "\(artist)·\(tabName)", tabName: tabName)
        )
    }

    private func reloadSummary(force: Bool) async {
        guard let member = appModel.selectedMember else {
            summary = nil
            return
        }

        let model: MemberMedalModel
        if let existing = summary, existing.member.itemId == member.itemId {
            model = existing
        } else {
            model = MemberMedalModel(member: member)
            summary = model
        }

        if force {
            model.reset()
        }
        model.reloadHonorRecords()

        if model.needsLoad {
            let url = appModel.medalURL ?? QQMusicClient.medalURL(forItemID: member.itemId)
            await model.load(url: url)
        }
    }
}
