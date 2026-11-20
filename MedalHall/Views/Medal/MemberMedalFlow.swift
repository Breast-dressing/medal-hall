import SwiftUI

/// 成员勋章馆：独立的全屏 NavigationStack（对应原 Web 版的 medalPage 覆盖层）。
struct MemberMedalFlow: View {
    let member: Member

    @State private var model: MemberMedalModel
    @State private var path: [MedalRoute]

    init(member: Member, model: MemberMedalModel? = nil, initialRoute: MedalRoute? = nil) {
        self.member = member
        _model = State(initialValue: model ?? MemberMedalModel(member: member))
        if let initialRoute {
            _path = State(initialValue: [initialRoute])
        } else {
            _path = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            MemberMedalHomeView(model: model, path: $path)
                .navigationDestination(for: MedalRoute.self) { route in
                    destination(for: route)
                }
        }
        .environment(model)
        .task {
            if model.needsLoad {
                await model.load(url: QQMusicClient.medalURL(forItemID: member.itemId))
            }
        }
    }

    @ViewBuilder
    private func destination(for route: MedalRoute) -> some View {
        switch route {
        case .medalsList:
            MedalsListView()
        case let .module(moduleId, moduleName, tabName):
            ModuleListView(moduleId: moduleId, moduleName: moduleName, tabName: tabName)
        case let .rank(scheme, title, tabName):
            RankView(scheme: scheme, title: title, preferredTab: tabName)
        case let .medal(medalId, medalName, scheme, enableSkins):
            MedalDetailView(
                medalId: medalId,
                medalName: medalName,
                scheme: scheme,
                enableSkins: enableSkins
            )
        case let .honorRecords(memberName):
            HonorRecordsView(memberName: memberName)
        case let .honorDay(memberName, dateKey):
            HonorDayView(memberName: memberName, dateKey: dateKey)
        }
    }
}
