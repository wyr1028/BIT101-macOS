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
    @AppStorage("notifyEnabled") private var notifyEnabled = true
    @State private var showFollow = false
    @State private var showAbout = false

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
                .glassSurface(18)

                // 编辑面板
                if showEditor {
                    VStack(spacing: 10) {
                        GlassTextField(placeholder: "昵称", text: $editNick)
                        GlassTextField(placeholder: "签名", text: $editMotto)
                        HStack {
                            Button("取消") { showEditor = false }.buttonStyle(.plain)
                            Button { Task { await save() } } label: {
                                saving ? AnyView(ProgressView().controlSize(.small)) : AnyView(Text("保存"))
                            }.buttonStyle(.glass).disabled(saving)
                        }
                    }
                    .padding(16).frame(width: 260)
                    .glassSurface(12)
                    .transition(.opacity.combined(with: .scale(0.95)))
                }

                // 设置列表
                VStack(spacing: 0) {
                    SettingsBtn(icon: "pencil", title: "编辑个人信息") {
                        editNick = nick; editMotto = motto
                        withAnimation(.easeInOut(duration: 0.2)) { showEditor = true }
                    }
                    GlassDivider().padding(.leading, 40)

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

                    GlassDivider().padding(.leading, 40)
                    HStack {
                        Image(systemName: "bell.fill").frame(width: 22).foregroundColor(.orange)
                        Text("课程提醒与静音").font(.body)
                        Spacer()
                        Toggle("", isOn: $notifyEnabled).toggleStyle(.switch).controlSize(.small)
                    }
                    .padding(.vertical, 9).padding(.horizontal, 14)
                    GlassDivider().padding(.leading, 40)
                    SettingsBtn(icon: "person.2", title: "关注 / 粉丝") { showFollow = true }
                    GlassDivider().padding(.leading, 40)
                    SettingsBtn(icon: "info.circle", title: "关于 BIT101") { showAbout = true }
                    GlassDivider().padding(.leading, 40)
                    SettingsBtn(icon: "gearshape", title: "设置…") {
                        if #available(macOS 14.0, *) {
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        } else {
                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                        }
                    }
                    GlassDivider().padding(.leading, 40)

                    Button {
                        net.logout(); nick = ""; motto = ""; ident = ""; avatar = nil
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right").frame(width: 22)
                            Text("退出登录").foregroundColor(.red); Spacer()
                        }
                        .padding(.vertical, 13).padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .wideHitArea()
                }
                .glassSurface(16)
            }
            .padding(20)
        }
        .navigationTitle("个人")
        .task { if !loaded { await load() } }
        .animation(.easeInOut(duration: 0.2), value: showEditor)
        .sheet(isPresented: $showFollow) { FollowListSheet() }
        .sheet(isPresented: $showAbout) { AboutSheet() }
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
        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
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
        .frame(maxWidth: .infinity, alignment: .leading)   // 占满整行
        .contentShape(Rectangle())
        .wideHitArea()
    }
}

// MARK: 关注 / 粉丝

struct FollowListSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var net = NetworkManager.shared
    @State private var tab = 0
    @State private var users: [UserAPI] = []
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("关注").tag(0)
                Text("粉丝").tag(1)
            }
            .pickerStyle(.segmented).frame(width: 200).padding(.vertical, 8)
            .onChange(of: tab) { _, _ in Task { await load() } }

            GlassDivider()

            if loading { LoadingStateView() }
            else if users.isEmpty {
                EmptyStateView(title: "暂无数据", icon: "person.2")
            } else {
                ScrollView {
                    LazyVStack(spacing: Sp.m) {
                        ForEach(users) { u in
                            GlassListItem {
                                HStack(spacing: 10) {
                                    GlassAvatar(name: u.nickname ?? "", size: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(u.nickname ?? "用户").font(.callout.weight(.medium))
                                        if let m = u.motto, !m.isEmpty { Text(m).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }.padding(Sp.m)
                }
            }
        }
        .frame(width: 380, height: 420)
        .glassSheetBackground()
        .task { await load() }
    }

    func load() async {
        loading = true
        do {
            let list = tab == 0 ? try await net.fetchFollowings() : try await net.fetchFollowers()
            await MainActor.run { users = list; loading = false }
        } catch { await MainActor.run { loading = false } }
    }
}

// MARK: 关于

struct AboutSheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 12) {
            ModuleIcon(icon: "books.vertical.fill", color: .bitBlue, size: 52)
            Text("BIT101").font(Typo.header(.title))
            Text("北京理工大学校园助手 macOS 客户端")
            Text("基于 BIT101 开放 API（bit101.flwfdd.xyz）构建\n课表 · 成绩 · 校园地图 · 社区内容 · 教务数据")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("关闭") { dismiss() }.buttonStyle(.glass)
        }
        .padding(30).frame(width: 380, height: 300)
        .glassSheetBackground()
    }
}

// UserAPI 已有存储属性 id，直接用它满足 Identifiable
extension UserAPI: Identifiable {}
