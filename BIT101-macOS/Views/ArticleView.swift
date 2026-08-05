import SwiftUI

struct ArticleView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var papers: [PaperItem] = []
    @State private var loading = false; @State private var err: String?
    @State private var page = 0; @State private var more = true
    @State private var comments: [CommentItem] = []
    @State private var loadingComments = false; @State private var commentText = ""
    @State private var showComposer = false
    @State private var pTitle = ""; @State private var pIntro = ""; @State private var pContent = ""

    var body: some View {
        Group {
            if loading && papers.isEmpty { LoadingStateView() }
            else if let err, papers.isEmpty { ErrorStateView(message: err) { Task { await reload() } } }
            else {
                VStack(spacing: 0) {
                    RecentHistoryStrip(type: "paper") { e in
                        Task { await openPaper(id: e.itemId) }
                    }
                    .padding(.horizontal, Sp.l).padding(.top, Sp.m)
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(papers.enumerated()), id: \.element.id) { idx, item in
                                paperRow(item).entrance()
                                    .onAppear {
                                        if idx >= papers.count - 3 && more { Task { await loadMore() } }
                                    }
                            }
                            if more { ProgressView().onAppear{Task{await loadMore()}} }
                        }.padding(Sp.l)
                    }
                }
            }
        }
        .sheet(isPresented: $showComposer) { composeView }
        .navigationTitle("文章")
        .toolbar {
            ToolbarItem {
                Button { showComposer = true } label: { Image(systemName: "square.and.pencil") }
                    .disabled(!net.isLoggedIn)
            }
            ToolbarItem { Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") } }
        }
        .task { await reload() }
    }

    // MARK: 发布文章

    var composeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Spacer(); Button("取消") { showComposer = false }.buttonStyle(.plain) }
            Text("发布文章").font(Typo.header(.title2))
            GlassTextField(placeholder: "标题", text: $pTitle)
            GlassTextField(placeholder: "简介（可选）", text: $pIntro)
            Text("正文").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $pContent).frame(minHeight: 180)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(.secondary.opacity(0.15), lineWidth: 1))
            Button {
                Task { await publish() }
            } label: { Text("发布").frame(maxWidth: .infinity) }
            .buttonStyle(.glass)
            .disabled(pTitle.isEmpty || pContent.isEmpty)
        }
        .padding(24).frame(width: 420)
        .glassSheetBackground()
    }

    func publish() async {
        let editorJSON = """
        {"time": \(Int(Date().timeIntervalSince1970)), "blocks": [{"type": "header", "data": {"text": \(jsonQuote(pTitle)), "level": 2}}, {"type": "paragraph", "data": {"text": \(jsonQuote(pContent))}}]}
        """
        do {
            try await net.createPaper(title: pTitle, intro: pIntro, content: editorJSON)
            await MainActor.run { showComposer = false; pTitle = ""; pIntro = ""; pContent = "" }
            await reload()
        } catch { print("publish err:\(error)") }
    }

    func jsonQuote(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                      .replacingOccurrences(of: "\"", with: "\\\"")
                      .replacingOccurrences(of: "\r", with: "\\r")
                      .replacingOccurrences(of: "\n", with: "\\n")
                      .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    func paperRow(_ item: PaperItem) -> some View {
        Button { Task { await openDetail(item) } } label: {
            VStack(alignment:.leading,spacing:8) {
                Text(item.title ?? "无标题").font(.headline).lineLimit(1)
                Text(item.intro ?? "").font(.callout).lineLimit(3).foregroundStyle(.secondary)
                HStack(spacing:16) {
                    Label("\(item.like_num ?? 0)",systemImage:"heart")
                    Label("\(item.comment_num ?? 0)",systemImage:"bubble.right")
                    FavoriteButton(id: "paper\(item.identity)")
                    Spacer(); Text(rt(item.update_time)).font(.caption2).foregroundStyle(.secondary)
                }.font(.caption).foregroundStyle(.secondary)
            }
            .glassCard(14)
            .contentShape(RoundedRectangle(cornerRadius:14))
            .hoverCard()
        }.buttonStyle(.plain)
        .contextMenu {
            Button("复制标题") { copyText(item.title ?? "") }
            Button("复制简介") { copyText(item.intro ?? "") }
        }
    }

    // 独立窗口详情：交给自包含的 PaperDetailView（带独立评论状态）
    func paperDetailContent(_ d: PaperDetail) -> some View {
        PaperDetailView(detail: d)
    }

    func reload() async { loading=true;err=nil;page=0;more=true;await loadPage(0) }
    func loadMore() async { guard more,!loading else{return};await loadPage(page+1) }
    func loadPage(_ p: Int) async {
        do{let items=try await net.fetchPapers(page:p);await MainActor.run{if p==0{papers=items}else{papers.append(contentsOf:items)};more = !items.isEmpty;page=p;loading=false}}catch{await MainActor.run{if p==0{err=error.localizedDescription};loading=false}}
    }
    func openDetail(_ item: PaperItem) async {
        HistoryStore.record(type: "paper", id: item.identity, title: item.title ?? "文章")
        do {
            let d = try await net.fetchPaperDetail(id: item.identity)
            await MainActor.run {
                openDetailWindow(title: d.title ?? "文章详情", width: 520, height: 720) {
                    PaperDetailView(detail: d)
                }
            }
        } catch { print("detail:\(error)") }
    }

    // 从「最近浏览」重新打开
    func openPaper(id: Int) async {
        do {
            let d = try await net.fetchPaperDetail(id: id)
            await MainActor.run {
                openDetailWindow(title: d.title ?? "文章详情", width: 520, height: 720) {
                    PaperDetailView(detail: d)
                }
            }
        } catch {}
    }
    func loadComments(_ obj: String) async { loadingComments=true;do{let c=try await net.fetchComments(obj:obj);await MainActor.run{comments=c}}catch{print("cmt:\(error)")};await MainActor.run{loadingComments=false} }
    func postComment(_ obj: String) async { do{try await net.sendComment(obj:obj,text:commentText);await loadComments(obj)}catch{print("cmt:\(error)")} }
    func rt(_ s: String?) -> String { guard let s else{return""}; return String(s.prefix(10)) }
}

// MARK: 文章详情（自包含评论状态，独立窗口可用）

struct PaperDetailView: View {
    @ObservedObject var net = NetworkManager.shared
    let detail: PaperDetail
    @State private var comments: [CommentItem] = []
    @State private var loadingComments = false
    @State private var commentText = ""

    var body: some View {
        DetailGlassBackground {
            VStack(spacing: 0) {
                // 玻璃头部条
                VStack(alignment: .leading, spacing: Sp.s) {
                    HStack(spacing: 10) {
                        ModuleIcon(icon: "doc.richtext", color: .moduleGallery, size: 28)
                        Text("文章")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, Sp.s).padding(.vertical, 3)
                            .background(Capsule().fill(Color.moduleGallery.opacity(0.16)))
                            .foregroundColor(Color.moduleGallery)
                        Spacer()
                    }
                    Text(detail.title ?? "").font(Typo.header(.title2))
                    if let u = detail.update_user {
                        HStack(spacing: 8) {
                            GlassAvatar(name: u.nickname ?? "", size: 28)
                            Text(u.nickname ?? "用户").font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal, Sp.m).padding(.vertical, Sp.s)
                .glassSurface(Radius.md)
                .padding(.horizontal, Sp.l).padding(.top, Sp.l)

                // 可滚动正文 + 评论
                ScrollView {
                    VStack(alignment: .leading, spacing: Sp.m) {
                        if let content = detail.content, let parsed = parseEditorJS(content) {
                            EditorJSRenderer(content: parsed)
                        } else {
                            Text(detail.content ?? detail.intro ?? "").font(.body).lineSpacing(5)
                        }

                        HStack(spacing: 16) {
                            Label("\(detail.like_num ?? 0)", systemImage: (detail.like ?? false) ? "heart.fill" : "heart")
                                .foregroundColor(detail.like == true ? .red : .secondary)
                            Label("\(detail.comment_num ?? 0) 评论", systemImage: "bubble.right")
                            FavoriteButton(id: "paper\(detail.id ?? 0)")
                            Spacer()
                        }.font(.callout).foregroundStyle(.secondary)

                        GlassDivider()
                        Text("评论 · \(comments.count)").font(.subheadline.weight(.semibold))
                        if loadingComments {
                            LoadingStateView()
                        } else if comments.isEmpty {
                            Text("暂无评论").font(.callout).foregroundStyle(.secondary)
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
            let c = try await net.fetchComments(obj: "paper\(detail.id ?? 0)")
            await MainActor.run { comments = c }
        } catch {}
        await MainActor.run { loadingComments = false }
    }

    func postComment() async {
        do {
            try await net.sendComment(obj: "paper\(detail.id ?? 0)", text: commentText)
            commentText = ""
            await loadComments()
        } catch {}
    }
}

extension PaperDetail: Identifiable {}
