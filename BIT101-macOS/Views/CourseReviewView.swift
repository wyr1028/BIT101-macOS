import SwiftUI

struct CourseReviewView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var courses: [CourseItem] = []
    @State private var loading = false; @State private var err: String?
    @State private var page = 0; @State private var more = true
    @State private var search = ""; @State private var order = "rate"

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏 + 排序
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索课程名/教师", text: $search)
                    .textFieldStyle(.roundedBorder).frame(width: 200)
                    .onSubmit { Task { await reload() } }
                Picker("排序", selection: $order) {
                    Text("评分").tag("rate"); Text("最新").tag("new"); Text("最热").tag("like")
                }.frame(width: 80).onChange(of: order) { _, _ in Task { await reload() } }
                Spacer()
            }.padding(.horizontal, 20).padding(.vertical, 8)

            Divider()

            if loading && courses.isEmpty { Spacer(); ProgressView(); Spacer() }
            else if let err, courses.isEmpty { ContentUnavailableView("加载失败", systemImage: "wifi.slash", description: Text(err)) }
            else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(courses) { courseRow($0) }
                        if more { ProgressView().onAppear { Task { await loadMore() } } }
                    }.padding(16)
                }
            }
        }
        .navigationTitle("课程评价")
        .task { await reload() }
    }

    func courseRow(_ c: CourseItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(c.name ?? "未知课程").font(.body.bold()).lineLimit(1)
                HStack(spacing: 4) {
                    if let n = c.number, !n.isEmpty { Text(n).font(.caption2).foregroundStyle(.tertiary).monospaced() }
                    Text(c.teachers_name ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", c.rate ?? 0)).font(.title3.bold()).foregroundColor(rateC(c.rate ?? 0))
                HStack(spacing: 2) { Image(systemName: "star.fill").font(.system(size:8)); Text("\(c.comment_num ?? 0)").font(.caption2) }.foregroundStyle(.secondary)
            }
        }
        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    func rateC(_ r: Double) -> Color { r>=8 ? .green : r>=6 ? .blue : r>=4 ? .orange : .red }

    func reload() async { loading=true;err=nil;page=0;more=true;await loadPage(0) }
    func loadMore() async { guard more,!loading else{return};await loadPage(page+1) }
    func loadPage(_ p: Int) async {
        do {
            let items = try await net.fetchCourses(page: p, order: order, search: search.isEmpty ? nil : search)
            await MainActor.run {
                if p==0 { courses=items } else { courses.append(contentsOf:items) }
                more = !items.isEmpty; page = p; loading = false
            }
        } catch { await MainActor.run { if p==0 { err=error.localizedDescription }; loading=false } }
    }
}
