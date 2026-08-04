import SwiftUI

struct ArticleView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var papers: [PaperItem] = []
    @State private var loading = false; @State private var err: String?
    @State private var page = 0; @State private var more = true
    @State private var detailPaper: PaperDetail?; @State private var comments: [CommentItem] = []
    @State private var loadingComments = false; @State private var commentText = ""

    var body: some View {
        Group {
            if loading && papers.isEmpty { ProgressView().frame(maxWidth:.infinity,maxHeight:.infinity) }
            else if let err, papers.isEmpty { ContentUnavailableView("加载失败", systemImage:"wifi.slash", description:Text(err)) }
            else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(papers) { paperRow($0) }
                        if more { ProgressView().onAppear{Task{await loadMore()}} }
                    }.padding(16)
                }
            }
        }
        .sheet(item: $detailPaper) { detailSheet($0) }
        .task { await reload() }
    }

    func paperRow(_ item: PaperItem) -> some View {
        Button { Task { await openDetail(item) } } label: {
            VStack(alignment:.leading,spacing:8) {
                Text(item.title ?? "无标题").font(.headline).lineLimit(1)
                Text(item.intro ?? "").font(.callout).lineLimit(3).foregroundStyle(.secondary)
                HStack(spacing:16) {
                    Label("\(item.like_num ?? 0)",systemImage:"heart")
                    Label("\(item.comment_num ?? 0)",systemImage:"bubble.right")
                    Spacer(); Text(rt(item.update_time)).font(.caption2).foregroundStyle(.secondary)
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(14)
            .background(.regularMaterial, in:RoundedRectangle(cornerRadius:14))
            .contentShape(RoundedRectangle(cornerRadius:14))
        }.buttonStyle(.plain)
    }

    func detailSheet(_ d: PaperDetail) -> some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                HStack{Spacer();Button{detailPaper=nil}label:{Image(systemName:"xmark.circle.fill").font(.title3).foregroundStyle(.secondary)}.buttonStyle(.plain)}
                Text(d.title ?? "").font(.title2.bold())
                if let u = d.update_user {
                    HStack(spacing:8) {
                        Text(String(u.nickname?.prefix(1) ?? "?")).font(.headline).frame(width:32,height:32).background(Circle().fill(Color.bitBlue.opacity(0.2)))
                        Text(u.nickname ?? "用户").font(.subheadline)
                    }
                }

                // 使用EditorJS渲染器
                if let content = d.content, let parsed = parseEditorJS(content) {
                    EditorJSRenderer(content: parsed)
                } else {
                    Text(d.content ?? d.intro ?? "").font(.body)
                }

                HStack(spacing:16) {
                    Label("\(d.like_num ?? 0)",systemImage:(d.like ?? false) ? "heart.fill":"heart").foregroundColor(d.like == true ? .red:.secondary)
                    Label("\(d.comment_num ?? 0) 评论",systemImage:"bubble.right")
                    Spacer()
                }.font(.callout).foregroundStyle(.secondary)

                Divider()

                HStack{TextField("写评论...",text:$commentText).textFieldStyle(.roundedBorder)
                    Button("发送"){Task{await postComment("paper\(d.id ?? 0)");commentText=""}}.buttonStyle(.borderedProminent).disabled(commentText.isEmpty)
                }

                if loadingComments{ProgressView()}
                else if comments.isEmpty{Text("暂无评论").font(.callout).foregroundStyle(.secondary)}
                else{ForEach(comments){c in VStack(alignment:.leading,spacing:4){HStack{Text(c.user?.nickname ?? "用户").font(.caption.bold());Spacer();Text(rt(c.create_time)).font(.caption2).foregroundStyle(.secondary)};Text(c.text ?? "").font(.callout)}.padding(.vertical,4);Divider()}}
            }.padding(20)
        }.frame(minWidth:420,minHeight:500)
        .task{await loadComments("paper\(d.id ?? 0)")}
    }

    func reload() async { loading=true;err=nil;page=0;more=true;await loadPage(0) }
    func loadMore() async { guard more,!loading else{return};await loadPage(page+1) }
    func loadPage(_ p: Int) async {
        do{let items=try await net.fetchPapers(page:p);await MainActor.run{if p==0{papers=items}else{papers.append(contentsOf:items)};more = !items.isEmpty;page=p;loading=false}}catch{await MainActor.run{if p==0{err=error.localizedDescription};loading=false}}
    }
    func openDetail(_ item: PaperItem) async { do{let d=try await net.fetchPaperDetail(id:item.identity);await MainActor.run{detailPaper=d}}catch{print("detail:\(error)")} }
    func loadComments(_ obj: String) async { loadingComments=true;do{let c=try await net.fetchComments(obj:obj);await MainActor.run{comments=c}}catch{print("cmt:\(error)")};await MainActor.run{loadingComments=false} }
    func postComment(_ obj: String) async { do{try await net.sendComment(obj:obj,text:commentText);await loadComments(obj)}catch{print("cmt:\(error)")} }
    func rt(_ s: String?) -> String { guard let s else{return""}; return String(s.prefix(10)) }
}

extension PaperDetail: Identifiable {}
