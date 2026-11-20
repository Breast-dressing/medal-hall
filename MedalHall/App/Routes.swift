import SwiftUI

/// 路由定义。首页栈、家族栈、勋章栈各自使用不同的枚举。
enum HomeRoute: Hashable {
    case family(String)
    case feature(FeatureKind)
}

enum MedalRoute: Hashable {
    case medalsList
    case module(moduleId: Int, moduleName: String, tabName: String)
    case rank(scheme: String, title: String, tabName: String)
    case medal(medalId: String, medalName: String, scheme: String, enableSkins: Bool)
    case honorRecords(memberName: String)
    case honorDay(memberName: String, dateKey: String)
}

/// 打开成员勋章馆（全屏）的请求。
struct MedalCoverRequest: Identifiable {
    let id = UUID()
    var member: Member
    var model: MemberMedalModel?
    var initialRoute: MedalRoute?
}

extension View {
    /// 点成员 → 全屏打开勋章馆。
    func memberMedalCover(_ member: Binding<Member?>) -> some View {
        modifier(MemberMedalCoverModifier(member: member))
    }
}

private struct MemberMedalCoverModifier: ViewModifier {
    @Binding var member: Member?

    func body(content: Content) -> some View {
        content.fullScreenCover(item: $member) { value in
            MemberMedalFlow(member: value)
        }
    }
}
