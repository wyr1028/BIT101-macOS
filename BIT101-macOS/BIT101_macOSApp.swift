//
//  BIT101_macOSApp.swift
//
import SwiftUI

@main
struct BIT101_macOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var net = NetworkManager.shared
    @AppStorage("colorScheme") private var scheme = "system"

    func applyTheme() {
        switch scheme {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
        default:      NSApp.appearance = nil
        }
    }

    /// 通过深链通知切换页面（Cmd+1..5 等触发）
    private func nav(_ page: String) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openNavItem, object: nil, userInfo: ["item": page])
    }

    private func toggleMini() {
        (NSApp.delegate as? AppDelegate)?.toggleMiniSchedule()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                LiquidGlassBackground()
                Group {
                    if net.isLoggedIn {
                        ContentView().frame(minWidth: 480, minHeight: 560)
                    } else {
                        // 登录窗口：固定小尺寸
                        LoginGateView()
                            .frame(width: 400, height: 540)
                    }
                }
            }
            .onAppear { applyTheme() }
            .onChange(of: scheme) { _, _ in applyTheme() }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 780)
        .commands {
            // macOS 独占：Cmd+1..5 直达五大模块
            CommandMenu("导航") {
                Button("日程") { nav("课表") }.keyboardShortcut("1")
                Button("地图") { nav("校园地图") }.keyboardShortcut("2")
                Button("话廊") { nav("话题") }.keyboardShortcut("3")
                Button("学业") { nav("成绩") }.keyboardShortcut("4")
                Button("我的") { nav("个人") }.keyboardShortcut("5")
            }
            CommandMenu("窗口") {
                Button("浮动课表") { toggleMini() }
                    .keyboardShortcut("m", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}

struct LoginGateView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var sid = ""; @State private var pwd = ""
    @State private var loading = false; @State private var err: String?

    var body: some View {
        VStack(spacing: Sp.l) {
            ModuleIcon(icon: "books.vertical.fill", color: .bitOrange, size: 52)

            VStack(spacing: 2) {
                Text("BIT101").font(Typo.header(.title))
                Text("北理助手").font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Sp.s) {
                Text("学号").font(Typo.caption()).foregroundStyle(.secondary)
                GlassTextField(placeholder: "112020xxxx", text: $sid).frame(width: 230)
                Text("密码").font(Typo.caption()).foregroundStyle(.secondary)
                GlassTextField(placeholder: "统一身份认证密码", text: $pwd, isSecure: true) {
                    Task { await login() }
                }.frame(width: 230)
                if let err {
                    Text(err).font(.caption).foregroundColor(.red).frame(width: 230)
                }
            }

            Button { Task { await login() } } label: {
                Text(loading ? "登录中..." : "登 录").fontWeight(.medium).frame(width: 230, height: 32)
            }
            .buttonStyle(.glass).disabled(sid.isEmpty || pwd.isEmpty || loading)
        }
        .padding(Sp.xl)
        .frame(width: 330)
        .glassSurface(Radius.xl)
        .onAppear { if sid.isEmpty { sid = net.studentID } }
    }

    func login() async {
        err = nil; loading = true
        do {
            try await withThrowingTaskGroup(of: Void.self) { g in
                g.addTask { try await NetworkManager.shared.login(sid: sid, password: pwd) }
                g.addTask { try await Task.sleep(nanoseconds: 15_000_000_000); throw URLError(.timedOut) }
                try await g.next(); g.cancelAll()
            }
            await MainActor.run { loading = false }
        } catch {
            await MainActor.run { loading = false; err = (error as? URLError)?.code == .timedOut ? "登录超时" : error.localizedDescription }
        }
    }
}
