//
//  SettingsView.swift - 应用设置（⌘,）
//
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("colorScheme") private var scheme = "system"
    @AppStorage("notifyEnabled") private var notifyEnabled = true
    @AppStorage("dockBadgeEnabled") private var dockBadgeEnabled = true
    @AppStorage("dndEnabled") private var dndEnabled = true
    @AppStorage("cacheEnabled") private var cacheEnabled = true
    @AppStorage("menuIcon") private var menuIcon = "calendar.circle"

    @ObservedObject var net = NetworkManager.shared
    @State private var webvpnOK = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
            appearanceTab
                .tabItem { Label("外观与关于", systemImage: "paintbrush") }
            accountTab
                .tabItem { Label("账户", systemImage: "person.crop.circle") }
        }
        .frame(width: 460, height: 360)
        .task { await verify() }
    }

    // MARK: 通用

    private var generalTab: some View {
        ScrollView {
            VStack(spacing: Sp.m) {
                settingsCard {
                    Toggle("课程提醒（上课前 10 分钟通知）", isOn: $notifyEnabled)
                    GlassDivider()
                    Toggle("上课期间自动开启勿扰模式", isOn: $dndEnabled)
                }
                settingsCard {
                    Toggle("Dock 图标显示消息未读数", isOn: $dockBadgeEnabled)
                    GlassDivider()
                    Text("开启后消息数会在 Dock 图标角标上显示")
                        .font(.caption).foregroundStyle(.secondary)
                }
                settingsCard {
                    Toggle("缓存已加载的数据（课表/成绩等）", isOn: $cacheEnabled)
                }
            }
            .padding(Sp.l)
        }
    }

    // MARK: 外观与关于

    private var appearanceTab: some View {
        ScrollView {
            VStack(spacing: Sp.m) {
                settingsCard {
                    Picker("外观模式", selection: $scheme) {
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                        Text("跟随系统").tag("system")
                    }
                    .pickerStyle(.segmented)
                }
                settingsCard {
                    Picker("菜单栏图标", selection: $menuIcon) {
                        Text("日历").tag("calendar.circle")
                        Text("书本").tag("books.vertical.fill")
                        Text("毕业帽").tag("graduationcap.fill")
                        Text("闪电").tag("bolt.fill")
                    }
                    .pickerStyle(.segmented)
                }
                settingsCard {
                    LabeledContent("版本") { Text("1.0.0").foregroundStyle(.secondary) }
                    GlassDivider()
                    LabeledContent("BIT101 API") { Text("bit101.flwfdd.xyz").foregroundStyle(.secondary) }
                }
            }
            .padding(Sp.l)
        }
    }

    // MARK: 账户

    private var accountTab: some View {
        ScrollView {
            VStack(spacing: Sp.m) {
                settingsCard {
                    LabeledContent("BIT101 社区账号") {
                        Text(net.isLoggedIn ? "已登录" : "未登录")
                            .foregroundColor(net.isLoggedIn ? .green : .secondary)
                    }
                    GlassDivider()
                    LabeledContent("学校统一身份认证") {
                        Text(net.webvpnCookie.isEmpty ? "未认证" : (webvpnOK ? "有效" : "已过期"))
                            .foregroundColor(net.webvpnCookie.isEmpty ? .orange : (webvpnOK ? .green : .orange))
                    }
                    if net.webvpnCookie.isEmpty {
                        Text("考试、空教室、DDL 等需要学校官方 webvpn 认证。若提示需要验证码或被风控拦截，请稍后再试。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button(webvpnOK ? "重新校验" : "重新认证") { Task { await verify() } }
                        .buttonStyle(.glassSecondary)
                }
                settingsCard {
                    HStack {
                        Button("导出数据备份") { exportBackup() }
                            .buttonStyle(.glassSecondary)
                        Button("导入数据备份") { importBackup() }
                            .buttonStyle(.glassSecondary)
                    }
                }
                settingsCard {
                    HStack {
                        Button("清空本地缓存") { CacheStore.shared.clear() }
                            .buttonStyle(.glassSecondary)
                        Spacer()
                        Button("退出登录") { net.logout() }
                            .buttonStyle(.glassDestructive)
                    }
                }
            }
            .padding(Sp.l)
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Sp.s) {
            content()
        }
        .padding(Sp.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(Radius.md)
    }

    func verify() async {
        webvpnOK = await net.verifyWebVPNSession()
    }

    // MARK: 数据备份 / 恢复

    private var backupKeys: [String] {
        ["studentID", "fakeCookie", "webvpnCookie", "favorites", "colorScheme",
         "notifyEnabled", "dockBadgeEnabled", "dndEnabled", "cacheEnabled"]
    }

    func exportBackup() {
        var dict: [String: Any] = [:]
        for k in backupKeys {
            if let v = UserDefaults.standard.object(forKey: k) { dict[k] = v }
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "BIT101_备份.json"
        panel.allowedContentTypes = [.json]
        panel.begin { resp in
            guard resp == .OK, let url = panel.url,
                  let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) else { return }
            try? data.write(to: url)
        }
    }

    func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.begin { resp in
            guard resp == .OK, let url = panel.url,
                  let data = try? Data(contentsOf: url),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            for (k, v) in dict { UserDefaults.standard.set(v, forKey: k) }
        }
    }
}
