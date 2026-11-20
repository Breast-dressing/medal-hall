import SwiftUI
import UniformTypeIdentifiers

/// 家族详情：三环、近 7 天总荣誉、资料卡、四项统计、不达标成员；右上角可导入 HAR。
struct FamilyDetailView: View {
    @Environment(AppModel.self) private var appModel
    let familyID: String

    @State private var model: FamilyDetailModel?
    @State private var showImporter = false
    @State private var pendingImport: HARImportResult?
    @State private var alertText: String?
    @State private var memberListPresented = false
    @State private var coverMember: Member?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(model?.title ?? "家族")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task {
            if model == nil, let family = appModel.families.first(where: { $0.id == familyID }) {
                let created = FamilyDetailModel(family: family, appModel: appModel)
                model = created
                await created.load()
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: harContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(item: $pendingImport) { parsed in
            HARPreviewSheet(result: parsed) {
                let saved = Persistence.addHonorRecords(parsed.records)
                alertText = "已导入 \(saved.records) 条 · \(saved.members) 位成员"
                model?.refreshHonor()
            }
        }
        .alert("提示", isPresented: alertBinding) {
            Button("好", role: .cancel) { alertText = nil }
        } message: {
            Text(alertText ?? "")
        }
        .memberMedalCover($coverMember)
    }

    // MARK: - 内容

    private func content(_ model: FamilyDetailModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isInitialLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if let failure = model.failureMessage, model.members.isEmpty {
                    ErrorStateView(message: failure) {
                        Task { await model.reload() }
                    }
                } else {
                    hero(model)
                    unqualifiedSection(model)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .refreshable { await model.reload() }
        .navigationDestination(isPresented: $memberListPresented) {
            MemberListView(members: model.members)
        }
    }

    private func hero(_ model: FamilyDetailModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RingHeroView(items: familyRingItems)

            BarChartView(title: "近 7 天总荣誉", values: model.weeklyValues)
                .padding(.top, 12)

            HStack(spacing: 12) {
                RemoteAvatar(url: model.family.avatar, size: 64, placeholderSystemImage: "person.3.fill")
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.family.displayName)
                        .font(.system(size: 26, weight: .bold))
                    Text(model.family.sign.isEmpty ? "暂无签名" : model.family.sign)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.top, 18)
            .padding(.horizontal, 4)

            StatsRowView(items: familyStats(model))
                .padding(.horizontal, 4)
                .padding(.top, 16)
        }
    }

    private var familyRingItems: [RingItem] {
        [
            RingItem(label: "本周总荣誉", color: Theme.red, text: "--", percent: 0),
            RingItem(label: "上周总荣誉", color: Theme.green, text: "--", percent: 0),
            RingItem(label: "付费人数", color: Theme.blue, text: "--", percent: 0)
        ]
    }

    private func familyStats(_ model: FamilyDetailModel) -> [StatItem] {
        [
            StatItem(value: model.family.honor.isEmpty ? "--" : model.family.honor, label: "总荣誉值"),
            StatItem(value: model.family.rank, label: "周排名"),
            StatItem(value: model.family.pkWins, label: "PK胜场"),
            StatItem(value: model.memberCountText, label: "成员数", showsArrow: true, action: {
                memberListPresented = true
            })
        ]
    }

    private func unqualifiedSection(_ model: FamilyDetailModel) -> some View {
        let list = model.unqualifiedMembers
        let shown = model.unqualifiedExpanded ? list : Array(list.prefix(3))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("不达标成员")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(list.count) 人")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
            }

            VStack(spacing: 0) {
                if list.isEmpty {
                    Text("暂无数据（不达标口径待接入）")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                } else {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { pair in
                        Button {
                            coverMember = pair.element
                        } label: {
                            unqualifiedRow(pair.element)
                        }
                        .buttonStyle(.plain)

                        if pair.offset < shown.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }

                    if list.count > 3 {
                        Divider().padding(.leading, 60)
                        Button {
                            model.toggleUnqualified()
                        } label: {
                            HStack {
                                Text(model.unqualifiedExpanded ? "收起" : "展开更多 \(list.count - 3) 人")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Image(systemName: model.unqualifiedExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Theme.secondaryText)
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .cardStyle()
        }
    }

    private func unqualifiedRow(_ member: Member) -> some View {
        HStack(spacing: 12) {
            RemoteAvatar(url: member.pic, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    if !member.medalText.isEmpty {
                        TagPill(text: member.medalText)
                    }
                }
                Text("荣誉 \(member.honor.isEmpty ? "--" : member.honor) · ID \(member.itemId)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text("未达标")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.red.opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showImporter = true
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .accessibilityLabel("导入 HAR 荣誉记录")

            ShareLink(item: model?.shareText ?? "勋章馆") {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享家族")
        }
    }

    // MARK: - HAR 导入

    private var harContentTypes: [UTType] {
        var types: [UTType] = [.json]
        if let har = UTType(filenameExtension: "har") {
            types.insert(har, at: 0)
        }
        return types
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertText != nil },
            set: { if !$0 { alertText = nil } }
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                let parsed = try HonorImporter.parse(
                    data: data,
                    fileName: url.lastPathComponent,
                    memberLookup: { Persistence.member(named: $0) }
                )
                guard parsed.recordCount > 0 else {
                    alertText = "未解析到可写入的荣誉记录"
                    return
                }
                pendingImport = parsed
            } catch {
                alertText = error.localizedDescription
            }
        case let .failure(error):
            alertText = error.localizedDescription
        }
    }
}
