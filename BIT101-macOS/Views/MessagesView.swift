//
//  MessagesView.swift
//
import SwiftUI

struct MessagesView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var msgs: [MessageItem] = []
    @State private var unread = 0
    @State private var loading = false

    var body: some View {
        Group {
            if loading { ProgressView().frame(maxWidth:.infinity,maxHeight:.infinity) }
            else if msgs.isEmpty {
                ContentUnavailableView {
                    Label("暂无消息", systemImage: "envelope.open")
                } description: { Text("登录后查看消息通知") }
            } else {
                List(msgs) { msg in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(msg.from_user?.nickname ?? "系统").font(.subheadline.bold())
                            Spacer()
                            Text(fmt(msg.update_time)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(msg.text ?? "").font(.callout).foregroundStyle(.secondary)
                        if let obj = msg.link_obj, !obj.isEmpty {
                            Text("查看详情 →").font(.caption).foregroundColor(.bitBlue)
                        }
                    }.padding(.vertical, 4)
                }
            }
        }
        .task { if net.isLoggedIn { await load() } }
        .navigationTitle("消息\(unread > 0 ? " (\(unread))" : "")")
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
}
