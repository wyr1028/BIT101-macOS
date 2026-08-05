import SwiftUI
import UniformTypeIdentifiers

struct ScheduleView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var events = [iCalEvent](); @State private var fd = Date()
    @State private var courses = [Course](); @State private var loading = false; @State private var err: String?
    @State private var wk = 1; @State private var tWk = 1; @State private var wks = [1]
    @State private var tm = ""; @State private var icalURL = ""
    @State private var showAuth = false
    private let days = ["周一","周二","周三","周四","周五","周六","周日"]
    /// 今天在星期表头中的列（周一=0 … 周日=6）
    private var todayColumn: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        return (wd + 5) % 7
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 2)
                Picker("", selection: $tm) {
                    Text("当前学期").tag("")
                    ForEach(terms, id: \.self) { Text(termName($0)).tag($0) }
                }
                .pickerStyle(.menu).controlSize(.small)
                .onChange(of: tm) { _, _ in Task { await load() } }
                if tWk > 1 {
                    HStack(spacing: 4) {
                        Button { if wk > 1 { wk -= 1; filter() } } label: {
                            Image(systemName: "chevron.left").font(.caption)
                        }
                        .buttonStyle(.plain).disabled(wk <= 1)
                        .wideHitArea(24)
                        Picker("", selection: $wk) { ForEach(wks, id: \.self) { Text("第\($0)周").tag($0) } }
                            .pickerStyle(.menu).controlSize(.small)
                        Text("/ 共\(tWk)周").font(.caption).foregroundStyle(.secondary)
                        Button { if wk < tWk { wk += 1; filter() } } label: {
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .buttonStyle(.plain).disabled(wk >= tWk)
                        .wideHitArea(24)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, Sp.l).padding(.top, Sp.m).padding(.bottom, Sp.m)

            if loading { LoadingStateView() }
            else if let err { errorView(err) }
            else if courses.isEmpty { emptyView }
            else { gridView }
        }
        .navigationTitle("课表")
        .task { if net.isLoggedIn && events.isEmpty { await load() } }
        .toolbar {
            ToolbarItem { Button { importToCalendar() } label: { Label("导入日历", systemImage: "calendar.badge.plus") } }
            ToolbarItem { Button { exportIcal() } label: { Label("导出 iCal", systemImage: "square.and.arrow.down") } }
            ToolbarItem { Button { Task { await load() } } label: { Label("刷新", systemImage: "arrow.clockwise") } }
        }
        .sheet(isPresented: $showAuth) { SchoolAuthSheet() }
    }

    var gridView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("").frame(width: 45)
                ForEach(0..<7, id: \.self) { i in
                    let isToday = i == todayColumn
                    VStack(spacing: 1) {
                        Text(isToday ? "今天" : days[i])
                            .font(.caption.weight(isToday ? .bold : .semibold))
                        Text(dateStr(offset: i))
                            .font(.system(size: 9))
                            .foregroundStyle(isToday ? Color.bitOrange : Color.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 5)
                    .background {
                        if isToday {
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(Color.bitOrange.opacity(0.16))
                        } else {
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .strokeBorder(isToday ? Color.bitOrange.opacity(0.6) : Color.secondary.opacity(0.25),
                                          lineWidth: isToday ? 1.5 : 1)
                    }
                }
            }
            .padding(.bottom, Sp.m)

            ScrollView {
                HStack(alignment: .top, spacing: 6) {
                    VStack(spacing: 6) {
                        ForEach(1...13, id: \.self) { s in
                            Text("\(s)")
                                .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                                .frame(width: 45, height: 54)
                        }
                    }
                    ForEach(1...7, id: \.self) { d in
                        ZStack(alignment: .top) {
                            VStack(spacing: 6) {
                                ForEach(1...13, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(d > 5 ? Color.primary.opacity(0.02) : Color.primary.opacity(0.03))
                                        .frame(height: 54)
                                }
                            }
                            ForEach(courses.filter { $0.day == d }) { block($0) }
                        }.frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, Sp.s)
            }
        }
        .padding(Sp.m)
        .glassSurface(Radius.lg)
    }

    func dateStr(offset: Int) -> String {
        let cal = Calendar.current
        let mondayOffset = (wk - 1) * 7 + offset
        guard let date = cal.date(byAdding: .day, value: mondayOffset, to: fd) else { return "" }
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: date)
    }

    func block(_ c: Course) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(c.color).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(c.name).font(.system(size: 10, weight: .bold)).lineLimit(2)
                if !c.location.isEmpty { Text(c.location).font(.system(size: 8)).lineLimit(1) }
                if !c.teacher.isEmpty { Text(c.teacher).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(1) }
            }
            .padding(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: CGFloat(c.duration) * 54 + CGFloat(c.duration - 1) * 6)
        .background(c.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(c.color.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contextMenu {
            Button("复制课程信息") { copyCourse(c) }
        }
        .onDrag {  // macOS 独占：可把课程拖到备忘录/日历等其他 App
            NSItemProvider(object: courseText(c) as NSString)
        }
        .offset(y: CGFloat(c.startSection - 1) * (54 + 6))
    }

    /// 课程文本（拖放 / 复制用）
    func courseText(_ c: Course) -> String {
        var parts = [c.name]
        if !c.location.isEmpty { parts.append(c.location) }
        if !c.teacher.isEmpty { parts.append(c.teacher) }
        return parts.joined(separator: " · ")
    }
    func copyCourse(_ c: Course) {
        let p = NSPasteboard.general
        p.clearContents()
        p.setString(courseText(c), forType: .string)
    }

    func errorView(_ m: String) -> some View {
        ErrorStateView(message: m,
                       retry: { Task { await load() } },
                       secondaryTitle: "重新认证",
                       secondaryAction: { showAuth = true })
    }
    var emptyView: some View {
        EmptyStateView(title: "暂无课表", icon: "calendar.badge.exclamationmark")
    }

    func load() async {
        loading = true; err = nil
        // 当前学期：先读缓存
        if tm.isEmpty, let cache = CacheStore.shared.read("schedule_current", as: ScheduleCache.self) {
            await MainActor.run { apply(cache) }
        }
        do { let r = try await net.fetchSchedule(term: tm.isEmpty ? nil : tm)
            let cache = ScheduleCache(events: r.events, firstDay: r.firstDay, term: r.term, icalURL: r.icalURL)
            CacheStore.shared.write(cache, key: "schedule_current")
            await MainActor.run { apply(cache); loading = false }
        } catch let e { await MainActor.run { err = e.localizedDescription; loading = false } }
    }

    private func apply(_ cache: ScheduleCache) {
        events = cache.events; fd = cache.firstDay; icalURL = cache.icalURL
        wks = Set(events.map { wOf($0.startDate) }).sorted(); tWk = wks.last ?? 1; wk = 1
        filter()
    }
    func filter() { courses = events.filter { wOf($0.startDate) == wk }.map { Course.from(iCalEvent: $0, color: CourseColorPool.color(for: $0.summary)) } }
    func wOf(_ d: Date) -> Int { Calendar.current.dateComponents([.day], from: fd, to: d).day! / 7 + 1 }

    var terms: [String] {
        let cal = Calendar.current; let y = cal.component(.year, from: Date()); let ay = cal.component(.month, from: Date()) >= 8 ? y : y - 1
        var t = [String](); for yy in stride(from: ay, through: 2020, by: -1) { t.append("\(yy)-\(yy+1)-1"); t.append("\(yy)-\(yy+1)-2") }; return t
    }
    func termName(_ t: String) -> String { let p = t.components(separatedBy: "-"); guard p.count >= 3 else { return t }; let season = p[2] == "1" ? "秋" : "春"; return "\(String(p[0].suffix(2)))-\(String(p[1].suffix(2)))\(season)" }

    func importToCalendar() {
        guard !icalURL.isEmpty else { return }
        importScheduleToCalendar(icalURL: icalURL)
    }

    /// 导出课表为本地 .ics 文件
    func exportIcal() {
        guard !icalURL.isEmpty, let url = URL(string: icalURL) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "ics") ?? .data]
        panel.nameFieldStringValue = "BIT101_课表.ics"
        panel.begin { resp in
            guard resp == .OK, let dest = panel.url else { return }
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    try data.write(to: dest)
                } catch {}
            }
        }
    }
}
