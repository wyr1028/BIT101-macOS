import SwiftUI

struct ScoreRecord: Identifiable {
    let id = UUID()
    let number: String; let name: String; let credit: Double
    let score: Double; let scoreText: String
    let gpa: Double; let gpaText: String
    let semester: String; let isNormal: Bool; let valid: Bool
}

struct GradeView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var all: [ScoreRecord] = []
    @State private var loading = false; @State private var err: String?
    @State private var sems: [String] = []; @State private var picked: Set<String> = []
    @State private var historyAvg: Double?; @State private var historyGPA: Double?

    private var shown: [ScoreRecord] { picked.isEmpty ? all : all.filter { picked.contains($0.semester) } }
    private var validRecords: [ScoreRecord] { shown.filter(\.valid) }

    var body: some View {
        Group {
            if loading { ProgressView().frame(maxWidth:.infinity,maxHeight:.infinity) }
            else if let err, all.isEmpty { errorView(err) }
            else if all.isEmpty { emptyView }
            else {
                ScrollView {
                    VStack(spacing: 16) {
                        semesterBar
                        statsGrid
                        LazyVStack(spacing: 8) { ForEach(shown) { card($0) } }
                    }.padding(.horizontal, 24).padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("成绩")
        .task { if net.isLoggedIn && all.isEmpty { await load() } }
        .onChange(of: picked) { _, _ in Task { await loadHistory() } }
    }

    // MARK: 学期栏

    var semesterBar: some View {
        VStack(alignment:.leading,spacing:6) {
            HStack { Text("学期筛选").font(.callout.weight(.medium)); Spacer()
                if !picked.isEmpty { Button("清除"){picked=[]}.font(.caption).buttonStyle(.plain) }
            }
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:8) { ForEach(sems,id:\.self){ sem in
                    let sel = picked.contains(sem)
                    Button { if sel {picked.remove(sem)} else {picked.insert(sem)} } label: {
                        Text(semName(sem)).font(.caption).padding(.horizontal,12).padding(.vertical,6)
                            .background(Capsule().fill(sel ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial)))
                            .foregroundColor(sel ? .white : .primary)
                    }.buttonStyle(.plain)
                }}
            }
        }
    }

    // MARK: 统计

    var statsGrid: some View {
        let vr = validRecords
        let tc = vr.reduce(0.0){$0+$1.credit}
        let as_ = tc>0 ? vr.reduce(0.0){$0+$1.credit*$1.score}/tc : 0
        let ag = tc>0 ? vr.reduce(0.0){$0+$1.credit*$1.gpa}/tc : 0

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                tile("加权均分", String(format:"%.1f",as_), "chart.bar.fill", .blue)
                tile("加权绩点", String(format:"%.2f",ag), "star.fill", .orange)
                tile("有效学分", String(format:"%.0f",tc), "books.vertical.fill", .green)
            }
            if let ha = historyAvg {
                HStack(spacing: 10) {
                    tile("历史均分", String(format:"%.1f",ha), "person.3.fill", .purple)
                    tile("历史绩点", String(format:"%.2f",historyGPA ?? 0), "rosette", .pink)
                    tile("科目数", "\(vr.count)", "list.clipboard.fill", .teal)
                }
            }
        }
    }

    func tile(_ l: String, _ v: String, _ i: String, _ c: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: i).font(.title3).foregroundColor(c)
            Text(v).font(.system(.title2, design: .rounded).bold())
            Text(l).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: 卡片

    func card(_ r: ScoreRecord) -> some View {
        HStack(spacing: 0) {
            VStack(alignment:.leading,spacing:3) {
                Text(r.name).font(.system(.body,design:.rounded).bold()).lineLimit(2)
                HStack(spacing:6) {
                    if !r.number.isEmpty { Text(r.number).font(.caption2).foregroundStyle(.tertiary).monospaced() }
                    if !r.semester.isEmpty { Text(semName(r.semester)).font(.caption2).foregroundStyle(.tertiary) }
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
            Spacer()
            HStack(spacing: 16) {
                col(String(format:"%.0f",r.credit), "学分")
                col(r.scoreText, "成绩", r.score>0 ? scC(r.score) : .secondary)
                col(r.gpaText, "绩点", r.gpa>0 ? gpC(r.gpa) : .secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .opacity(r.isNormal ? 1 : 0.45)
    }
    func col(_ v: String, _ l: String, _ c: Color = .primary) -> some View {
        VStack(spacing: 2) { Text(v).font(.system(.title3,design:.rounded).bold()).foregroundColor(c); Text(l).font(.caption2).foregroundStyle(.secondary) }
    }
    func scC(_ s: Double) -> Color { s>=90 ? .green : s>=80 ? .blue : s>=70 ? .orange : s>=60 ? .yellow : .red }
    func gpC(_ g: Double) -> Color { g>=3.7 ? .green : g>=3.0 ? .blue : g>=2.0 ? .orange : .red }
    func semName(_ s: String) -> String {
        let p=s.components(separatedBy:"-"); guard p.count>=3 else {return s}
        return "\(String(p[0].suffix(2)))-\(String(p[1].suffix(2)))" + (p[2] == "1" ? "秋" : "春")
    }

    func errorView(_ m: String) -> some View {
        VStack(spacing:12) { Image(systemName:"exclamationmark.triangle.fill").font(.largeTitle).foregroundColor(.orange); Text(m).font(.callout); Button("重试"){Task{await load()}}.buttonStyle(.borderedProminent) }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    var emptyView: some View {
        ContentUnavailableView { Label("暂无成绩", systemImage:"doc.text.magnifyingglass") }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }

    // MARK: 数据

    func load() async {
        loading=true;err=nil
        do {
            let scores = try await net.fetchScores()
            let parsed = parse(scores)
            await MainActor.run { all=parsed; sems=Array(Set(parsed.map(\.semester))).sorted(); picked=[]; loading=false }
            await loadHistory()
        } catch let e { await MainActor.run { err=e.localizedDescription;loading=false } }
    }

    func loadHistory() async {
        let nums = Array(Set(shown.filter(\.valid).map(\.number).filter{!$0.isEmpty}))
        guard !nums.isEmpty else { await MainActor.run { historyAvg=nil;historyGPA=nil }; return }
        let hist = await net.fetchCourseHistories(courseNumbers: nums)
        let vr = validRecords
        var ts=0.0,tc=0.0
        for r in vr where !r.number.isEmpty {
            if let h=hist[r.number], let a=h.avg_score, a>0 { ts+=r.credit*a; tc+=r.credit }
        }
        await MainActor.run {
            historyAvg = tc>0 ? ts/tc : nil
            historyGPA = historyAvg.map { ($0/100)*4.0 }
        }
    }
}

// MARK: 解析

func parse(_ t: [[String]]) -> [ScoreRecord] {
    guard t.count>1 else {return[]}
    let h=t[0]
    let ci=cx(h,["课程编号","课程号","KCH"]),ni=cx(h,["课程名称","课程名","KCM"])
    let ri=cx(h,["学分","XF"]),si=cx(h,["成绩","总成绩","综合成绩","CJ","ZCJ"])
    let gi=cx(h,["绩点","GPA","JD","绩点系数"]),mi=cx(h,["开课学期","学期","XNXQ"])
    let ti=cx(h,["成绩标识","标识"])
    var rec=[ScoreRecord]()
    for row in t.dropFirst() {
        func s(_ i: Int?) -> String { guard let i=i,i<row.count else{return""}; return row[i].trimmingCharacters(in:.whitespaces) }
        let cr=Double(s(ri)) ?? 0, sc=Double(s(si)) ?? -1
        let gp: Double
        if let gi=gi { let xs=s(gi); gp=Double(xs) ?? -1 }
        else { gp=sc>=0 ? gpaCalc(sc) : -1 }
        let tag = s(ti).lowercased()
        let ok = (!tag.contains("补考")) && (!tag.contains("重修")) && (!tag.contains("缓考"))
        let scText=sc>=0 ? String(format:"%.0f",sc) : (s(si).isEmpty ? "--":s(si))
        let gpText=gp>=0 ? String(format:"%.1f",gp) : (gi != nil ? s(gi) : "--")
        let nm=s(ni)
        rec.append(ScoreRecord(number:s(ci),name:nm.isEmpty ? (row.first ?? ""):nm,credit:cr,score:max(sc,0),scoreText:scText,gpa:max(gp,0),gpaText:gpText,semester:s(mi),isNormal:ok,valid:cr>0&&ok&&sc>=0))
    }
    return rec
}
func cx(_ h: [String], _ kw: [String]) -> Int? { for k in kw { for(i,x) in h.enumerated() { if x.contains(k) { return i } } }; return nil }
func gpaCalc(_ s: Double) -> Double { if s>=90{4.0}else if s>=85{3.7}else if s>=82{3.3}else if s>=78{3.0}else if s>=75{2.7}else if s>=72{2.3}else if s>=68{2.0}else if s>=65{1.7}else if s>=62{1.3}else if s>=60{1.0}else{0} }
