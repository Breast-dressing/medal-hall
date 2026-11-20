import SwiftUI
import UIKit

/// 皮肤详情底部弹层（对应原 Web 版 skinModal）。
struct SkinDetailSheet: View {
    let skin: Skin
    let memberItemID: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    MedalThumb(url: skin.pic, size: 220, cornerRadius: 20)

                    Text(skin.name)
                        .font(.system(size: 20, weight: .bold))
                    Text(skin.id)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)

                    VStack(spacing: 0) {
                        infoRow("皮肤序号", "\(skin.seq)")
                        Divider()
                        infoRow("所属分类ID", skin.categId.isEmpty ? "-" : skin.categId)
                        Divider()
                        infoRow(
                            "解锁状态",
                            skin.stateText,
                            color: skin.isUnlocked ? Theme.green : Theme.secondaryText
                        )
                        Divider()
                        infoRow("限定编号", skin.seqNo.isEmpty ? "无" : skin.seqNo)
                        Divider()
                        infoRow("获取日期", skin.unlockedDate.isEmpty ? "-" : skin.unlockedDate)
                        Divider()
                        infoRow("全服解锁人数", skin.userCount > 0 ? "\(skin.userCount) 人" : "-")
                        if !skin.isUnlocked && !skin.unlockTask.isEmpty {
                            Divider()
                            infoRow("解锁条件", skin.unlockTask)
                        }
                    }
                    .padding(14)
                    .cardStyle(cornerRadius: 16)

                    Button {
                        copyLink()
                    } label: {
                        Label(
                            copied ? "链接已复制" : "复制当前皮肤链接",
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(copied ? Theme.green : Theme.red)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("皮肤详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 9)
    }

    private func copyLink() {
        let base = "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3/skin_detail.html"
        let encodedSkin = skin.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? skin.id
        let encodedUin = memberItemID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? memberItemID
        let link = "\(base)?_hidehd=1&_fontscale=1&skin_id=\(encodedSkin)&enc_uin=\(encodedUin)"
        UIPasteboard.general.string = link
        copied = true
    }
}
