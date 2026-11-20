import SwiftUI

/// 设置页：多家族链接（可排序、可删除）+ 当前归属成员（原版 settingsModal）。
struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var newFamilyURL = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var tip = ""
    @State private var members: [Member] = []
    @State private var selectedItemID: String?
    @State private var isLoadingMembers = false

    var body: some View {
        NavigationStack {
            Form {
                familySection
                memberSection
                Section {
                    Button("关闭") { dismiss() }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { EditButton() }
            .task { await loadState() }
            .alert("提示", isPresented: errorBinding) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 家族

    private var familySection: some View {
        Section {
            ForEach(appModel.families) { family in
                HStack(spacing: 10) {
                    RemoteAvatar(url: family.avatar, size: 36, placeholderSystemImage: "person.3.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(family.displayName)
                            .font(.system(size: 15))
                        Text(family.id)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let index = appModel.families.firstIndex(where: { $0.id == family.id }) {
                        Circle()
                            .fill(Theme.ringColors[index % Theme.ringColors.count])
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .onDelete(perform: deleteFamilies)
            .onMove(perform: moveFamilies)

            VStack(alignment: .leading, spacing: 8) {
                TextField("https://i2.y.qq.com/?family_id=...", text: $newFamilyURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 14))

                Button {
                    Task { await addFamily() }
                } label: {
                    Text(isAdding ? "解析中…" : "添加家族")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.blue)
                .disabled(isAdding || newFamilyURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !tip.isEmpty {
                    Text(tip)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("家族链接")
        } footer: {
            Text("拖动左侧手柄可调整顺序，左滑可删除。")
        }
    }

    // MARK: - 当前成员

    private var memberSection: some View {
        Section {
            if isLoadingMembers {
                HStack {
                    ProgressView()
                    Text("正在获取成员…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            } else if members.isEmpty {
                Text("先添加家族，再选择成员")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Picker("成员", selection: $selectedItemID) {
                    Text("未选择").tag(String?.none)
                    ForEach(members) { member in
                        Text(member.displayName).tag(Optional(member.itemId))
                    }
                }
            }

            Button {
                saveMember()
            } label: {
                Text("保存成员并自动解析")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.blue)
            .disabled(selectedItemID == nil)
        } header: {
            Text("当前归属成员")
        }
    }

    // MARK: - 操作

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func loadState() async {
        selectedItemID = appModel.selectedMember?.itemId
        await loadMembers()
    }

    private func loadMembers() async {
        guard !appModel.families.isEmpty else {
            members = []
            return
        }
        isLoadingMembers = true
        defer { isLoadingMembers = false }
        members = await appModel.allMembers()
    }

    private func deleteFamilies(_ offsets: IndexSet) {
        appModel.removeFamilies(at: offsets)
        Task { await loadMembers() }
    }

    private func moveFamilies(_ source: IndexSet, _ destination: Int) {
        appModel.moveFamilies(from: source, to: destination)
    }

    private func addFamily() async {
        let url = newFamilyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        isAdding = true
        tip = ""
        defer { isAdding = false }
        do {
            let family = try await appModel.addFamily(urlText: url)
            newFamilyURL = ""
            tip = "已添加：\(family.displayName)"
            await loadMembers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveMember() {
        guard let itemID = selectedItemID else { return }
        appModel.select(itemID: itemID)
        dismiss()
    }
}
