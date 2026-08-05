import SwiftUI

struct ScoreRecord: Identifiable, Codable {
    let id = UUID()
    let number: String; let name: String; let credit: Double
    let score: Double; let scoreText: String
    let gpa: Double; let gpaText: String
    let semester: String; let isNormal: Bool; let valid: Bool
    let avgScore: Double?   // 全班平均分

    // id 不参与编解码（每次解码生成新 UUID 即可）
    enum CodingKeys: String, CodingKey {
        case number, name, credit, score, scoreText, gpa, gpaText, semester, isNormal, valid, avgScore
    }
}

struct GradeView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var all: [ScoreRecord] = []
    @State private var loading = false; @State private var err: String?
    @State private var sems: [String] = []; @State private var picked: Set<String> = []
    @State private var historyAvg: Double?; @State private var historyGPA: Double?
    @State private var showTrend = false
    @State private var showAuth = false

    private var shown: [ScoreRecord] { picked.isEmpty ? all : all.filter { picked.contains($0.semester) } }
    private var validRecords: [ScoreRecord] { shown.filter(\.valid) }

    var body: some View {
        Group {
            if loading && all.isEmpty { LoadingStateView() }
            else if let err, all.isEmpty { errorView(err) }
            else if all.isEmpty { emptyView }
            else {
                ScrollView {
                    VStack(spacing: 14) {
                        statsGrid
                        semesterBar
                        LazyVStack(spacing: 8) { ForEach(shown) { card($0) } }
                    }.padding(.horizontal, 20).padding(.vertical, 14)
                }
            }
        }
        .navigationTitle("成绩")
        .toolbar {
            ToolbarItem { Button { exportGradesToPDF(records: shown) } label: { Label("导出PDF", systemImage: "arrow.down.doc") } }
            ToolbarItem { Button { showTrend = true } label: { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") } }
            ToolbarItem { Button { Task { await load() } } label: { Label("刷新", systemImage: "arrow.clockwise") } }
        }
        .sheet(isPresented: $showTrend) { GradeTrendSheet(records: shown) }
        .sheet(isPresented: $showAuth) { SchoolAuthSheet() }
        .task { if net.isLoggedIn && all.isEmpty { await load() } }
        .onChange(of: picked) { _, _ in Task { await loadHistory() } }
    }

    // MARK: 统计（官方计算规则，含五级制与重修取最高）

    var statsGrid: some View {
        // 官方规则：同一课程编号只取最高成绩参与统计
        let vr = bestRecords(validRecords)
        let tc = vr.reduce(0.0){$0+$1.credit}
        let as_ = tc>0 ? vr.reduce(0.0){$0+$1.credit*$1.score}/tc : 0
        let ag = tc>0 ? vr.reduce(0.0){$0+$1.credit*$1.gpa}/tc : 0
        // 相对均分 = 个人加权均分 − 全班平均（历史均分）
        let diffAvg = historyAvg.map { as_ - $0 }

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(title: "加权均分", value: String(format:"%.2f", as_), icon: "chart.bar.fill", color: .blue)
                StatTile(title: "加权绩点", value: String(format:"%.2f", ag), icon: "star.fill", color: .orange)
                StatTile(title: "有效学分", value: String(format:"%.0f", tc), icon: "books.vertical.fill", color: .green)
            }
            HStack(spacing: 10) {
                StatTile(title: "历史均分", value: historyAvg.map { String(format:"%.2f", $0) } ?? "--",
                         icon: "person.3.fill", color: .purple)
                StatTile(title: "历史绩点", value: historyGPA.map { String(format:"%.2f", $0) } ?? "--",
                         icon: "rosette", color: .pink)
                StatTile(title: "相对均分", value: diffAvg.map { String(format:"%+.1f", $0) } ?? "--",
                         icon: "arrow.up.arrow.down", color: (diffAvg ?? 0) >= 0 ? .green : .orange)
            }
        }
    }

    // MARK: 学期筛选

    var semesterBar: some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {
                Text("学期筛选").font(.callout.weight(.medium))
                Spacer()
                if !picked.isEmpty { Button("清除"){picked=[]}.font(.caption).buttonStyle(.plain) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sems, id: \.self) { sem in
                        Chip(title: semName(sem), selected: picked.contains(sem)) {
                            if picked.contains(sem) { picked.remove(sem) } else { picked.insert(sem) }
                        }
                    }
                }
            }
        }
    }

    // MARK: 卡片

    func card(_ r: ScoreRecord) -> some View {
        HStack(spacing: 12) {
            // 成绩徽章
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(r.score > 0 ? scC(r.score).opacity(0.16) : Color.secondary.opacity(0.1))
                    .frame(width: 52, height: 44)
                VStack(spacing: 1) {
                    Text(r.scoreText)
                        .font(.system(.callout, design: .rounded).bold())
                        .foregroundColor(r.score > 0 ? scC(r.score) : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(r.gpaText)
                        .font(.system(size: 9, design: .rounded).weight(.medium))
                        .foregroundColor(r.gpa > 0 ? gpC(r.gpa) : .secondary)
                }
            }
            VStack(alignment:.leading,spacing:3) {
                Text(r.name).font(.system(.body,design:.rounded).bold()).lineLimit(2)
                HStack(spacing:6) {
                    if !r.number.isEmpty { Text(r.number).font(.caption2).foregroundStyle(.tertiary).monospaced() }
                    if !r.semester.isEmpty { Text(semName(r.semester)).font(.caption2).foregroundStyle(.tertiary) }
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
            HStack(spacing: 16) {
                col(String(format:"%.1f", r.credit), "学分")
                if let av = r.avgScore {
                    col(String(format:"%.0f", av), "班级均分", .purple)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .glassSurface(14)
        .hoverCard()
        .opacity(r.isNormal ? 1 : 0.45)
        .contextMenu {
            Button("复制成绩") { copyGrade(r) }
            Button("单独导出 PDF") { exportGradesToPDF(records: [r]) }
        }
        .onDrag {  // macOS 独占：把单科成绩拖成文本
            NSItemProvider(object: gradeText(r) as NSString)
        }
    }
    func col(_ v: String, _ l: String, _ c: Color = .primary) -> some View {
        VStack(spacing: 2) { Text(v).font(.system(.callout,design:.rounded).bold()).foregroundColor(c); Text(l).font(.caption2).foregroundStyle(.secondary) }
    }
    func gradeText(_ r: ScoreRecord) -> String {
        "\(r.name) \(r.scoreText) · 绩点\(r.gpaText) · 学分\(String(format: "%.0f", r.credit))"
    }
    func copyGrade(_ r: ScoreRecord) {
        let p = NSPasteboard.general
        p.clearContents()
        p.setString(gradeText(r), forType: .string)
    }
    func scC(_ s: Double) -> Color { s>=90 ? .green : s>=80 ? .blue : s>=70 ? .orange : s>=60 ? .yellow : .red }
    func gpC(_ g: Double) -> Color { g>=3.7 ? .green : g>=3.0 ? .blue : g>=2.0 ? .orange : .red }
    func semName(_ s: String) -> String {
        let p=s.components(separatedBy:"-"); guard p.count>=3 else {return s}
        return "\(String(p[0].suffix(2)))-\(String(p[1].suffix(2)))" + (p[2] == "1" ? "秋" : "春")
    }

    func errorView(_ m: String) -> some View {
        ErrorStateView(message: m,
                       retry: { Task { await load() } },
                       secondaryTitle: "重新认证",
                       secondaryAction: { showAuth = true })
    }
    var emptyView: some View {
        EmptyStateView(title: "暂无成绩", icon: "doc.text.magnifyingglass")
    }

    // MARK: 数据

    func load() async {
        loading=true;err=nil
        // 先读缓存
        if let cached = CacheStore.shared.read("grades_all_v2", as: [ScoreRecord].self), !cached.isEmpty {
            await MainActor.run { apply(cached); loading=false }
            await loadHistory()   // 缓存数据也计算历史平均
        }
        do {
            let scores = try await net.fetchScores()
            // 解析移到后台执行，避免大数组阻塞主线程
            let parsed = await Task.detached { parse(scores) }.value
            CacheStore.shared.write(parsed, key: "grades_all_v2")
            await MainActor.run { apply(parsed); loading=false }
            await loadHistory()
        } catch let e {
            await MainActor.run { err=e.localizedDescription; loading=false }
            await loadHistory()   // 拉取失败（如会话失效）时，仍基于缓存数据计算历史平均
        }
    }

    private func apply(_ parsed: [ScoreRecord]) {
        all=parsed; sems=Array(Set(parsed.map(\.semester))).sorted(); picked=[]
    }

    func loadHistory() async {
        // 历史平均 = 每门课「全班平均分」按学分加权
        // 优先用成绩里的 avgScore（平均分字段），缺的再查历届历史接口
        let nums = Array(Set(shown.filter(\.valid).map(\.number).filter{!$0.isEmpty}))
        let hist = await net.fetchCourseHistories(courseNumbers: nums)
        let vr = validRecords
        var ts = 0.0, tc = 0.0
        for r in vr {
            let a: Double
            if let s = r.avgScore, s > 0 {
                a = s
            } else if let h = hist[r.number], let s = h.avg_score, s > 0 {
                a = s
            } else {
                continue
            }
            ts += r.credit * a
            tc += r.credit
        }
        await MainActor.run {
            historyAvg = tc > 0 ? ts / tc : nil
            historyGPA = historyAvg.flatMap { $0 > 0 ? officialGPA(String(format: "%.2f", $0)) : nil }
        }
    }
}

// MARK: - 解析

/// 官方计算规则（《北京理工大学本科生学分绩点计算办法》，jwb.bit.edu.cn）：
/// 1. 计算范围：所有课程（百分制 + 五级制），同一课程编号有多条成绩（重修/补考/重考）时仅取最高分计入；
/// 2. 五级制成绩换算：优秀=95、良好=85、中等=75、及格=65、不及格=0；
/// 3. 课程绩点 = 4 − 3×(100−X)²/1600（60≤X≤100，四舍五入保留1位小数；X<60 记 0）；
///    五级制绩点：优秀=4.0、良好=3.6、中等=2.8、及格=1.7、不及格=0；
/// 4. 加权平均分 = Σ(学分×成绩)/Σ学分，加权绩点 = Σ(学分×绩点)/Σ学分。

/// 五级制 → 百分制
let scoreLevelMap: [String: Double] = ["优秀": 95, "良好": 85, "中等": 75, "及格": 65, "不及格": 0]
/// 五级制 → 绩点
let gpaLevelMap: [String: Double] = ["优秀": 4.0, "良好": 3.6, "中等": 2.8, "及格": 1.7, "不及格": 0]

/// 成绩文本 → 数值成绩（五级制换算，无法识别返回 -1）
func numericScore(_ raw: String) -> Double {
    let t = raw.trimmingCharacters(in: .whitespaces)
    if let v = scoreLevelMap[t] { return v }
    return Double(t) ?? -1
}

/// 成绩文本 → 官方课程绩点
func officialGPA(_ raw: String) -> Double {
    let t = raw.trimmingCharacters(in: .whitespaces)
    if let g = gpaLevelMap[t] { return g }
    let x = Double(t) ?? 0
    guard x >= 60 else { return 0 }
    let g = 4 - 3 * (100 - x) * (100 - x) / 1600
    return (g * 10).rounded() / 10   // 四舍五入保留 1 位小数
}

/// 同一课程编号只取最高成绩（官方：重修/补考/重考仅最高分计入）
func bestRecords(_ records: [ScoreRecord]) -> [ScoreRecord] {
    var best: [String: ScoreRecord] = [:]
    var fallback: [ScoreRecord] = []
    for r in records {
        if r.number.isEmpty { fallback.append(r); continue }
        if let e = best[r.number] {
            if r.score > e.score { best[r.number] = r }
        } else { best[r.number] = r }
    }
    return Array(best.values) + fallback
}

func parse(_ t: [[String]]) -> [ScoreRecord] {
    guard t.count>1 else {return[]}
    let h=t[0]
    let ci=cx(h,["课程编号","课程号","KCH"]),ni=cx(h,["课程名称","课程名","KCM"])
    let ri=cx(h,["学分","XF"]),si=cx(h,["成绩","总成绩","综合成绩","CJ","ZCJ"])
    let gi=cx(h,["绩点","GPA","JD","绩点系数"]),mi=cx(h,["开课学期","学期","XNXQ"])
    let ti=cx(h,["成绩标识","标识"]),ai=cx(h,["平均分"])
    var rec=[ScoreRecord]()
    for row in t.dropFirst() {
        func s(_ i: Int?) -> String { guard let i=i,i<row.count else{return""}; return row[i].trimmingCharacters(in:.whitespaces) }
        let cr=Double(s(ri)) ?? 0, rawScore=s(si)
        let sc = rawScore.isEmpty ? -1 : numericScore(rawScore)
        let gp: Double
        if let gi=gi { let xs=s(gi); gp=Double(xs) ?? -1 }
        else { gp=sc>=0 ? officialGPA(rawScore) : -1 }
        let tag = s(ti).lowercased()
        let ok = (!tag.contains("补考")) && (!tag.contains("重修")) && (!tag.contains("缓考"))
        // 显示原文（五级制显示"优秀/良好…"，数值保留原样避免小数被截断）
        let scText = rawScore.isEmpty ? "--" : rawScore
        let gpText=gp>=0 ? String(format:"%.1f",gp) : (gi != nil ? s(gi) : "--")
        let nm=s(ni); let av = Double(s(ai)).flatMap { $0 > 0 ? $0 : nil }
        // 有效 = 有学分且成绩可识别（含五级制）；重修/补考等仍计入统计，但同一课程只取最高分（见 bestRecords）
        rec.append(ScoreRecord(number:s(ci),name:nm.isEmpty ? (row.first ?? ""):nm,credit:cr,score:max(sc,0),scoreText:scText,gpa:max(gp,0),gpaText:gpText,semester:s(mi),isNormal:ok,valid:cr>0&&sc>=0,avgScore:av))
    }
    return rec
}
func cx(_ h: [String], _ kw: [String]) -> Int? { for k in kw { for(i,x) in h.enumerated() { if x.contains(k) { return i } } }; return nil }

// MARK: 趋势图Sheet

struct GradeTrendSheet: View {
    let records: [ScoreRecord]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); Button("关闭") { dismiss() }.buttonStyle(.glassSecondary) }
                .padding(Sp.m)
            GradeTrendChart(records: records)
            Spacer()
        }
        .frame(width: 600, height: 500)
        .glassSheetBackground()
    }
}
