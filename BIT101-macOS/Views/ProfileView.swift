//
//  ProfileView.swift
//
import SwiftUI

struct ProfileView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var nick = ""; @State private var motto = ""
    @State private var avatarURL: String?; @State private var ident = ""
    @State private var avatar: NSImage?; @State private var loaded = false
    @State private var showEditor = false; @State private var editNick = ""
    @State private var editMotto = ""; @State private var saving = false
    @AppStorage("colorScheme") private var scheme = "system"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 头像卡片
                VStack(spacing: 10) {
                    avatarView
                    VStack(spacing: 2) {
                        Text(nick.isEmpty ? "BIT101用户" : nick).font(.title3.bold())
                        Text(net.studentID).font(.caption).foregroundStyle(.secondary).monospaced()
                    }
                    if !motto.isEmpty {
                        Text(motto).font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                    Text(ident.isEmpty ? "普通用户" : ident)
                        .font(.caption2.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 5)
                        .background(Capsule().fill(.blue.opacity(0.1))).foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

                // 编辑面板
                if showEditor {
                    VStack(spacing: 10) {
                        TextField("昵称", text: $editNick).textFieldStyle(.roundedBorder)
                        TextField("签名", text: $editMotto).textFieldStyle(.roundedBorder)
                        HStack {
                            Button("取消") { showEditor = false }.buttonStyle(.plain)
                            Button { Task { await save() } } label: {
                                saving ? AnyView(ProgressView().controlSize(.small)) : AnyView(Text("保存"))
                            }.buttonStyle(.borderedProminent).disabled(saving)
                        }
                    }
                    .padding(16).frame(width: 260)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity.combined(with: .scale(0.95)))
                }

                // 设置列表
                VStack(spacing: 0) {
                    SettingsBtn(icon: "pencil", title: "编辑个人信息") {
                        editNick = nick; editMotto = motto
                        withAnimation(.easeInOut(duration: 0.2)) { showEditor = true }
                    }
                    Divider().padding(.leading, 40)

                    // 外观-主题
                    HStack {
                        Image(systemName: "circle.lefthalf.filled").frame(width: 22).foregroundColor(.blue)
                        Text("外观").font(.body)
                        Spacer()
                        Picker("", selection: $scheme) {
                            Text("浅色").tag("light"); Text("深色").tag("dark"); Text("系统").tag("system")
                        }.pickerStyle(.segmented).frame(width: 170)
                    }
                    .padding(.vertical, 12).padding(.horizontal, 14)

                    Divider().padding(.leading, 40)
                    SettingsBtn(icon: "person.2", title: "关注 / 粉丝") {}
                    Divider().padding(.leading, 40)
                    SettingsBtn(icon: "info.circle", title: "关于 BIT101") {}
                    Divider().padding(.leading, 40)

                    Button {
                        net.logout(); nick = ""; motto = ""; ident = ""; avatar = nil
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right").frame(width: 22)
                            Text("退出登录").foregroundColor(.red); Spacer()
                        }
                        .padding(.vertical, 13).padding(.horizontal, 14)
                    }.buttonStyle(.plain)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(20)
        }
        .navigationTitle("个人")
        .task { if !loaded { await load() } }
        .animation(.easeInOut(duration: 0.2), value: showEditor)
    }

    var avatarView: some View {
        ZStack {
            Circle().fill(.quaternary).frame(width: 80, height: 80)
            if let a = avatar {
                Image(nsImage: a).resizable().scaledToFill().frame(width: 80, height: 80).clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().frame(width: 56, height: 56).foregroundStyle(.secondary)
            }
        }
    }

    func load() async {
        loaded = true
        do {
            let u = try await net.fetchUserInfo()
            await MainActor.run { nick = u.nickname ?? ""; motto = u.motto ?? ""; avatarURL = u.avatarURL; ident = u.identityName ?? "" }
            if let urlStr = u.avatarURL, let url = URL(string: urlStr) { await loadAv(url) }
        } catch { print("info:\(error)") }
    }
    func loadAv(_ url: URL) async {
        do { let (d,_) = try await URLSession.shared.data(from: url); await MainActor.run { avatar = NSImage(data: d) } }
        catch { print("av:\(error)") }
    }
    func save() async {
        saving = true
        do { try await net.updateUserInfo(nickname: editNick, motto: editMotto)
            await MainActor.run { nick = editNick; motto = editMotto; showEditor = false; saving = false }
        } catch { await MainActor.run { saving = false } }
    }
}

struct SettingsBtn: View {
    let icon: String; let title: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).frame(width: 22).foregroundColor(.blue)
                Text(title).font(.body); Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 13).padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}
