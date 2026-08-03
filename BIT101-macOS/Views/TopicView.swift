import SwiftUI

// MARK: - 话题视图

struct TopicView: View {
    @ObservedObject var networkManager = NetworkManager.shared
    @State private var posters: [PosterItem] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var page = 0
    @State private var hasMore = true
    @State private var mode = "recommend"
    @State private var detailPoster: PosterDetail?
    @State private var comments: [CommentItem] = []
    @State private var loadingComments = false

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            if isLoading && posters.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else if let errorMsg, posters.isEmpty {
                ContentUnavailableView("加载失败", systemImage: "wifi.slash", description: Text(errorMsg))
            } else {
                ScrollView {
                    GlassEffectContainer(spacing: 12) {
                        LazyVStack(spacing: 12) {
                            ForEach(posters) { posterRow($0) }
                            if hasMore { ProgressView().onAppear { Task { await loadMore() } } }
                        }.padding(16)
                    }
                }
            }
        }
        .sheet(item: $detailPoster) { detailSheet($0) }
        .task { if networkManager.isLoggedIn && posters.isEmpty { await reload() } }
    }

    // MARK: 分类选择器

    private var modePicker: some View {
        Picker("分类", selection: $mode) {
            Text("推荐").tag("recommend"); Text("热门").tag("hot"); Text("关注").tag("follow")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 260)
        .padding(.vertical, 8)
        .onChange(of: mode) { _, _ in Task { await reload() } }
    }

    // MARK: 帖子卡片

    private func posterRow(_ item: PosterItem) -> some View {
        Button { Task { await openDetail(item) } } label: {
            VStack(alignment: .leading, spacing: 10) {
                // 头部：用户 + 时间
                HStack(spacing: 8) {
                    avatarIcon(for: item)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.anonymous == true ? "匿名者" : (item.user?.nickname ?? "用户"))
                            .font(.system(.subheadline, weight: .medium))
                        Text(relativeTime(from: item.update_time))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let tags = item.tags, !tags.isEmpty {
                        Text("#\(tags.first!)").font(.caption2).foregroundColor(.accentColor)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .glassEffect(.regular, in: Capsule())
                    }
                }

                // 标题
                if let t = item.title, !t.isEmpty {
                    Text(t).font(.system(.headline, design: .rounded)).lineLimit(1)
                }

                // 正文
                Text(item.text ?? "").font(.body).lineLimit(4).foregroundStyle(.primary)

                // 底栏
                HStack(spacing: 20) {
                    Label("\(item.like_num ?? 0)", systemImage: "heart")
                    Label("\(item.comment_num ?? 0)", systemImage: "bubble.right")
                    Spacer()
                    if let tags = item.tags {
                        ForEach(tags.prefix(3), id: \.self) { t in
                            Text("#\(t)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }.font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func avatarIcon(for item: PosterItem) -> some View {
        let name = item.anonymous == true ? "?" : String((item.user?.nickname ?? "?").prefix(1))
        return Text(name).font(.system(.caption, design: .rounded).bold())
            .frame(width: 32, height: 32)
            .background(Circle().fill(item.anonymous == true ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.2)))
            .foregroundColor(item.anonymous == true ? .secondary : .accentColor)
    }

    // MARK: 详情 Sheet

    private func detailSheet(_ d: PosterDetail) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Spacer(); Button { detailPoster = nil } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary) }.buttonStyle(.plain) }

                    // 用户信息
                    HStack(spacing: 10) {
                        Text(String((d.anonymous == true ? "匿" : (d.user?.nickname ?? "?"))).prefix(1))
                            .font(.title3.bold()).frame(width: 40, height: 40)
                            .background(Circle().fill(Color.accentColor.opacity(0.2))).foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.anonymous == true ? "匿名者" : (d.user?.nickname ?? "用户")).font(.headline)
                            Text(relativeTime(from: d.create_time)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    if let t = d.title, !t.isEmpty {
                        Text(t).font(.title3.bold())
                    }

                    Text(d.text ?? "").font(.body).lineSpacing(4)

                    if let tags = d.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(tags, id: \.self) { Text("#\($0)").font(.caption).padding(.horizontal, 10).padding(.vertical, 4).glassEffect(.regular, in: Capsule()).foregroundColor(.accentColor) } }
                        }
                    }

                    HStack(spacing: 20) {
                        Button { Task { await toggleLike(obj: "poster\(d.id ?? 0)") } } label: {
                            Label("\(d.like_num ?? 0)", systemImage: (d.like ?? false) ? "heart.fill" : "heart").foregroundColor(d.like == true ? .red : .secondary)
                        }.buttonStyle(.plain)
                        Label("\(d.comment_num ?? 0) 评论", systemImage: "bubble.right")
                        Spacer()
                    }.font(.callout)

                    Divider()

                    if loadingComments { ProgressView().frame(maxWidth: .infinity) }
                    else if comments.isEmpty { Text("暂无评论").font(.callout).foregroundStyle(.secondary).padding(.vertical, 8) }
                    else {
                        ForEach(comments) { commentRow($0) }
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 420, idealWidth: 480, minHeight: 500)
        .task { await loadComments(obj: "poster\(d.id ?? 0)") }
    }

    private func commentRow(_ c: CommentItem) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String((c.user?.nickname ?? "?").prefix(1)))
                        .font(.caption2.bold()).frame(width: 22, height: 22)
                        .background(Circle().fill(Color.secondary.opacity(0.15)))
                    Text(c.user?.nickname ?? "用户").font(.caption.bold())
                    Spacer()
                    Text(relativeTime(from: c.create_time)).font(.caption2).foregroundStyle(.secondary)
                }
                Text(c.text ?? "").font(.callout).padding(.leading, 28)
                if let subs = c.sub {
                    ForEach(subs) { s in
                        HStack(alignment: .top, spacing: 4) {
                            Text(String((s.user?.nickname ?? "?").prefix(1)))
                                .font(.caption2.bold()).frame(width: 18, height: 18)
                                .background(Circle().fill(Color.secondary.opacity(0.12)))
                            Text(s.user?.nickname ?? "用户").font(.caption.bold())
                            Text(s.text ?? "").font(.caption)
                        }.padding(.leading, 44)
                    }.padding(.top, 4)
                }
            }
            .padding(.vertical, 6)
            Divider()
        }
    }

    // MARK: Actions

    private func reload() async { isLoading = true; errorMsg = nil; page = 0; hasMore = true; await loadPage(0) }
    private func loadMore() async { guard hasMore, !isLoading else { return }; await loadPage(page + 1) }

    private func loadPage(_ p: Int) async {
        do {
            let items = try await networkManager.fetchPosters(page: p, mode: mode)
            await MainActor.run {
                if p == 0 { posters = items } else { posters.append(contentsOf: items) }
                hasMore = !items.isEmpty; page = p; isLoading = false
            }
        } catch {
            await MainActor.run { if p == 0 { errorMsg = error.localizedDescription }; isLoading = false }
        }
    }

    private func openDetail(_ item: PosterItem) async {
        do { let d = try await networkManager.fetchPosterDetail(id: item.identity); await MainActor.run { detailPoster = d } }
        catch { print("detail: \(error)") }
    }

    private func loadComments(obj: String) async {
        loadingComments = true
        do { let c = try await networkManager.fetchComments(obj: obj); await MainActor.run { comments = c } }
        catch { print("comments: \(error)") }
        await MainActor.run { loadingComments = false }
    }

    private func toggleLike(obj: String) async {
        do {
            let r = try await networkManager.toggleLike(obj: obj)
            await MainActor.run {
                guard let d = detailPoster else { return }
                detailPoster = PosterDetail(
                    id: d.id, title: d.title, text: d.text, create_time: d.create_time,
                    update_time: d.update_time, uid: d.uid, anonymous: d.anonymous,
                    like_num: r.count, comment_num: d.comment_num, user: d.user,
                    images: d.images, tags: d.tags, like: r.liked, own: d.own, claim: d.claim)
            }
        } catch { print("like: \(error)") }
    }
}

/// 相对时间格式化
func relativeTime(from str: String?) -> String {
    guard let str else { return "" }
    let df = ISO8601DateFormatter(); df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = df.date(from: str) ?? ISO8601DateFormatter().date(from: str) else { return String(str.prefix(10)) }
    let interval = -date.timeIntervalSinceNow
    switch interval {
    case ..<60: return "刚刚"
    case ..<3600: return "\(Int(interval/60))分钟前"
    case ..<86400: return "\(Int(interval/3600))小时前"
    case ..<604800: return "\(Int(interval/86400))天前"
    default: return String(str.prefix(10))
    }
}

extension PosterDetail: Identifiable {}
