//
//  ProfileView.swift
//
import SwiftUI

struct ProfileView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var sid = ""; @State private var pwd = ""
    @State private var loading = false; @State private var err: String?
    @State private var nick = ""; @State private var motto = ""
    @State private var avatarMid = ""; @State private var ident = ""
    @State private var avatar: NSImage?; @State private var about = false
    @State private var fn: Int64 = 0; @State private var frn: Int64 = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if net.isLoggedIn { infoCard; statsCard; settingsCard }
                else { loginCard }
            }.padding(24)
        }
        .sheet(isPresented: $about) { AboutSheet() }
        .task { if net.isLoggedIn { await info() } }
    }

    var infoCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(.regularMaterial).frame(width: 80, height: 80).shadow(color: .black.opacity(0.08), radius: 8)
                if let a = avatar {
                    Image(nsImage: a).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill").resizable().frame(width: 60, height: 60).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 4) {
                Text(nick.isEmpty ? "BIT101用户" : nick).font(.title2.bold())
                Text(net.studentID).font(.subheadline).foregroundStyle(.secondary).monospaced()
            }
            if !motto.isEmpty { Text(motto).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            Text(ident.isEmpty ? "普通用户" : ident)
                .font(.caption2.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15))).foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    var statsCard: some View {
        HStack(spacing: 0) {
            statItem("\(fn)", "关注"); Divider().frame(height: 30)
            statItem("\(frn)", "粉丝"); Divider().frame(height: 30)
            statItem("--", "动态")
        }.padding(.vertical, 12).frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    func statItem(_ v: String, _ l: String) -> some View {
        VStack(spacing: 4) { Text(v).font(.system(.title3, design: .rounded).bold()); Text(l).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }

    var settingsCard: some View {
        VStack(spacing: 0) {
            row("person.text.rectangle", "修改个人信息")
            Divider().padding(.leading, 40)
            row("paintbrush.fill", "切换主题") { toggleTheme() }
            Divider().padding(.leading, 40)
            row("info.circle.fill", "关于 BIT101") { about = true }
            Divider().padding(.leading, 40)
            Button {
                net.logout(); nick = ""; motto = ""; ident = ""; avatarMid = ""; avatar = nil
            } label: {
                HStack { Image(systemName: "rectangle.portrait.and.arrow.right").frame(width: 24); Text("退出登录"); Spacer() }
                    .padding(.vertical, 12).padding(.horizontal, 16).foregroundColor(.red)
            }.buttonStyle(.plain)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    func row(_ icon: String, _ title: String, action: (() -> Void)? = nil) -> some View {
        Group { if let a = action { Button(action: a) { rowContent(icon, title) } } else { rowContent(icon, title) } }
    }
    func rowContent(_ icon: String, _ title: String) -> some View {
        HStack { Image(systemName: icon).frame(width: 24).foregroundColor(.accentColor); Text(title); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
            .padding(.vertical, 12).padding(.horizontal, 16).contentShape(Rectangle())
    }

    var loginCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "graduationcap.circle.fill").resizable().frame(width: 64, height: 64).foregroundColor(.accentColor)
            Text("登录 BIT101").font(.title).fontWeight(.bold)
            Text("使用学校统一身份认证登录").font(.caption).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("学号").font(.caption).foregroundStyle(.secondary)
                    TextField("112020xxxx", text: $sid).textFieldStyle(.roundedBorder).onAppear { if sid.isEmpty { sid = net.studentID } }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("密码").font(.caption).foregroundStyle(.secondary)
                    SecureField("统一身份认证密码", text: $pwd).textFieldStyle(.roundedBorder).onSubmit(login)
                }
                if let err { Text(err).font(.caption).foregroundColor(.red) }
            }.frame(width: 280)

            Button(action: login) {
                HStack { if loading { ProgressView().controlSize(.small).padding(.trailing, 4) }; Text(loading ? "登录中..." : "登 录").fontWeight(.medium) }
                    .frame(width: 280, height: 32)
            }.buttonStyle(.borderedProminent).disabled(sid.isEmpty || pwd.isEmpty || loading)
        }
        .padding(.vertical, 40).frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    func login() {
        err = nil; loading = true
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { g in
                    g.addTask { try await NetworkManager.shared.login(sid: sid, password: pwd) }
                    g.addTask { try await Task.sleep(nanoseconds: 15_000_000_000); throw URLError(.timedOut) }
                    try await g.next(); g.cancelAll()
                }
                await MainActor.run { loading = false }; await info()
            } catch { await MainActor.run { loading = false; err = (error as? URLError)?.code == .timedOut ? "登录超时" : error.localizedDescription } }
        }
    }

    func info() async {
        do {
            let u = try await net.fetchUserInfo()
            await MainActor.run { nick = u.nickname ?? ""; motto = u.motto ?? ""; avatarMid = u.avatarMid ?? ""; ident = u.identityName ?? ""; fn = u.following_num ?? 0; frn = u.follower_num ?? 0 }
            if let m = u.avatarMid, !m.isEmpty { await loadAv(m) }
        } catch { print("info:\(error)") }
    }
    func loadAv(_ mid: String) async {
        guard let url = net.avatarURL(for: mid) else { return }
        var r = URLRequest(url: url); r.setValue(net.fakeCookie, forHTTPHeaderField: "fake-cookie")
        do { let (d, _) = try await URLSession.shared.data(for: r); await MainActor.run { avatar = NSImage(data: d) } }
        catch { print("av:\(error)") }
    }
    func toggleTheme() { NSApp.appearance = NSApp.effectiveAppearance.name == .darkAqua ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua) }
}

struct AboutSheet: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill").font(.system(size: 44)).foregroundColor(.accentColor)
            Text("BIT101").font(.largeTitle.bold()); Text("北理助手 macOS").font(.title3)
            Text("版本 1.0").font(.caption).foregroundStyle(.secondary)
        }.padding(40).frame(width: 280, height: 240)
    }
}
