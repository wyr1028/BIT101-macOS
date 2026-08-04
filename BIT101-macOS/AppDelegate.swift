//
//  AppDelegate.swift
//
import SwiftUI
import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    var timer: Timer?
    var popover: NSPopover?
    @AppStorage("notifyEnabled") private var notifyEnabled = true

    func applicationDidFinishLaunching(_ n: Notification) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        setupStatusBar()
        startReminder()
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
            btn.image = NSImage(systemSymbolName: "books.vertical.fill", accessibilityDescription: "BIT101")
            btn.action = #selector(togglePopover)
        }
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 340)
        popover?.behavior = .transient
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
        guard NetworkManager.shared.isLoggedIn, notifyEnabled else { return }
        Task {
            do {
                let r = try await NetworkManager.shared.fetchSchedule()
                let now = Date()
                var inClass = false
                for e in r.events {
                    let diff = e.startDate.timeIntervalSince(now)
                    // 课程提醒
                    if diff > 540 && diff < 600 {
                        notify("课程提醒", "\(e.summary) 10分钟后开始\n\(e.location)")
                    }
                    // 检测是否正在上课（开始后45分钟内）
                    if now >= e.startDate && now <= e.startDate.addingTimeInterval(2700) {
                        inClass = true
                    }
                }
                // 上课静音：开启勿扰模式
                if inClass {
                    enableDND()
                } else {
                    disableDND()
                }
            } catch {}
        }
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

    func notify(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent n: UNNotification, withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h([.banner, .sound])
    }
}

// MARK: Popover

struct MenuBarPopover: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var today: [iCalEvent] = []; @State private var loaded = false
    @AppStorage("colorScheme") private var scheme = "system"
    @AppStorage("notifyEnabled") private var notifyEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Image(systemName: "books.vertical.fill").foregroundStyle(.blue.gradient)
                Text("BIT101").font(.headline); Spacer()
                Text(net.isLoggedIn ? "已登录" : "未登录").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal).padding(.top, 12).padding(.bottom, 8)

            Divider()

            if net.isLoggedIn {
                // 今日课程
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日课程").font(.subheadline.bold()).padding(.horizontal)
                    if today.isEmpty && !loaded {
                        ProgressView().controlSize(.small).frame(maxWidth: .infinity)
                    } else if today.isEmpty {
                        Text("今日无课").font(.callout).foregroundStyle(.secondary).padding(.horizontal)
                    } else {
                        ScrollView {
                            ForEach(today.prefix(8), id: \.summary) { c in
                                HStack {
                                    Circle().fill(.blue).frame(width: 6, height: 6)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(c.summary).font(.caption).lineLimit(1)
                                        Text(tf(c.startDate)).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }.padding(.horizontal)
                            }
                        }.frame(maxHeight: 160)
                    }
                }.padding(.vertical, 6)

                Divider()

                // 快捷设置
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "circle.lefthalf.filled").frame(width: 18).foregroundColor(.blue)
                        Text("外观").font(.caption)
                        Spacer()
                        Picker("", selection: $scheme) {
                            Text("浅").tag("light"); Text("深").tag("dark"); Text("系统").tag("system")
                        }.pickerStyle(.segmented).frame(width: 120)
                    }.padding(.horizontal)
                }.padding(.vertical, 4)

                HStack {
                    Image(systemName: "bell.fill").frame(width: 18).foregroundColor(.orange)
                    Text("课程提醒").font(.caption)
                    Spacer()
                    Toggle("", isOn: $notifyEnabled).toggleStyle(.switch).controlSize(.small)
                }.padding(.horizontal).padding(.vertical, 2)

                Divider()

                // 操作按钮
                VStack(spacing: 6) {
                    Button {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            (NSApp.delegate as? AppDelegate)?.showMainWindow()
                        }
                    } label: {
                        Label("显示主窗口", systemImage: "macwindow").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.small)

                    Button {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NSApp.terminate(nil)
                        }
                    } label: {
                        Label("退出 BIT101", systemImage: "xmark.circle").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered).controlSize(.small)
                }.padding(.horizontal).padding(.vertical, 4)
            } else {
                Text("请先登录").font(.callout).foregroundStyle(.secondary).padding()
                Button {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        (NSApp.delegate as? AppDelegate)?.showMainWindow()
                    }
                } label: {
                    Label("打开 BIT101", systemImage: "macwindow").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.small).padding(.horizontal)
            }
            Spacer()
        }
        .frame(width: 280, height: 380)
        .task { if net.isLoggedIn && !loaded { loaded = true; await load() } }
    }

    func load() async {
        do {
            let r = try await net.fetchSchedule()
            let cal = Calendar.current; let dow = cal.component(.weekday, from: Date())
            await MainActor.run { today = r.events.filter { cal.component(.weekday, from: $0.startDate) == dow && $0.startDate > Date() } }
        } catch {}
    }

    func tf(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d) }
}
