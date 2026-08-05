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
                GlassSearchField(placeholder: "搜索课程名/教师", text: $search) {
                    Task { await reload() }
                }
                .frame(width: 220)
                Picker("排序", selection: $order) {
                    Text("评分").tag("rate"); Text("最新").tag("new"); Text("最热").tag("like")
                }
                .pickerStyle(.menu).controlSize(.small)
                .onChange(of: order) { _, _ in Task { await reload() } }
                Spacer()
            }.padding(.horizontal, Sp.l).padding(.vertical, Sp.m)

            GlassDivider(inset: Sp.l)

            if loading && courses.isEmpty { LoadingStateView() }
            else if let err, courses.isEmpty { ErrorStateView(message: err) { Task { await reload() } } }
            else {
                ScrollView {
                    LazyVStack(spacing: Sp.m) {
                        ForEach(Array(courses.enumerated()), id: \.element.id) { idx, item in
                            courseRow(item).entrance()
                                .onAppear {
                                    if idx >= courses.count - 3 && more { Task { await loadMore() } }
                                }
                        }
                        if more { ProgressView().onAppear { Task { await loadMore() } } }
                    }.padding(Sp.l)
                }
            }
        }
        .navigationTitle("课程评价")
        .toolbar { ToolbarItem { Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") } } }
        .task { await reload() }
    }

    func courseRow(_ c: CourseItem) -> some View {
        Button { openDetail(c) } label: {
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
            .glassCard(12)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .hoverCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: 课程详情窗口

    func openDetail(_ c: CourseItem) {
        openDetailWindow(title: c.name ?? "课程详情", width: 500, height: 680) {
            CourseDetailContent(course: c)
        }
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

// MARK: 课程详情（评价列表 + 发表评价）

struct CourseDetailContent: View {
    @ObservedObject var net = NetworkManager.shared
    let course: CourseItem
    @State private var comments: [CommentItem] = []
    @State private var loading = false
    @State private var reviewText = ""
    @State private var sending = false

    var body: some View {
        DetailGlassBackground {
            VStack(spacing: 0) {
                // 玻璃头部条：课程图标 + 课程名 + 评分
                HStack(spacing: 10) {
                    ModuleIcon(icon: "star.fill", color: .moduleScore, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name ?? "未知课程")
                            .font(.subheadline.weight(.semibold)).lineLimit(1)
                        HStack(spacing: 8) {
                            if let n = course.number, !n.isEmpty {
                                Text(n).font(.caption2).monospaced().foregroundStyle(.tertiary)
                            }
                            Text(course.teachers_name ?? "").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(String(format: "%.1f", course.rate ?? 0))
                            .font(Typo.stat()).foregroundColor(rateColor)
                        Text("\(course.comment_num ?? 0) 评价")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Sp.m).padding(.vertical, Sp.s)
                .glassSurface(Radius.md)
                .padding(.horizontal, Sp.l).padding(.top, Sp.l)

                // 发表评价（玻璃条，回车发送）
                HStack(spacing: Sp.s) {
                    GlassTextField(placeholder: "写一条课程评价…（回车发送）", text: $reviewText) {
                        Task { await postReview() }
                    }
                    Button {
                        Task { await postReview() }
                    } label: {
                        sending ? AnyView(ProgressView().controlSize(.small)) : AnyView(Text("发表"))
                    }
                    .buttonStyle(.glass)
                    .disabled(reviewText.isEmpty || sending)
                }
                .padding(.horizontal, Sp.m).padding(.vertical, Sp.s)
                .glassSurface(Radius.md)
                .padding(.horizontal, Sp.l).padding(.bottom, Sp.l)

                // 评价列表
                Group {
                    if loading {
                        LoadingStateView()
                    } else if comments.isEmpty {
                        EmptyStateView(title: "暂无评价", icon: "bubble.left.and.bubble.right")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Sp.m) {
                                ForEach(comments) {
                                    CommentCard(nickname: $0.user?.nickname, text: $0.text,
                                                time: $0.create_time.map { String($0.prefix(10)) })
                                }
                            }
                            .padding(Sp.l)
                        }
                    }
                }
            }
            .task { await load() }
        }
    }

    var rateColor: Color {
        let r = course.rate ?? 0
        return r >= 8 ? .green : r >= 6 ? .blue : r >= 4 ? .orange : .red
    }

    func load() async {
        loading = true
        do {
            let list = try await net.fetchComments(obj: "course\(course.identity)")
            await MainActor.run { comments = list; loading = false }
        } catch { await MainActor.run { loading = false } }
    }

    func postReview() async {
        sending = true
        do {
            try await net.sendComment(obj: "course\(course.identity)", text: reviewText)
            await MainActor.run { reviewText = ""; sending = false }
            await load()
        } catch { await MainActor.run { sending = false } }
    }
}
