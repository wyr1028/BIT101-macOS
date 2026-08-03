import SwiftUI

struct CourseReviewView: View {
    @ObservedObject var networkManager = NetworkManager.shared
    @State private var courses: [CourseItem] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var page = 0
    @State private var hasMore = true

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && courses.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else if let errorMsg, courses.isEmpty {
                ContentUnavailableView("加载失败", systemImage: "wifi.slash", description: Text(errorMsg))
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 10) {
                        LazyVStack(spacing: 10) {
                            ForEach(courses) { courseRow($0) }
                            if hasMore { ProgressView().onAppear { Task { await loadMore() } } }
                        }.padding(16)
                    }
                }
            }
        }
        .task { if networkManager.isLoggedIn { await reload() } }
    }

    private func courseRow(_ c: CourseItem) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(c.name ?? "未知课程").font(.system(.body, design: .rounded).bold()).lineLimit(1)
                Text(c.teachers_name ?? "").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", c.rate ?? 0))
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundColor(rateColor(c.rate ?? 0))
                HStack(spacing: 2) {
                    Image(systemName: "star.fill").font(.system(size: 9))
                    Text("\(c.comment_num ?? 0)评价").font(.caption2)
                }.foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    private func rateColor(_ r: Double) -> Color {
        r >= 8 ? .green : r >= 6 ? .blue : r >= 4 ? .orange : .red
    }

    private func reload() async { isLoading = true; errorMsg = nil; page = 0; hasMore = true; await loadPage(0) }
    private func loadMore() async { guard hasMore, !isLoading else { return }; await loadPage(page + 1) }
    private func loadPage(_ p: Int) async {
        do {
            let items = try await networkManager.fetchCourses(page: p)
            await MainActor.run { if p == 0 { courses = items } else { courses.append(contentsOf: items) }; hasMore = !items.isEmpty; page = p; isLoading = false }
        } catch { await MainActor.run { if p == 0 { errorMsg = error.localizedDescription }; isLoading = false } }
    }
}
