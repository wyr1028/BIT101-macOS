//
//  AppDelegate.swift
//
import SwiftUI
import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    var badgeTimer: Timer?
    var popover: NSPopover?
    var miniPanel: NSPanel?
    @AppStorage("notifyEnabled") private var notifyEnabled = true
    @AppStorage("dockBadgeEnabled") private var dockBadgeEnabled = true
    @AppStorage("dndEnabled") private var dndEnabled = true
    @AppStorage("menuIcon") private var menuIcon = "calendar.circle"

    func applicationDidFinishLaunching(_ n: Notification) {
        // 崩溃日志：未捕获异常写入 caches/crash.log
        installCrashHandler()
        // 扩大共享缓存：让 AsyncImage 等图片请求能命中磁盘缓存
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        setupStatusBar()
        startReminder()
        startBadgeTimer()
        setupNotificationActions()
        setupGlobalHotkey()
        startSessionCheck()
        restoreMainWindowSize()
        startWindowFrameSave()
        // 启动时检查登录是否过期
        checkSession()
    }

    // MARK: 窗口大小/位置记忆

    func restoreMainWindowSize() {
        guard let frameString = UserDefaults.standard.string(forKey: "mainWindowFrame") else { return }
        let rect = NSRectFromString(frameString)
        guard rect.width > 600, rect.height > 400 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.windows.first(where: { $0.styleMask.contains(.titled) && $0.isMiniaturizable })?
                .setFrame(rect, display: true)
        }
    }

    func startWindowFrameSave() {
        let save: (Notification) -> Void = { note in
            guard let win = note.object as? NSWindow,
                  win.styleMask.contains(.titled), win.isMiniaturizable,
                  win.frame.width > 600, win.frame.height > 400 else { return }
            UserDefaults.standard.set(NSStringFromRect(win.frame), forKey: "mainWindowFrame")
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: nil, queue: .main, using: save)
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: .main, using: save)
    }

    // MARK: 崩溃日志（写入 caches/crash.log）

    func installCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let stack = exception.callStackSymbols.joined(separator: "\n")
            let log = "\(Date())\n\(exception.name.rawValue) \(exception.reason ?? "")\n\(stack)\n\n"
            if let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("crash.log"),
               let data = log.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: url.path),
                   let fh = try? FileHandle(forWritingTo: url) {
                    fh.seekToEndOfFile(); fh.write(data); try? fh.close()
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }

    /// 每 30 分钟检测一次登录态是否过期（全局兜底）
    func startSessionCheck() {
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.checkSession()
        }
    }

    // MARK: macOS 独占：Dock 右键菜单

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let show = NSMenuItem(title: "显示主窗口", action: #selector(dockShowMain), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let settings = NSMenuItem(title: "设置…", action: #selector(dockSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 BIT101", action: #selector(dockQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }
    @objc private func dockShowMain() { showMainWindow() }
    @objc private func dockSettings() { showMainWindow(); NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
    @objc private func dockQuit() { NSApp.terminate(nil) }

    // MARK: macOS 独占：浮动置顶迷你课表（always-on-top）

    func toggleMiniSchedule() {
        if let mini = miniPanel {
            mini.close(); miniPanel = nil
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "本周课程"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: ThisWeekView())
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.setContentSize(NSSize(width: 320, height: 420))
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        miniPanel = panel
    }

    // MARK: macOS 独占：全局快捷键（Cmd+Shift+B 唤出菜单栏面板）

    func setupGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.charactersIgnoringModifiers?.lowercased() == "b" else { return }
            DispatchQueue.main.async { self?.togglePopover() }
        }
    }

    // MARK: macOS 独占：通知操作按钮

    func setupNotificationActions() {
        let view = UNNotificationAction(identifier: "view_schedule", title: "查看课表", options: .foreground)
        let ok = UNNotificationAction(identifier: "dismiss", title: "知道了", options: [])
        let category = UNNotificationCategory(identifier: "course",
                                              actions: [view, ok],
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: 登录过期检测

    func checkSession() {
        guard NetworkManager.shared.isLoggedIn else { return }
        Task {
            do {
                try await NetworkManager.shared.checkLoginStatus()
            } catch {
                await MainActor.run {
                    NetworkManager.shared.logout()
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    notify("登录已过期", "请重新登录 BIT101")
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !NSApp.windows.contains(where: { $0.isVisible && $0.styleMask.contains(.titled) }) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        return false
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let win = NSApp.windows.first(where: { $0.styleMask.contains(.titled) && $0.isMiniaturizable }) {
            win.makeKeyAndOrderFront(nil)
        } else {
            // 没有主窗口时重新显示所有标题窗口
            for win in NSApp.windows where win.styleMask.contains(.titled) {
                win.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: 菜单栏

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem?.button {
            btn.image = NSImage(systemSymbolName: menuIcon, accessibilityDescription: "BIT101")
            btn.action = #selector(togglePopover)
        }
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 220)
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(rootView: MenuBarPopover())
    }

    @objc func togglePopover() {
        guard let p = popover, let btn = statusItem?.button else { return }
        p.isShown ? p.performClose(nil) : p.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
    }

    // MARK: 通知

    func startReminder() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func check() {
        guard NetworkManager.shared.isLoggedIn else { return }
        Task {
            do {
                let r = try await NetworkManager.shared.fetchSchedule()
                let now = Date()
                var inClass = false
                var hasToday = false
                var upcoming: [iCalEvent] = []
                let cal = Calendar.current
                let todayDOW = cal.component(.weekday, from: now)
                for e in r.events {
                    let diff = e.startDate.timeIntervalSince(now)
                    // 课程提醒
                    if notifyEnabled && diff > 540 && diff < 600 {
                        notify("课程提醒", "\(e.summary) 10分钟后开始\n\(e.location)", target: "schedule")
                    }
                    // 检测是否正在上课（开始后45分钟内）
                    if now >= e.startDate && now <= e.startDate.addingTimeInterval(2700) {
                        inClass = true
                    }
                    if cal.component(.weekday, from: e.startDate) == todayDOW {
                        hasToday = true
                        if e.startDate > now { upcoming.append(e) }
                    }
                }
                // 上课静音：开启勿扰模式（受开关控制）
                if dndEnabled {
                    if inClass { enableDND() } else { disableDND() }
                }
                await MainActor.run {
                    updateMenuBarIcon(hasToday: hasToday)
                    updateCountdown(next: upcoming.sorted { $0.startDate < $1.startDate }.first, now: now, inClass: inClass)
                }
            } catch {}
        }
    }

    /// 菜单栏倒计时：下一节课在 2 小时内时显示「⏱x′」
    func updateCountdown(next: iCalEvent?, now: Date, inClass: Bool) {
        guard let btn = statusItem?.button else { return }
        if !inClass, let next {
            let secs = next.startDate.timeIntervalSince(now)
            if secs > 0 && secs < 7200 {
                btn.title = "⏱\(max(1, Int(secs / 60)))′"
                return
            }
        }
        btn.title = ""
    }

    // MARK: Dock 角标（消息未读数）

    func startBadgeTimer() {
        badgeTimer?.invalidate()
        badgeTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refreshBadge()
        }
        refreshBadge()
    }

    func refreshBadge() {
        guard dockBadgeEnabled, NetworkManager.shared.isLoggedIn else {
            NSApp.dockTile.badgeLabel = nil
            return
        }
        Task {
            do {
                let (_, unread) = try await NetworkManager.shared.fetchMessages()
                let label = unread > 0 ? "\(unread)" : nil
                await MainActor.run { NSApp.dockTile.badgeLabel = label }
            } catch {}
        }
    }

    func updateMenuBarIcon(hasToday: Bool) {
        guard let btn = statusItem?.button else { return }
        let name: String
        if menuIcon == "calendar.circle" {
            name = hasToday ? "calendar.circle.fill" : "calendar.circle"
        } else {
            name = menuIcon
        }
        btn.image = NSImage(systemSymbolName: name, accessibilityDescription: "BIT101")
    }

    func enableDND() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDistributedCenter(),
            CFNotificationName("com.apple.notificationcenterui.dndStart" as CFString),
            nil, nil, true
        )
    }

    func disableDND() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDistributedCenter(),
            CFNotificationName("com.apple.notificationcenterui.dndEnd" as CFString),
            nil, nil, true
        )
    }

    func notify(_ title: String, _ body: String, target: String? = nil) {
        let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
        if let target {
            c.userInfo = ["target": target]
            if target == "schedule" { c.categoryIdentifier = "course" }  // 带操作按钮
        }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    // MARK: 通知点击跳转

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent n: UNNotification, withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        showMainWindow()
        if response.actionIdentifier == "view_schedule" {
            NotificationCenter.default.post(name: .openNavItem, object: nil, userInfo: ["item": "课表"])
        } else {
            let target = response.notification.request.content.userInfo["target"] as? String
            if target == "schedule" {
                NotificationCenter.default.post(name: .openNavItem, object: nil, userInfo: ["item": "课表"])
            } else if target == "messages" {
                NotificationCenter.default.post(name: .openNavItem, object: nil, userInfo: ["item": "消息"])
            }
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let openNavItem = Notification.Name("openNavItem")
    static let menuBarReload = Notification.Name("menuBarReload")
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        // 弹窗出现后再通知一次，确保视图已挂载
        NotificationCenter.default.post(name: .menuBarReload, object: nil)
    }
}

// MARK: Popover

struct MenuBarPopover: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var today: [iCalEvent] = []; @State private var loaded = false
    @AppStorage("colorScheme") private var scheme = "system"
    @AppStorage("notifyEnabled") private var notifyEnabled = true

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            VStack(spacing: 0) {
                // 头部
                HStack(spacing: 8) {
                    ModuleIcon(icon: "books.vertical.fill", color: .bitOrange, size: 24)
                    Text("BIT101").font(.headline)
                    Spacer()
                    Text(net.isLoggedIn ? "已登录" : "未登录").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, Sp.m).padding(.top, Sp.m).padding(.bottom, Sp.s)

                GlassDivider(inset: Sp.m)

                if net.isLoggedIn {
                    // 今日课程
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日课程").font(.subheadline.bold()).padding(.horizontal, Sp.m)
                        if today.isEmpty && !loaded {
                            ProgressView().controlSize(.small).frame(maxWidth: .infinity).padding(.vertical, 8)
                        } else if today.isEmpty {
                            Text("今日无课").font(.callout).foregroundStyle(.secondary)
                                .padding(.horizontal, Sp.m).padding(.vertical, 4)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(today.prefix(8), id: \.summary) { courseRow($0) }
                                }
                            }
                            .frame(maxHeight: min(CGFloat(min(today.count, 8)) * 32, 160))
                        }
                    }
                    .padding(.vertical, 6)

                    GlassDivider(inset: Sp.m)

                    // 快捷设置
                    HStack(spacing: 8) {
                        Image(systemName: "circle.lefthalf.filled").frame(width: 18).foregroundColor(.blue)
                        Text("外观").font(.caption)
                        Spacer()
                        Picker("", selection: $scheme) {
                            Text("浅").tag("light"); Text("深").tag("dark"); Text("系统").tag("system")
                        }
                        .pickerStyle(.segmented).controlSize(.small).frame(width: 120)
                    }.padding(.horizontal, Sp.m).padding(.vertical, 4)

                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill").frame(width: 18).foregroundColor(.orange)
                        Text("课程提醒").font(.caption)
                        Spacer()
                        Toggle("", isOn: $notifyEnabled).toggleStyle(.switch).controlSize(.small)
                    }.padding(.horizontal, Sp.m).padding(.vertical, 2)

                    GlassDivider(inset: Sp.m)

                    // 操作按钮
                    VStack(spacing: 6) {
                        Button {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                (NSApp.delegate as? AppDelegate)?.showMainWindow()
                            }
                        } label: {
                            Label("显示主窗口", systemImage: "macwindow").frame(maxWidth: .infinity)
                        }.buttonStyle(.glass).controlSize(.small)

                        Button {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                (NSApp.delegate as? AppDelegate)?.toggleMiniSchedule()
                            }
                        } label: {
                            Label("浮动课表", systemImage: "macwindow.on.rectangle").frame(maxWidth: .infinity)
                        }.buttonStyle(.glassSecondary).controlSize(.small)

                        Button {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NSApp.terminate(nil)
                            }
                        } label: {
                            Label("退出 BIT101", systemImage: "xmark.circle").frame(maxWidth: .infinity)
                        }.buttonStyle(.glassSecondary).controlSize(.small)
                    }
                    .padding(.horizontal, Sp.m).padding(.vertical, 4)
                } else {
                    Text("请先登录").font(.callout).foregroundStyle(.secondary).padding()
                    Button {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            (NSApp.delegate as? AppDelegate)?.showMainWindow()
                        }
                    } label: {
                        Label("打开 BIT101", systemImage: "macwindow").frame(maxWidth: .infinity)
                    }.buttonStyle(.glass).controlSize(.small).padding(.horizontal)
                }
            }
            .frame(width: 280)
        }
        .frame(width: 280, height: popoverHeight)
        .clipped()
        .task { if net.isLoggedIn && !loaded { loaded = true; await load() } }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarReload)) { _ in
            Task { await load() }
        }
        .onAppear { updateSize() }
        .onChange(of: today.count) { _, _ in updateSize() }
        .onChange(of: net.isLoggedIn) { _, _ in updateSize() }
    }

    /// 课程行：模块色条 + 时间/地点
    func courseRow(_ c: iCalEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color.bitBlue).frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(c.summary).font(.caption).lineLimit(1)
                HStack(spacing: 6) {
                    Text(tf(c.startDate)).font(.caption2).foregroundStyle(.secondary)
                    if !c.location.isEmpty {
                        Text(c.location).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, Sp.m).padding(.vertical, 3)
    }

    /// 高度按内容自适应：课多则高、课少则矮
    var popoverHeight: CGFloat {
        guard net.isLoggedIn else { return 130 }
        let contentH: CGFloat = today.isEmpty ? 24 : CGFloat(min(today.count, 8)) * 32
        return min(253 + min(contentH, 160), 450)
    }

    func updateSize() {
        let h = popoverHeight
        DispatchQueue.main.async {
            (NSApp.delegate as? AppDelegate)?.popover?.contentSize = NSSize(width: 280, height: h)
        }
    }

    func load() async {
        do {
            let r = try await net.fetchSchedule()
            let cal = Calendar.current; let dow = cal.component(.weekday, from: Date())
            let upcoming = r.events
                .filter { cal.component(.weekday, from: $0.startDate) == dow && $0.startDate > Date() }
                .sorted { $0.startDate < $1.startDate }
            await MainActor.run { today = upcoming }
        } catch {}
    }

    func tf(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d) }
}
