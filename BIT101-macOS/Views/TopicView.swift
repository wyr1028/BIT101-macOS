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

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                Text("推荐").tag("recommend"); Text("热门").tag("hot"); Text("关注").tag("follow")
            }.pickerStyle(.segmented).padding(.horizontal, 40).padding(.vertical, 6)
            .onChange(of: mode) { _, _ in Task { await reload() } }
            Divider()

            if loading && list.isEmpty { Spacer(); ProgressView(); Spacer() }
            else if let err, list.isEmpty { ContentUnavailableView("加载失败", systemImage: "wifi.slash", description: Text(err)) }
            else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(list) { card($0) }
                        if more { ProgressView().onAppear { Task { await loadMore() } } }
                    }.padding(16)
                }
            }
        }
        .sheet(isPresented: $showComposer) { composeView }
        .toolbar { ToolbarItem { Button { showComposer=true } label: { Image(systemName:"square.and.pencil") }.disabled(!net.isLoggedIn) } }
        .task { if net.isLoggedIn && list.isEmpty { await reload() } }
    }

    // MARK: 卡片

    func card(_ item: PosterItem) -> some View {
        Button { Task { await openDetail(item) } } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.anonymous == true ? "匿" : String((item.user?.nickname ?? "?").prefix(1)))
                        .font(.caption.bold()).frame(width:28,height:28)
                        .background(Circle().fill(item.anonymous == true ? Color.secondary.opacity(0.2) : Color.bitBlue.opacity(0.2)))
                    Text(item.anonymous == true ? "匿名者" : (item.user?.nickname ?? "用户")).font(.subheadline.weight(.medium))
                    Spacer(); Text(rt(item.update_time)).font(.caption2).foregroundStyle(.secondary)
                }
                if let t=item.title,!t.isEmpty { Text(t).font(.headline).lineLimit(1) }
                Text(item.text ?? "").font(.callout).lineLimit(4)
                HStack(spacing: 16) {
                    Label("\(item.like_num ?? 0)", systemImage:"heart")
                    Label("\(item.comment_num ?? 0)", systemImage:"bubble.right")
                    if let tags=item.tags,!tags.isEmpty {
                        Spacer(); ForEach(tags.prefix(3),id:\.self){Text("#\($0)").font(.caption2).foregroundStyle(.secondary)}
                    }
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }

    // MARK: 详情

    func detailView(_ d: PosterDetail) -> some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                HStack{Spacer();Button{detail=nil}label:{Image(systemName:"xmark.circle.fill").font(.title3).foregroundStyle(.secondary)}.buttonStyle(.plain)}
                HStack{
                    Text(String((d.user?.nickname ?? "?").prefix(1))).font(.title3).frame(width:36,height:36).background(Circle().fill(Color.bitBlue.opacity(0.2)))
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

                Divider()
                Text("评论").font(.headline)
                HStack{TextField("写评论...",text:$commentText).textFieldStyle(.roundedBorder)
                    Button("发送"){Task{await sendComment("poster\(d.id ?? 0)");commentText=""}}.buttonStyle(.borderedProminent).disabled(commentText.isEmpty)
                }
                if loadingComments{ProgressView()}
                else if comments.isEmpty{Text("暂无评论").font(.callout).foregroundStyle(.secondary)}
                else{ForEach(comments){commentRow($0)}}
            }.padding(20)
        }.frame(minWidth:420,minHeight:500)
        .task{await loadComments("poster\(d.id ?? 0)")}
    }

    func commentRow(_ c: CommentItem) -> some View {
        Group {
            VStack(alignment:.leading,spacing:4){
                HStack{Text(c.user?.nickname ?? "用户").font(.caption.bold());Spacer();Text(rt(c.create_time)).font(.caption2).foregroundStyle(.secondary)}
                Text(c.text ?? "").font(.callout)
                if let subs=c.sub{ForEach(subs){s in HStack{Text("↳").font(.caption2).foregroundStyle(.secondary);Text(s.user?.nickname ?? "").font(.caption.bold());Text(s.text ?? "").font(.caption)}.padding(.leading,16)}}
            }
            .padding(.vertical,4)
            Divider()
        }
    }

    // MARK: 发帖

    var composeView: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack{Spacer();Button("取消"){showComposer=false}.buttonStyle(.plain)}
            Text("发布话题").font(.title2.bold())
            TextField("标题",text:$cTitle).textFieldStyle(.roundedBorder)
            TextEditor(text:$cText).frame(minHeight:120).border(.secondary.opacity(0.2))
            HStack{Toggle("匿名",isOn:$cAnon);TextField("标签(逗号分隔)",text:$cTags).textFieldStyle(.roundedBorder)}
            Button{let tags=cTags.split(separator:",").map{String($0).trimmingCharacters(in:.whitespaces)}.filter{!$0.isEmpty}
                Task{do{try await net.createPoster(title:cTitle,text:cText,anonymous:cAnon,tags:tags)
                await MainActor.run{showComposer=false;cTitle="";cText="";cTags=""};await reload()}catch{print("err:\(error)")}}
            }label:{Text("发布").frame(maxWidth:.infinity)}.buttonStyle(.borderedProminent).disabled(cTitle.isEmpty||cText.isEmpty)
        }.padding(24).frame(width:400)
    }

    // MARK: Data

    func reload() async { loading=true;err=nil;page=0;more=true;await loadPage(0) }
    func loadMore() async { guard more,!loading else{return};await loadPage(page+1) }
    func loadPage(_ p: Int) async {
        do{let items=try await net.fetchPosters(page:p,mode:mode);await MainActor.run{if p==0{list=items}else{list.append(contentsOf:items)};more = !items.isEmpty;page=p;loading=false}}catch{await MainActor.run{if p==0{err=error.localizedDescription};loading=false}}
    }
    func openDetail(_ item: PosterItem) async {
        do { let d = try await net.fetchPosterDetail(id: item.identity)
            await MainActor.run {
                openDetailWindow(title: d.title ?? "帖子详情", width: 480, height: 560) {
                    posterDetailContent(d)
                }
            }
        } catch { print("detail:\(error)") }
    }

    // 独立窗口详情
    func posterDetailContent(_ d: PosterDetail) -> some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                HStack{
                    Text(String((d.user?.nickname ?? "?").prefix(1))).font(.title3).frame(width:36,height:36).background(Circle().fill(Color.blue.opacity(0.2)))
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
                Divider()
                Text("评论").font(.headline)
                HStack{TextField("写评论...",text:$commentText).textFieldStyle(.roundedBorder)
                    Button("发送"){Task{await postComment("poster\(d.id ?? 0)");commentText=""}}.buttonStyle(.borderedProminent).disabled(commentText.isEmpty)
                }
                if loadingComments{ProgressView()}
                else if comments.isEmpty{Text("暂无评论").font(.callout).foregroundStyle(.secondary)}
                else{ForEach(comments){c in 
                    VStack(alignment:.leading,spacing:4){
                        HStack{Text(c.user?.nickname ?? "用户").font(.caption.bold());Spacer();Text(rt(c.create_time)).font(.caption2).foregroundStyle(.secondary)}
                        Text(c.text ?? "").font(.callout)
                        if let subs=c.sub{ForEach(subs){s in HStack{Text("↳").foregroundStyle(.secondary);Text(s.user?.nickname ?? "").font(.caption.bold());Text(s.text ?? "").font(.caption)}.padding(.leading,16)}}
                    }.padding(.vertical,4);Divider()
                }}
            }.padding(20)
        }.task{await loadComments("poster\(d.id ?? 0)")}
    }

    func postComment(_ obj: String) async { 
        do { try await net.sendComment(obj: obj, text: commentText); await loadComments(obj) }
        catch { print("cmt:\(error)") }
    }

    func toggleLike(_ obj: String) async { do { let _ = try await net.toggleLike(obj: obj) } catch { print("like:\(error)") } }
    func loadComments(_ obj: String) async { loadingComments = true; do { let c = try await net.fetchComments(obj: obj); await MainActor.run { comments = c } } catch { print("cmt:\(error)") }; await MainActor.run { loadingComments = false } }
    func sendComment(_ obj: String) async { await postComment(obj) }

    func rt(_ s: String?) -> String { guard let s else{return""}; return String(s.prefix(10)) }
}

extension PosterDetail: Identifiable {}
