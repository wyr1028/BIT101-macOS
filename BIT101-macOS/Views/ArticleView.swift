import SwiftUI

struct ArticleView: View {
    @ObservedObject var networkManager = NetworkManager.shared
    @State private var papers: [PaperItem] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var page = 0
    @State private var hasMore = true
    @State private var detailPaper: PaperDetail?
    @State private var comments: [CommentItem] = []
    @State private var loadingComments = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && papers.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else if let errorMsg, papers.isEmpty {
                ContentUnavailableView("加载失败", systemImage: "wifi.slash", description: Text(errorMsg))
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 12) {
                        LazyVStack(spacing: 12) {
                            ForEach(papers) { paperRow($0) }
                            if hasMore { ProgressView().onAppear { Task { await loadMore() } } }
                        }.padding(16)
                    }
                }
            }
        }
        .sheet(item: $detailPaper) { detailSheet($0) }
        .task { await reload() }
    }

    private func paperRow(_ item: PaperItem) -> some View {
        Button { Task { await openDetail(item) } } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(item.title ?? "无标题").font(.system(.headline, design: .rounded)).lineLimit(1)
                    Spacer()
                    Text(relativeTime(from: item.update_time)).font(.caption2).foregroundStyle(.secondary)
                }
                Text(item.intro ?? "").font(.body).lineLimit(3).foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    Label("\(item.like_num ?? 0)", systemImage: "heart")
                    Label("\(item.comment_num ?? 0)", systemImage: "bubble.right")
                    Spacer()
                }.font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func detailSheet(_ d: PaperDetail) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Spacer(); Button { detailPaper = nil } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary) }.buttonStyle(.plain) }

                    Text(d.title ?? "").font(.title2.bold())

                    if let u = d.update_user {
                        HStack(spacing: 8) {
                            Text(String(u.nickname?.prefix(1) ?? "?")).font(.headline).frame(width: 32, height: 32).background(Circle().fill(Color.accentColor.opacity(0.2))).foregroundColor(.accentColor)
                            Text(u.nickname ?? "用户").font(.subheadline)
                        }
                    }

                    Text(d.content ?? d.intro ?? "").font(.body).lineSpacing(4)

                    HStack(spacing: 20) {
                        Label("\(d.like_num ?? 0)", systemImage: (d.like ?? false) ? "heart.fill" : "heart").foregroundColor(d.like == true ? .red : .secondary)
                        Label("\(d.comment_num ?? 0) 评论", systemImage: "bubble.right")
                        Spacer()
                    }.font(.callout).foregroundStyle(.secondary)

                    Divider()
                    if loadingComments { ProgressView().frame(maxWidth: .infinity) }
                    else if comments.isEmpty { Text("暂无评论").font(.callout).foregroundStyle(.secondary) }
                    else {
                        ForEach(comments) { c in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(String((c.user?.nickname ?? "?").prefix(1))).font(.caption2.bold()).frame(width: 22, height: 22).background(Circle().fill(Color.secondary.opacity(0.15)))
                                    Text(c.user?.nickname ?? "用户").font(.caption.bold())
                                    Spacer(); Text(relativeTime(from: c.create_time)).font(.caption2).foregroundStyle(.secondary)
                                }
                                Text(c.text ?? "").font(.callout).padding(.leading, 28)
                            }.padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 420, idealWidth: 480, minHeight: 500)
        .task { await loadComments(obj: "paper\(d.id ?? 0)") }
    }

    private func reload() async { isLoading = true; errorMsg = nil; page = 0; hasMore = true; await loadPage(0) }
    private func loadMore() async { guard hasMore, !isLoading else { return }; await loadPage(page + 1) }
    private func loadPage(_ p: Int) async {
        do {
            let items = try await networkManager.fetchPapers(page: p)
            await MainActor.run { if p == 0 { papers = items } else { papers.append(contentsOf: items) }; hasMore = !items.isEmpty; page = p; isLoading = false }
        } catch { await MainActor.run { if p == 0 { errorMsg = error.localizedDescription }; isLoading = false } }
    }
    private func openDetail(_ item: PaperItem) async {
        do { let d = try await networkManager.fetchPaperDetail(id: item.identity); await MainActor.run { detailPaper = d } } catch { print("detail: \(error)") }
    }
    private func loadComments(obj: String) async {
        loadingComments = true; do { let c = try await networkManager.fetchComments(obj: obj); await MainActor.run { comments = c } } catch { print("comments: \(error)") }
        await MainActor.run { loadingComments = false }
    }
}

extension PaperDetail: Identifiable {}
