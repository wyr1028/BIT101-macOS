//
//  MessagesView.swift
//
import SwiftUI

struct MessagesView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var msgs: [MessageItem] = []
    @State private var unread = 0
    @State private var loading = false
    @State private var readIds: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "readMsgIds") ?? [])

    private func isRead(_ id: Int) -> Bool { readIds.contains("\(id)") }
    private func markRead(_ id: Int) {
        readIds.insert("\(id)")
        UserDefaults.standard.set(Array(readIds), forKey: "readMsgIds")
    }
    private func markAllRead() {
        for m in msgs { readIds.insert("\(m.id ?? 0)") }
        UserDefaults.standard.set(Array(readIds), forKey: "readMsgIds")
    }

    var body: some View {
        Group {
            if loading { LoadingStateView() }
            else if msgs.isEmpty {
                EmptyStateView(title: "暂无消息", icon: "envelope.open", description: "登录后查看消息通知")
            } else {
                ScrollView {
                    LazyVStack(spacing: Sp.m) {
                        ForEach(msgs) { msg in
                            messageRow(msg).entrance()
                        }
                    }
                    .padding(Sp.m)
                }
            }
        }
        .task { if net.isLoggedIn { await load() } }
        .toolbar {
            ToolbarItem { Button("全部已读") { markAllRead() }.buttonStyle(.plain) }
            ToolbarItem { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") } }
        }
        .navigationTitle("消息\(unread > 0 ? " (\(unread))" : "")")
    }

    private func messageRow(_ msg: MessageItem) -> some View {
        GlassListItem {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    // 未读蓝点
                    Circle().fill(isRead(msg.id ?? 0) ? Color.clear : Color.bitBlue)
                        .frame(width: 7, height: 7)
                    GlassAvatar(name: msg.from_user?.nickname ?? "", color: .bitBlue, size: 24)
                    Text(msg.from_user?.nickname ?? "系统").font(.subheadline.bold())
                    Spacer()
                    Text(fmt(msg.update_time)).font(.caption2).foregroundStyle(.secondary)
                }
                Text(msg.text ?? "").font(.callout).foregroundStyle(.secondary)
                if let obj = msg.link_obj, !obj.isEmpty {
                    Button("查看详情 →") {
                        markRead(msg.id ?? 0)
                        openLinked(obj)
                    }
                    .font(.caption).foregroundColor(.bitBlue)
                    .buttonStyle(.plain)
                    .wideHitArea()
                }
            }
        }
    }

    func load() async {
        loading = true
        do {
            let (m, u) = try await net.fetchMessages()
            await MainActor.run { msgs = m; unread = u; loading = false }
        } catch { await MainActor.run { loading = false } }
    }

    func fmt(_ s: String?) -> String {
        guard let s else { return "" }; return String(s.prefix(10))
    }

    /// 根据 link_obj（如 poster123 / paper456 / comment789）打开对应详情窗口
    func openLinked(_ obj: String) {
        let id = Int(obj.filter(\.isNumber))
        Task {
            if obj.hasPrefix("poster"), let id {
                let d = try? await net.fetchPosterDetail(id: id)
                if let d {
                    await MainActor.run {
                        openDetailWindow(title: d.title ?? "帖子详情", width: 520, height: 720) {
                            LinkedPosterDetail(detail: d)
                        }
                    }
                }
            } else if obj.hasPrefix("paper"), let id {
                let d = try? await net.fetchPaperDetail(id: id)
                if let d {
                    await MainActor.run {
                        openDetailWindow(title: d.title ?? "文章详情", width: 520, height: 720) {
                            LinkedPaperDetail(detail: d)
                        }
                    }
                }
            }
        }
    }
}

// MARK: 消息跳转到的详情视图

struct LinkedPosterDetail: View {
    let detail: PosterDetail
    var body: some View {
        DetailGlassBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let t = detail.title, !t.isEmpty { Text(t).font(Typo.header(.title2)) }
                    Text(detail.text ?? "").font(.body)
                    HStack {
                        Label("\(detail.like_num ?? 0)", systemImage: "heart")
                        Label("\(detail.comment_num ?? 0)", systemImage: "bubble.right")
                        Spacer()
                    }.font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LinkedPaperDetail: View {
    let detail: PaperDetail
    var body: some View {
        DetailGlassBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let t = detail.title, !t.isEmpty { Text(t).font(Typo.header(.title2)) }
                    if let c = detail.content, let parsed = parseEditorJS(c) {
                        EditorJSRenderer(content: parsed)
                    } else {
                        Text(detail.content ?? detail.intro ?? "").font(.body)
                    }
                }
            }
        }
    }
}
