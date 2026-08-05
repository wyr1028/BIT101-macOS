import SwiftUI
import EventKit
import UserNotifications

struct ExamView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var exams: [NetworkManager.ExamItem] = []
    @State private var loading = false
    @State private var err: String?
    @State private var terms: [String] = []
    @State private var picked: String? = nil
    @State private var showAuth = false

    var shown: [NetworkManager.ExamItem] {
        picked.map { p in exams.filter { $0.term.contains(p) } } ?? exams
    }

    var body: some View {
        Group {
            if net.webvpnCookie.isEmpty {
                SchoolAuthRequiredView(title: "考试安排")
            } else if loading && exams.isEmpty {
                LoadingStateView()
            } else if let err, exams.isEmpty {
                VStack(spacing: Sp.m) {
                    ModuleIcon(icon: "exclamationmark.triangle.fill", color: .orange, size: 46)
                    Text(err).font(Typo.body()).multilineTextAlignment(.center).padding(.horizontal, 40)
                    HStack(spacing: Sp.s) {
                        Button("重新认证") { showAuth = true }.buttonStyle(.glass)
                        Button("重试") { Task { await load() } }.buttonStyle(.glassSecondary)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if exams.isEmpty {
                EmptyStateView(title: "暂无考试安排", icon: "pencil.and.list.clipboard", description: "当前没有可显示的考试数据")
            } else {
                VStack(spacing: 0) {
                    // 学期筛选 + 刷新（标题统一走标题栏）
                    HStack(spacing: 8) {
                        if !terms.isEmpty {
                            Picker("", selection: $picked) {
                                Text("全部学期").tag(String?.none)
                                ForEach(terms, id: \.self) { Text(termName($0)).tag(String?.some($0)) }
                            }
                            .pickerStyle(.menu).controlSize(.small)
                        }
                        Spacer()
                        Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.plain).help("刷新")
                    }
                    .padding(.horizontal, Sp.l).padding(.vertical, Sp.m)
                    GlassDivider(inset: Sp.l)

                    ScrollView {
                        LazyVStack(spacing: Sp.m) {
                            ForEach(shown) { card($0).entrance() }
                        }.padding(Sp.l)
                    }
                }
            }
        }
        .navigationTitle("考试安排")
        .toolbar {
            ToolbarItem { Button { importExamsToCalendar() } label: { Label("导入日历", systemImage: "calendar.badge.plus") } }
        }
        .sheet(isPresented: $showAuth) { SchoolAuthSheet() }
        .task { if !net.webvpnCookie.isEmpty && exams.isEmpty { await load() } }
    }

    func card(_ e: NetworkManager.ExamItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(e.name).font(.body.bold()).lineLimit(2)
                HStack(spacing: 6) {
                    if !e.location.isEmpty {
                        Label(e.location, systemImage: "mappin.and.ellipse")
                    }
                    if !e.seat.isEmpty {
                        Label("座位 \(e.seat)", systemImage: "number.square")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if !e.date.isEmpty {
                    Label(e.date, systemImage: "calendar")
                        .font(.caption.weight(.medium)).foregroundColor(.orange)
                }
                if !e.time.isEmpty {
                    Label(e.time, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .glassCard(12)
    }

    func load() async {
        loading = true; err = nil
        do {
            let list = try await net.fetchExams()
            await MainActor.run {
                exams = list
                terms = Array(Set(list.map(\.term).filter { !$0.isEmpty })).sorted()
                loading = false
            }
        } catch {
            await MainActor.run { err = error.localizedDescription; loading = false }
        }
    }

    func termName(_ s: String) -> String {
        let p = s.components(separatedBy: "-")
        if p.count >= 2 {
            let season = (p.last?.contains("1") ?? false) ? "秋" : "春"
            return "\(p[0].suffix(2))-\(p[1].suffix(2))\(season)"
        }
        return s
    }

    // MARK: 考试添加到系统日历（EventKit）

    func importExamsToCalendar() {
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, _ in
            guard granted else { return }
            var saved = 0
            for e in shown {
                guard let start = examDate(date: e.date, time: e.time),
                      let end = start.addingTimeInterval(2 * 3600) as Date? else { continue }
                let ev = EKEvent(eventStore: store)
                ev.title = "考试：\(e.name)"
                ev.startDate = start
                ev.endDate = end
                if !e.location.isEmpty { ev.location = e.location }
                ev.calendar = store.defaultCalendarForNewEvents
                if (try? store.save(ev, span: .thisEvent)) != nil { saved += 1 }
            }
            if saved > 0 {
                let c = UNMutableNotificationContent(); c.title = "已导入日历"
                c.body = "已将 \(saved) 门考试添加到系统日历"; c.sound = .default
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
            }
        }
    }

    func examDate(date: String, time: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"
        let t = time.components(separatedBy: "-").first?.trimmingCharacters(in: .whitespaces) ?? "09:00"
        return f.date(from: "\(date) \(t)")
    }
}
