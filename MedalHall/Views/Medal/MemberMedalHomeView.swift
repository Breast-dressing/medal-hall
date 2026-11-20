import SwiftUI

/// 成员详情页（对应原 Web 版 MedalApp.renderHome）。
struct MemberMedalHomeView: View {
    let model: MemberMedalModel
    @Binding var path: [MedalRoute]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isInitialLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if let failure = model.failureMessage, model.page == nil {
                    ErrorStateView(message: failure) {
                        Task { await reload() }
                    }
                } else {
                    RingHeroView(items: memberRings)
                    BarChartView(title: "近 7 天荣誉", values: model.weeklyValues)
                    profile
                    stats
                    honorSection
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("成员详情")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .onAppear { model.reloadHonorRecords() }
    }

    // MARK: - 环

    private var memberRings: [RingItem] {
        [
            RingItem(label: "本周荣誉值", color: Theme.green, text: "--", percent: 0),
            RingItem(label: "付费荣誉值", color: Theme.red, text: "--", percent: 0),
            RingItem(label: "乐迷值", color: Theme.blue, text: model.fanText, percent: model.fan?.progress ?? 0)
        ]
    }

    // MARK: - 资料

    private var profile: some View {
        HStack(spacing: 12) {
            RemoteAvatar(url: model.member.pic, size: 60)
            VStack(alignment: .leading, spacing: 6) {
                Text(model.member.displayName)
                    .font(.system(size: 24, weight: .bold))
                HStack(spacing: 6) {
                    if !model.familyName.isEmpty {
                        Text(model.familyName)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    if !model.member.medalText.isEmpty {
                        TagPill(text: model.member.medalText)
                    }
                    if !model.member.fanBadge.isEmpty {
                        TagPill(
                            text: model.member.fanBadge,
                            color: Theme.orange,
                            background: Theme.orange.opacity(0.12)
                        )
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 四项统计

    private var stats: some View {
        StatsRowView(items: [
            StatItem(
                value: model.weekRankText,
                label: "周榜排名",
                showsArrow: model.rankScheme != nil,
                action: rankAction(tab: model.weekTabName)
            ),
            StatItem(
                value: model.monthRankText,
                label: "月榜排名",
                showsArrow: model.rankScheme != nil,
                action: rankAction(tab: model.monthTabName)
            ),
            StatItem(
                value: model.skinCountText,
                label: "勋章皮肤",
                showsArrow: model.skinMedal != nil,
                action: skinAction()
            ),
            StatItem(
                value: model.desc,
                label: "已获得奖章",
                showsArrow: true,
                action: { path.append(.medalsList) }
            )
        ])
        .padding(.horizontal, 4)
    }

    private func rankAction(tab: String) -> (() -> Void)? {
        guard let scheme = model.rankScheme else { return nil }
        return {
            path.append(.rank(
                scheme: scheme,
                title: "\(model.artistDisplayName)·\(tab)",
                tabName: tab
            ))
        }
    }

    private func skinAction() -> (() -> Void)? {
        guard let target = model.skinMedal else { return nil }
        return {
            path.append(.medal(
                medalId: target.medalId,
                medalName: target.name,
                scheme: target.scheme,
                enableSkins: true
            ))
        }
    }

    // MARK: - 荣誉记录

    private var honorSection: some View {
        let groups = HonorAggregator.groups(from: model.honorRecords)
        let week = HonorAggregator.weekGroups(groups)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("荣誉值记录")
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("最近 7 天 · 按日期折叠")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if !groups.isEmpty {
                    Button("查看全部") {
                        path.append(.honorRecords(memberName: model.member.title))
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
            }

            if week.isEmpty {
                EmptyStateCard(text: groups.isEmpty ? "暂无荣誉值记录" : "最近一周暂无记录")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.element.id) { pair in
                        NavigationLink(value: MedalRoute.honorDay(
                            memberName: model.member.title,
                            dateKey: pair.element.dateKey
                        )) {
                            HonorDayRowView(group: pair.element)
                        }
                        .buttonStyle(.plain)

                        if pair.offset < week.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - 刷新

    private func reload() async {
        model.reset()
        await model.load(url: QQMusicClient.medalURL(forItemID: model.member.itemId))
    }
}
