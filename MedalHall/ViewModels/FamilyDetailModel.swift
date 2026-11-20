import Foundation
import Observation

/// 家族详情页状态：成员列表、近 7 天总荣誉、不达标成员、荣誉记录。
@MainActor
@Observable
final class FamilyDetailModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// 原版把「荣誉值低于 500」作为不达标的占位口径。
    static let unqualifiedThreshold: Double = 500

    let family: Family
    private(set) var members: [Member] = []
    private(set) var phase: Phase = .idle
    private(set) var honorGroups: [HonorDayGroup] = []
    var unqualifiedExpanded = false

    private let appModel: AppModel

    init(family: Family, appModel: AppModel) {
        self.family = family
        self.appModel = appModel
    }

    // MARK: - 派生状态

    var title: String { family.displayName }

    var isInitialLoading: Bool {
        members.isEmpty && (phase == .idle || phase == .loading)
    }

    var failureMessage: String? {
        if case let .failed(message) = phase { return message }
        return nil
    }

    var unqualifiedMembers: [Member] {
        members
            .filter { $0.honorValue < Self.unqualifiedThreshold }
            .sorted { $0.honorValue < $1.honorValue }
    }

    var weeklyValues: [Double] {
        appModel.weeklyHonorValues(for: members)
    }

    var weekHonorGroups: [HonorDayGroup] {
        HonorAggregator.weekGroups(honorGroups)
    }

    var artistName: String {
        members.first(where: { !$0.artistName.isEmpty })?.artistName ?? ""
    }

    var memberCountText: String {
        let value = family.members
        if !value.isEmpty && value != "0" {
            return value
        }
        return "\(members.count)"
    }

    var shareText: String {
        var lines: [String] = []
        lines.append(family.displayName)
        if !family.sign.isEmpty && family.sign != "暂无" {
            lines.append(family.sign)
        }
        var stats: [String] = []
        stats.append("总荣誉值 \(family.honor.isEmpty ? "--" : family.honor)")
        stats.append("周排名 \(family.rank)")
        stats.append("PK胜场 \(family.pkWins)")
        stats.append("成员数 \(memberCountText)")
        lines.append(stats.joined(separator: " · "))
        if !family.rawURL.isEmpty {
            lines.append(family.rawURL)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 加载

    func load() async {
        if case .loading = phase { return }
        phase = .loading

        let cached = appModel.cachedMembers(for: family.id)
        if !cached.isEmpty {
            members = cached
            phase = .loaded
            refreshHonor()
        }

        do {
            let fetched = try await appModel.members(for: family.id)
            members = fetched
            phase = .loaded
            refreshHonor()
        } catch {
            if members.isEmpty {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func reload() async {
        phase = .idle
        await load()
    }

    func refreshHonor() {
        let names = Set(members.map { $0.title })
        let records = Persistence.honorStore
            .filter { names.contains($0.name) }
            .flatMap { $0.records }
        honorGroups = HonorAggregator.groups(from: records)
    }

    func toggleUnqualified() {
        unqualifiedExpanded.toggle()
    }
}
