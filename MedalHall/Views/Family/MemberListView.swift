import SwiftUI

/// 家族成员列表（点击「成员数」进入）。
struct MemberListView: View {
    let members: [Member]
    @State private var coverMember: Member?

    var body: some View {
        List {
            ForEach(members) { member in
                Button {
                    coverMember = member
                } label: {
                    row(member)
                }
                .buttonStyle(.plain)
                .listRowBackground(Theme.card)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("家族成员")
        .navigationBarTitleDisplayMode(.inline)
        .memberMedalCover($coverMember)
    }

    private func row(_ member: Member) -> some View {
        HStack(spacing: 12) {
            RemoteAvatar(url: member.pic, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !member.medalText.isEmpty {
                        TagPill(text: member.medalText)
                    }
                    if !member.fanBadge.isEmpty {
                        TagPill(text: member.fanBadge, color: Theme.orange, background: Theme.orange.opacity(0.12))
                    }
                }
                Text("荣誉 \(member.honor.isEmpty ? "--" : member.honor) · ID \(member.itemId)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
