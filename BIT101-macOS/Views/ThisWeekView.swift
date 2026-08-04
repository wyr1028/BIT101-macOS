//
//  ThisWeekView.swift - 本周课程小组件
//
import SwiftUI

struct ThisWeekView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var weekCourses: [(day: Int, date: String, courses: [iCalEvent])] = []
    @State private var loading = false

    private let dayNames = ["日","一","二","三","四","五","六"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("本周课程", systemImage: "calendar").font(.headline)
                Spacer()
                if loading { ProgressView().controlSize(.small) }
            }.padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            if weekCourses.isEmpty && !loading {
                Text("登录后查看本周课程").font(.caption).foregroundStyle(.secondary).padding(20)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(weekCourses, id: \.day) { item in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(spacing: 2) {
                                    Text("周\(dayNames[item.day % 7])").font(.caption.bold())
                                    Text(item.date).font(.system(size: 10)).foregroundStyle(.secondary)
                                }.frame(width: 40)

                                if item.courses.isEmpty {
                                    Text("无课").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 4)
                                } else {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(item.courses, id: \.summary) { c in
                                            HStack(spacing: 4) {
                                                Circle().fill(courseColor(c.summary)).frame(width: 5, height: 5)
                                                Text(c.summary).font(.caption).lineLimit(1)
                                                Spacer()
                                                Text(timeStr(c.startDate)).font(.caption2).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                            }.padding(.horizontal, 12).padding(.vertical, 6)
                            Divider().padding(.leading, 50)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .task { if net.isLoggedIn { await load() } }
    }

    func load() async {
        loading = true
        do {
            let result = try await net.fetchSchedule()
            let cal = Calendar.current
            let today = Date()
            let weekday = cal.component(.weekday, from: today) // 1=Sun
            let mondayOffset = weekday == 1 ? -6 : 2 - weekday
            guard let monday = cal.date(byAdding: .day, value: mondayOffset, to: today) else { return }

            var week: [(day: Int, date: String, courses: [iCalEvent])] = []
            let df = DateFormatter(); df.dateFormat = "M/d"

            for i in 0..<7 {
                guard let date = cal.date(byAdding: .day, value: i, to: monday) else { continue }
                let dow = cal.component(.weekday, from: date)
                let dayEvents = result.events.filter { cal.isDate($0.startDate, inSameDayAs: date) }
                week.append((day: dow, date: df.string(from: date), courses: dayEvents))
            }

            await MainActor.run { weekCourses = week; loading = false }
        } catch { await MainActor.run { loading = false } }
    }

    func timeStr(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
    func courseColor(_ name: String) -> Color {
        CourseColorPool.color(for: name)
    }
}
