import SwiftUI

// MARK: - 成绩记录

struct ScoreRecord: Identifiable {
    let id = UUID()
    let number: String; let name: String; let credit: Double
    let score: Double; let scoreText: String
    let gpa: Double; let gpaText: String
    let semester: String; let isNormal: Bool; let isValid: Bool
    let avg: Double?; let max: Double?
}

// MARK: - 成绩视图

struct GradeView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var all: [ScoreRecord] = []; @State private var sum: GradeSummary?
    @State private var loading = false; @State private var error: String?
    @State private var semesters: [String] = []; @State private var pickedSems: Set<String> = []

    private var shown: [ScoreRecord] {
        pickedSems.isEmpty ? all : all.filter { pickedSems.contains($0.semester) }
    }

    var body: some View {
        Group {
            if loading { ProgressView().frame(maxWidth:.infinity,maxHeight:.infinity) }
            else if let error, all.isEmpty { errorView(error) }
            else if all.isEmpty { emptyView }
            else { mainContent }
        }
        .task { if net.isLoggedIn && all.isEmpty { await load() } }
        .onChange(of: pickedSems) { _, _ in sum = calculateSummary(parted: shown) }
    }

    private var mainContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    semesterBar.padding(.top, 12)
                    if let sum { summaryPanel(sum) }
                    LazyVStack(spacing: 8) { ForEach(shown) { card($0) } }
                }
                .padding(.horizontal, 24).padding(.bottom, 28)
            }
        }
    }

    // MARK: 学期筛选

    private var semesterBar: some View {
        VStack(alignment:.leading,spacing:8){
            HStack{
                Text("学期筛选").font(.callout.weight(.medium)); Spacer()
                if !pickedSems.isEmpty { Button("清除"){pickedSems=[]}.font(.caption).buttonStyle(.plain).foregroundColor(.accentColor)}
            }
            ScrollView(.horizontal,showsIndicators:false){
                HStack(spacing:8){ ForEach(semesters,id:\.self){ (sem: String) in
                    let sel = pickedSems.contains(sem)
                    Button{ if sel {pickedSems.remove(sem)}else{pickedSems.insert(sem)} } label: {
                        HStack(spacing:4){
                            Text(semName(sem)).font(.caption)
                            if sel { Image(systemName:"checkmark").font(.system(size:9,weight:.bold)) }
                        }
                        .padding(.horizontal,12).padding(.vertical,7)
                        .foregroundStyle(sel ? .white : .primary)
                        .glassEffect(sel ? .regular.tint(Color.accentColor).interactive() : .regular.interactive(), in: Capsule())
                    }.buttonStyle(.plain)
                }}
            }
        }
    }

    private func semName(_ s:String)->String{
        let p=s.components(separatedBy:"-"); guard p.count>=3 else {return s}
        let num = p[2]; let season = num == "1" ? "秋" : "春"
        return "\(String(p[0].suffix(2)))-\(String(p[1].suffix(2))) \(season)"
    }

    // MARK: 汇总

    private func summaryPanel(_ s:GradeSummary)->some View{
        VStack(spacing:10){
            HStack(spacing:10){
                tile("加权均分",String(format:"%.1f",s.totalAvgScore),"chart.bar.fill",.blue)
                tile("加权绩点",String(format:"%.2f",s.totalGPA),"star.fill",.orange)
                tile("有效学分",String(format:"%.0f",s.totalCredits),"books.vertical.fill",.green)
            }
            if let gs=s.globalAvgScore{
                HStack(spacing:10){
                    tile("历史均分",String(format:"%.1f",gs),"person.3.fill",.purple)
                    tile("历史绩点",String(format:"%.2f",s.globalAvgGPA ?? 0),"rosette",.pink)
                    tile("科目数","\(s.courseCount)","list.clipboard.fill",.teal)
                }
            }
        }
    }

    private func tile(_ l:String,_ v:String,_ i:String,_ c:Color)->some View{
        VStack(spacing:6){
            Image(systemName:i).font(.title3).foregroundColor(c)
            Text(v).font(.system(.title2,design:.rounded).bold())
            Text(l).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth:.infinity).padding(.vertical,14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: 成绩卡片

    private func card(_ r:ScoreRecord)->some View{
        HStack(spacing:0){
            VStack(alignment:.leading,spacing:4){
                Text(r.name).font(.system(.body,design:.rounded).bold()).lineLimit(2)
                HStack(spacing:8){
                    if !r.number.isEmpty{Text(r.number).font(.caption2).foregroundStyle(.tertiary).monospaced()}
                    if !r.semester.isEmpty{Text(semName(r.semester)).font(.caption2).foregroundStyle(.tertiary)}
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
            Spacer()
            HStack(spacing:18){
                col(String(format:"%.0f",r.credit),"学分")
                col(r.scoreText,"成绩",r.score>0 ? scColor(r.score):.secondary)
                col(r.gpaText,"绩点",r.gpa>0 ? gpColor(r.gpa):.secondary)
            }
            if let a=r.avg{ col(String(format:"%.0f",a),"均分",.purple).padding(.leading,6) }
        }
        .padding(.horizontal,18).padding(.vertical,13)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .opacity(r.isNormal ? 1:0.45)
    }

    private func col(_ v:String,_ l:String,_ c:Color = .primary)->some View{
        VStack(spacing:3){ Text(v).font(.system(.title3,design:.rounded).bold()).foregroundColor(c); Text(l).font(.caption2).foregroundStyle(.secondary) }
    }
    private func scColor(_ s:Double)->Color{ s>=90 ? .green : s>=80 ? .blue : s>=70 ? .orange : s>=60 ? .yellow : .red }
    private func gpColor(_ g:Double)->Color{ g>=3.7 ? .green : g>=3.0 ? .blue : g>=2.0 ? .orange : .red }

    // MARK: 状态视图

    private func errorView(_ msg:String)->some View{
        VStack(spacing:12){
            Image(systemName:"exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange)
            Text(msg).font(.callout).multilineTextAlignment(.center)
            Button("重试"){Task{await load()}}.buttonStyle(.glassProminent).disabled(!net.isLoggedIn)
        }
        .padding(40)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    private var emptyView:some View{
        ContentUnavailableView{Label("暂无成绩",systemImage:"doc.text.magnifyingglass")}
            .frame(maxWidth:.infinity,maxHeight:.infinity)
    }

    // MARK: 数据

    private func load() async{
        loading=true;error=nil
        do{
            let scores=try await net.fetchScores()
            let parsed=parse(scores)
            await MainActor.run{all=parsed;semesters=Array(Set(parsed.map(\.semester))).sorted();pickedSems=[];sum=calcSummary(parsed);loading=false}
        }catch let e{await MainActor.run{error=e.localizedDescription;loading=false}}
    }

    private func calcSummary(_ shown:[ScoreRecord])->GradeSummary{calculateSummary(parted:shown)}
}

// MARK: - 解析

private func parse(_ t:[[String]])->[ScoreRecord]{
    guard t.count>1 else{return[]}
    let h=t[0]
    let ci=col(h,["课程编号","课程号","KCH"]),ni=col(h,["课程名称","课程名","KCM"])
    let ri=col(h,["学分","XF"]),si=col(h,["成绩","总成绩","综合成绩","CJ","ZCJ"])
    let gi=col(h,["绩点","GPA","JD","绩点系数","获得绩点"]),mi=col(h,["开课学期","学期","XNXQ"])
    let ti=col(h,["成绩标识","标识"]),ai=col(h,["平均分"]),xi=col(h,["最高分"])
    var rec:[ScoreRecord]=[]
    for row in t.dropFirst(){
        func s(_ i:Int?)->String{guard let i=i,i<row.count else{return""};return row[i].trimmingCharacters(in:.whitespaces)}
        let cr=Double(s(ri)) ?? 0,sc=Double(s(si)) ?? -1
        let gp:Double
        if let gi=gi{let xs=s(gi);gp=Double(xs) ?? -1}
        else{gp=sc>=0 ? scoreToGPA(sc) : -1}
        let tag = s(ti).lowercased()
        let ok = !tag.contains("补考") && !tag.contains("重修") && !tag.contains("缓考")
        let scText=sc>=0 ? String(format:"%.0f",sc):(s(si).isEmpty ? "--":s(si))
        let gpText=gp>=0 ? String(format:"%.1f",gp):(gi != nil ? s(gi):"--")
        let name=s(ni);let sem=s(mi)
        let av = Double(s(ai)).flatMap { $0 > 0 ? $0 : nil }
        let mx = Double(s(xi)).flatMap { $0 > 0 ? $0 : nil }
        rec.append(ScoreRecord(number:s(ci),name:name.isEmpty ? (row.first ?? ""):name,credit:cr,score:max(sc,0),scoreText:scText,gpa:max(gp,0),gpaText:gpText,semester:sem,isNormal:ok,isValid:cr>0&&ok&&sc>=0,avg:av,max:mx))
    }
    return rec
}

private func col(_ h:[String],_ kw:[String])->Int?{for k in kw{for(i,x)in h.enumerated(){if x.contains(k){return i}}};return nil}

func scoreToGPA(_ s:Double)->Double{
    if s>=90{return 4.0};if s>=85{return 3.7};if s>=82{return 3.3};if s>=78{return 3.0};if s>=75{return 2.7};if s>=72{return 2.3};if s>=68{return 2.0};if s>=65{return 1.7};if s>=62{return 1.3};if s>=60{return 1.0};return 0
}

func calculateSummary(parted vr:[ScoreRecord])->GradeSummary{
    let v=vr.filter(\.isValid);guard !v.isEmpty else{return GradeSummary(totalAvgScore:0,totalGPA:0,totalCredits:0,courseCount:0,globalAvgScore:nil,globalAvgGPA:nil)}
    let ws=v.reduce(0.0){$0+$1.credit*$1.score};let tc=v.reduce(0.0){$0+$1.credit}
    let as_=tc>0 ? ws/tc : 0
    let wg=v.reduce(0.0){$0+$1.credit*$1.gpa};let ag=tc>0 ? wg/tc : 0
    let va=v.filter{$0.avg != nil}
    let gs:Double?,gg:Double?
    if !va.isEmpty{let ts=va.reduce(0.0){$0+$1.credit*$1.avg!};let tcr=va.reduce(0.0){$0+$1.credit};gs=tcr>0 ? ts/tcr:nil;gg=gs.map{($0/100)*4.0}}else{gs=nil;gg=nil}
    return GradeSummary(totalAvgScore:as_,totalGPA:ag,totalCredits:tc,courseCount:v.count,globalAvgScore:gs,globalAvgGPA:gg)
}
