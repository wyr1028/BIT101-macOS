//
//  ScheduleView.swift
//
import SwiftUI

struct ScheduleView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var events = [iCalEvent](); @State private var fd = Date()
    @State private var courses = [Course](); @State private var loading = false; @State private var err: String?
    @State private var wk = 1; @State private var tWk = 1; @State private var wks = [1]
    @State private var tm = ""
    private let days = ["周一","周二","周三","周四","周五","周六","周日"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "calendar").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $tm) {
                    Text("当前学期").tag("")
                    ForEach(terms, id: \.self) { Text(termName($0)).tag($0) }
                }.frame(width: 130).onChange(of: tm) { _, _ in Task { await load() } }
                if tWk > 1 {
                    Button { if wk > 1 { wk -= 1; filter() } } label: { Image(systemName: "chevron.left").font(.caption) }
                        .buttonStyle(.plain).disabled(wk <= 1)
                    Picker("", selection: $wk) { ForEach(wks, id: \.self) { Text("第\($0)周").tag($0) } }
                        .frame(width: 90).onChange(of: wk) { _, _ in filter() }
                    Text("/ 共\(tWk)周").font(.caption).foregroundStyle(.secondary)
                    Button { if wk < tWk { wk += 1; filter() } } label: { Image(systemName: "chevron.right").font(.caption) }
                        .buttonStyle(.plain).disabled(wk >= tWk)
                }
                Spacer()
            }.padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 4)
            Divider()

            if loading { Spacer(); ProgressView(); Spacer() }
            else if let err { errorView(err) }
            else if courses.isEmpty { emptyView }
            else { gridView }
        }
        .task { if net.isLoggedIn && events.isEmpty { await load() } }
    }

    var gridView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("节次").font(.caption).foregroundStyle(.secondary).frame(width: 45)
                ForEach(days, id: \.self) { d in
                    Text(d).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1)).cornerRadius(6)
                }
            }.padding(.horizontal, 12).padding(.top, 8)
            Divider().padding(.bottom, 4)

            ScrollView {
                HStack(alignment: .top, spacing: 6) {
                    VStack(spacing: 6) {
                        ForEach(1...13, id: \.self) { s in
                            Text("\(s)").font(.system(.subheadline, design: .monospaced)).fontWeight(.bold).frame(width: 45, height: 60)
                        }
                    }
                    ForEach(1...7, id: \.self) { d in
                        ZStack(alignment: .top) {
                            VStack(spacing: 6) {
                                ForEach(1...13, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 6).fill(d > 5 ? Color.secondary.opacity(0.03) : Color.secondary.opacity(0.05)).frame(height: 60)
                                }
                            }
                            ForEach(courses.filter { $0.day == d }) { block($0) }
                        }.frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
    }

    func block(_ c: Course) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(c.name).font(.system(size: 11, weight: .bold)).lineLimit(2)
            Spacer(minLength: 2)
            if !c.location.isEmpty { Text(c.location).font(.system(size: 9)).lineLimit(1) }
            if !c.teacher.isEmpty { Text(c.teacher).font(.system(size: 9)).lineLimit(1) }
        }
        .padding(4).frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: CGFloat(c.duration) * 60 + CGFloat(c.duration - 1) * 6)
        .background(c.color.opacity(0.2)).overlay(RoundedRectangle(cornerRadius: 8).stroke(c.color.opacity(0.8), lineWidth: 1.5)).cornerRadius(8)
        .offset(y: CGFloat(c.startSection - 1) * (60 + 6))
    }

    func errorView(_ m: String) -> some View {
        VStack(spacing: 12) { Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange); Text(m).font(.callout); Button("重试") { Task { await load() } }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    var emptyView: some View {
        ContentUnavailableView { Label("暂无课表", systemImage: "calendar.badge.exclamationmark") }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func load() async {
        loading = true; err = nil
        do { let r = try await net.fetchSchedule(term: tm.isEmpty ? nil : tm)
            await MainActor.run { events = r.events; fd = r.firstDay; wks = Set(events.map { wOf($0.startDate) }).sorted(); tWk = wks.last ?? 1; wk = 1; filter(); loading = false }
        } catch let e { await MainActor.run { err = e.localizedDescription; loading = false } }
    }
    func filter() { courses = events.filter { wOf($0.startDate) == wk }.map { Course.from(iCalEvent: $0, color: CourseColorPool.color(for: $0.summary)) } }
    func wOf(_ d: Date) -> Int { Calendar.current.dateComponents([.day], from: fd, to: d).day! / 7 + 1 }

    var terms: [String] {
        let cal = Calendar.current; let y = cal.component(.year, from: Date()); let ay = cal.component(.month, from: Date()) >= 8 ? y : y - 1
        var t = [String](); for yy in stride(from: ay, through: 2020, by: -1) { t.append("\(yy)-\(yy+1)-1"); t.append("\(yy)-\(yy+1)-2") }; return t
    }
    func termName(_ t: String) -> String { let p = t.components(separatedBy: "-"); guard p.count >= 3 else { return t }; return "\(String(p[0].suffix(2)))-\(String(p[1].suffix(2))) \(p[2]=="1" ? "秋" : "春")" }
}
