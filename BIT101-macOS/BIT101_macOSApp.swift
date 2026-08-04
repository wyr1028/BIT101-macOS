//
//  BIT101_macOSApp.swift
//
import SwiftUI

@main
struct BIT101_macOSApp: App {
    @ObservedObject var net = NetworkManager.shared
    @AppStorage("colorScheme") private var scheme = "system"

    func applyTheme() {
        switch scheme {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
        default:      NSApp.appearance = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if net.isLoggedIn {
                    ContentView().frame(minWidth: 780, minHeight: 500)
                } else {
                    LoginGateView()
                }
            }
            .onAppear { applyTheme() }
            .onChange(of: scheme) { _, _ in applyTheme() }
        }
        .windowResizability(.contentMinSize)
    }
}

struct LoginGateView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var sid = ""; @State private var pwd = ""
    @State private var loading = false; @State private var err: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 36)).foregroundStyle(.blue.gradient)

            VStack(spacing: 2) {
                Text("BIT101").font(.title.bold())
                Text("北理助手").font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("学号").font(.caption).foregroundStyle(.secondary)
                TextField("112020xxxx", text: $sid).textFieldStyle(.roundedBorder).frame(width: 220)
                Text("密码").font(.caption).foregroundStyle(.secondary)
                SecureField("统一身份认证密码", text: $pwd).textFieldStyle(.roundedBorder).frame(width: 220)
                    .onSubmit { Task { await login() } }
                if let err { Text(err).font(.caption).foregroundColor(.red).frame(width: 220) }
            }

            Button { Task { await login() } } label: {
                Text(loading ? "登录中..." : "登 录").fontWeight(.medium).frame(width: 220, height: 32)
            }
            .buttonStyle(.borderedProminent).disabled(sid.isEmpty || pwd.isEmpty || loading)
        }
        .padding(40).frame(width: 300, height: 340)
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
