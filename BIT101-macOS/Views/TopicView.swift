//
//  TopicView.swift - 话题列表+发帖+评论+点赞
//
import SwiftUI

struct TopicView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var list: [PosterItem] = []; @State private var loading = false; @State private var err: String?
    @State private var page = 0; @State private var more = true; @State private var mode = "recommend"
    @State private var detail: PosterDetail?; @State private var comments: [CommentItem] = []
    @State private var loadingComments = false; @State private var commentText = ""
    @State private var showComposer = false
    @State private var cTitle = ""; @State private var cText = ""; @State private var cAnon = false; @State private var cTags = ""
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("", selection: $mode) {
                    Text("推荐").tag("recommend"); Text("热门").tag("hot"); Text("关注").tag("follow")
                }.pickerStyle(.segmented).frame(width: 200)
                GlassSearchField(placeholder: "搜索话题", text: $search) {
                    Task { await reload() }
                }
                Spacer()
            }.padding(.horizontal, Sp.l).padding(.vertical, Sp.m)
            .onChange(of: mode) { _, _ in Task { await reload() } }
            GlassDivider(inset: Sp.l)

            if loading && list.isEmpty { LoadingStateView() }
            else if let err, list.isEmpty { ErrorStateView(message: err) { Task { await reload() } } }
            else {
                VStack(spacing: 0) {
                    RecentHistoryStrip(type: "poster") { e in
                        Task { await openPoster(id: e.itemId) }
                    }
                    .padding(.horizontal, Sp.l).padding(.top, Sp.m)
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { idx, item in
                                card(item).entrance()
                                    .onAppear {
                                        if idx >= list.count - 3 && more { Task { await loadMore() } }
                                    }
                            }
                            if more { ProgressView().onAppear { Task { await loadMore() } } }
                        }.padding(Sp.l)
                    }
                }
            }
        }
        .navigationTitle("话题")
        .sheet(isPresented: $showComposer) { composeView }
        .toolbar {
            ToolbarItem { Button { showComposer=true } label: { Image(systemName:"square.and.pencil") }.disabled(!net.isLoggedIn) }
            ToolbarItem { Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") } }
        }
        .task { if net.isLoggedIn && list.isEmpty { await reload() } }
    }

    // MARK: 卡片

    func card(_ item: PosterItem) -> some View {
        Button { Task { await openDetail(item) } } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    GlassAvatar(name: item.anonymous == true ? "匿" : (item.user?.nickname ?? ""),
                                color: item.anonymous == true ? .secondary : .bitBlue, size: 28)
                    Text(item.anonymous == true ? "匿名者" : (item.user?.nickname ?? "用户")).font(.subheadline.weight(.medium))
                    Spacer(); Text(rt(item.update_time)).font(.caption2).foregroundStyle(.secondary)
                }
                if let t=item.title,!t.isEmpty { Text(t).font(.headline).lineLimit(1) }
                Text(item.text ?? "").font(.callout).lineLimit(4)
                HStack(spacing: 16) {
                    Button {
                        Task { await toggleLike("poster\(item.identity)") }
                    } label: {
                        Label("\(item.like_num ?? 0)", systemImage: (item.like ?? false) ? "heart.fill" : "heart")
                            .foregroundColor(item.like == true ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .wideHitArea()
                    Label("\(item.comment_num ?? 0)", systemImage:"bubble.right")
                    FavoriteButton(id: "poster\(item.identity)")
                    if let tags=item.tags,!tags.isEmpty {
                        Spacer(); ForEach(tags.prefix(3),id:\.self){Text("#\($0)").font(.caption2).foregroundStyle(.secondary)}
                    }
                }.font(.caption).foregroundStyle(.secondary)
            }
            .glassCard(14)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .hoverCard()
        }.buttonStyle(.plain)
        .contextMenu {
            Button("复制标题") { copyText(item.title ?? "") }
            Button("复制正文") { copyText(item.text ?? "") }
        }
    }

    // MARK: 详情

    func detailView(_ d: PosterDetail) -> some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                HStack{Spacer();Button{detail=nil}label:{Image(systemName:"xmark.circle.fill").font(.title3).foregroundStyle(.secondary)}.buttonStyle(.plain)}
                HStack{
                    GlassAvatar(name: d.user?.nickname ?? "", size: 36)
                    VStack(alignment:.leading,spacing:2){Text(d.anonymous == true ? "匿名者" : (d.user?.nickname ?? "用户")).font(.headline);Text(rt(d.create_time)).font(.caption).foregroundStyle(.secondary)}
                    Spacer()
                }
                if let t=d.title,!t.isEmpty{Text(t).font(.title3.bold())}
                Text(d.text ?? "").font(.body)
                HStack(spacing:16){
                    Button{Task{await toggleLike("poster\(d.id ?? 0)")}}label:{Label("\(d.like_num ?? 0)",systemImage:(d.like ?? false) ? "heart.fill":"heart").foregroundColor(d.like == true ? .red:.secondary)}.buttonStyle(.plain)
                    Label("\(d.comment_num ?? 0)",systemImage:"bubble.right")
                    Spacer()
                }.font(.callout).foregroundStyle(.secondary)

                GlassDivider()
                Text("评论").font(.headline)
                HStack{
                    GlassTextField(placeholder: "写评论...", text: $commentText)
                    Button("发送"){Task{await sendComment("poster\(d.id ?? 0)");commentText=""}}.buttonStyle(.glass).disabled(commentText.isEmpty)
                }
                if loadingComments{ProgressView()}
                else if comments.isEmpty{Text("暂无评论").font(.callout).foregroundStyle(.secondary)}
                else{ForEach(comments){commentRow($0)}}
            }.padding(20)
        }.frame(minWidth:420,minHeight:500)
        .task{await loadComments("poster\(d.id ?? 0)")}
    }

    func commentRow(_ c: CommentItem) -> some View {
        CommentCard(nickname: c.user?.nickname, text: c.text, time: rt(c.create_time), subs: c.sub)
    }

    // MARK: 发帖

    var composeView: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack{Spacer();Button("取消"){showComposer=false}.buttonStyle(.plain)}
            Text("发布话题").font(Typo.header(.title2))
            GlassTextField(placeholder:"标题",text:$cTitle)
            TextEditor(text:$cText).frame(minHeight:120)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(.secondary.opacity(0.15), lineWidth: 1))
            HStack{Toggle("匿名",isOn:$cAnon);GlassTextField(placeholder:"标签(逗号分隔)",text:$cTags)}
            Button{let tags=cTags.split(separator:",").map{String($0).trimmingCharacters(in:.whitespaces)}.filter{!$0.isEmpty}
                Task{do{try await net.createPoster(title:cTitle,text:cText,anonymous:cAnon,tags:tags)
                await MainActor.run{showComposer=false;cTitle="";cText="";cTags=""};await reload()}catch{print("err:\(error)")}}
            }label:{Text("发布").frame(maxWidth:.infinity)}.buttonStyle(.glass).disabled(cTitle.isEmpty||cText.isEmpty)
        }.padding(24).frame(width:400)
            .glassSheetBackground()
    }

    // MARK: Data

    func reload() async { loading=true;err=nil;page=0;more=true;await loadPage(0) }
    func loadMore() async { guard more,!loading else{return};await loadPage(page+1) }
    func loadPage(_ p: Int) async {
        do{let items=try await net.fetchPosters(page:p,mode:mode,search:search.isEmpty ? nil : search);await MainActor.run{if p==0{list=items}else{list.append(contentsOf:items)};more = !items.isEmpty;page=p;loading=false}}catch{await MainActor.run{if p==0{err=error.localizedDescription};loading=false}}
    }
    func openDetail(_ item: PosterItem) async {
        HistoryStore.record(type: "poster", id: item.identity,
                            title: item.title ?? item.text ?? "话题")
        do { let d = try await net.fetchPosterDetail(id: item.identity)
            await MainActor.run {
                openDetailWindow(title: d.title ?? "帖子详情", width: 520, height: 720) {
                    PosterDetailView(detail: d)
                }
            }
        } catch { print("detail:\(error)") }
    }

    // 从「最近浏览」重新打开
    func openPoster(id: Int) async {
        do {
            let d = try await net.fetchPosterDetail(id: id)
            await MainActor.run {
                openDetailWindow(title: d.title ?? "帖子详情", width: 520, height: 720) {
                    PosterDetailView(detail: d)
                }
            }
        } catch {}
    }

    // 独立窗口详情：交给自包含的 PosterDetailView（带独立评论状态）
    func posterDetailContent(_ d: PosterDetail) -> some View {
        PosterDetailView(detail: d)
    }

    func postComment(_ obj: String) async { 
        do { try await net.sendComment(obj: obj, text: commentText); await loadComments(obj) }
        catch { print("cmt:\(error)") }
    }

    func toggleLike(_ obj: String) async {
        let pid = Int(obj.replacingOccurrences(of: "poster", with: ""))
        do {
            let r = try await net.toggleLike(obj: obj)
            await MainActor.run {
                if let pid, let idx = list.firstIndex(where: { $0.identity == pid }) {
                    list[idx].like_num = r.count
                    list[idx].like = r.liked
                }
                if let pid, detail?.identity == pid {
                    detail?.like = r.liked
                    detail?.like_num = r.count
                }
            }
        } catch { print("like:\(error)") }
    }
    func loadComments(_ obj: String) async { loadingComments = true; do { let c = try await net.fetchComments(obj: obj); await MainActor.run { comments = c } } catch { print("cmt:\(error)") }; await MainActor.run { loadingComments = false } }
    func sendComment(_ obj: String) async { await postComment(obj) }

    func rt(_ s: String?) -> String { guard let s else{return""}; return String(s.prefix(10)) }
}

// MARK: 话题详情（自包含评论状态，独立窗口可用）

struct PosterDetailView: View {
    @ObservedObject var net = NetworkManager.shared
    let detail: PosterDetail
    @State private var comments: [CommentItem] = []
    @State private var loadingComments = false
    @State private var commentText = ""
    @State private var liked: Bool
    @State private var likeCount: Int

    init(detail: PosterDetail) {
        self.detail = detail
        _liked = State(initialValue: detail.like ?? false)
        _likeCount = State(initialValue: detail.like_num ?? 0)
    }

    var body: some View {
        DetailGlassBackground {
            VStack(spacing: 0) {
                // 玻璃头部条：模块图标 + 作者 + 话题标签
                HStack(spacing: 10) {
                    ModuleIcon(icon: "bubble.left.and.bubble.right", color: .moduleGallery, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detail.anonymous == true ? "匿名者" : (detail.user?.nickname ?? "用户"))
                            .font(.subheadline.weight(.semibold))
                        Text(st(detail.create_time)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("话题")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, Sp.s).padding(.vertical, 3)
                        .background(Capsule().fill(Color.moduleGallery.opacity(0.16)))
                        .foregroundColor(Color.moduleGallery)
                }
                .padding(.horizontal, Sp.m).padding(.vertical, Sp.s)
                .glassSurface(Radius.md)
                .padding(.horizontal, Sp.l).padding(.top, Sp.l)

                // 可滚动正文 + 评论
                ScrollView {
                    VStack(alignment: .leading, spacing: Sp.m) {
                        if let t = detail.title, !t.isEmpty {
                            Text(t).font(Typo.header(.title2))
                        }
                        Text(detail.text ?? "").font(.body).lineSpacing(5)

                        HStack(spacing: 16) {
                            Button { Task { await toggleLike() } } label: {
                                Label("\(likeCount)", systemImage: liked ? "heart.fill" : "heart")
                                    .foregroundColor(liked ? .red : .secondary)
                            }
                            .buttonStyle(.plain)
                            .wideHitArea()
                            Label("\(detail.comment_num ?? 0)", systemImage: "bubble.right")
                            FavoriteButton(id: "poster\(detail.id ?? 0)")
                            Spacer()
                        }.font(.callout).foregroundStyle(.secondary)

                        GlassDivider()
                        Text("评论 · \(comments.count)").font(.subheadline.weight(.semibold))
                        if loadingComments {
                            LoadingStateView()
                        } else if comments.isEmpty {
                            Text("还没有评论，来抢沙发").font(.callout).foregroundStyle(.secondary)
                                .padding(.vertical, Sp.l)
                        } else {
                            LazyVStack(spacing: Sp.m) {
                                ForEach(comments) {
                                    CommentCard(nickname: $0.user?.nickname, text: $0.text,
                                                time: st($0.create_time), subs: $0.sub)
                                }
                            }
                        }
                    }
                    .padding(Sp.l)
                }

                // 玻璃评论输入条（回车发送）
                HStack(spacing: Sp.s) {
                    GlassTextField(placeholder: "写评论…（回车发送）", text: $commentText) {
                        Task { await postComment() }
                    }
                    Button("发送") { Task { await postComment() } }
                        .buttonStyle(.glass)
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, Sp.m).padding(.vertical, Sp.s)
                .glassSurface(Radius.md)
                .padding(.horizontal, Sp.l).padding(.bottom, Sp.l)
            }
            .task { await loadComments() }
        }
    }

    private func st(_ s: String?) -> String { String(s?.prefix(10) ?? "") }

    func loadComments() async {
        loadingComments = true
        do {
            let c = try await net.fetchComments(obj: "poster\(detail.id ?? 0)")
            await MainActor.run { comments = c }
        } catch {}
        await MainActor.run { loadingComments = false }
    }

    func postComment() async {
        do {
            try await net.sendComment(obj: "poster\(detail.id ?? 0)", text: commentText)
            commentText = ""
            await loadComments()
        } catch {}
    }

    func toggleLike() async {
        do {
            let r = try await net.toggleLike(obj: "poster\(detail.id ?? 0)")
            await MainActor.run { liked = r.liked; likeCount = r.count }
        } catch {}
    }
}

extension PosterDetail: Identifiable {}
