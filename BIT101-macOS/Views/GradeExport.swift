//
//  GradeExport.swift - 成绩导出PDF & 趋势图
//
import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers

// MARK: 成绩趋势图

struct GradeTrendChart: View {
    let records: [ScoreRecord]
    @State private var hovered: SemesterData?

    struct SemesterData: Identifiable {
        let id: String; let semester: String; let avgScore: Double; let avgGPA: Double
    }

    var semesterData: [SemesterData] {
        let grouped = Dictionary(grouping: records.filter(\.valid)) { $0.semester }
        return grouped.compactMap { sem, recs -> SemesterData? in
            let tc = recs.reduce(0.0){$0+$1.credit}
            let as_ = tc > 0 ? recs.reduce(0.0){$0+$1.credit*$1.score}/tc : 0
            let ag = tc > 0 ? recs.reduce(0.0){$0+$1.credit*$1.gpa}/tc : 0
            return SemesterData(id: sem, semester: semName(sem), avgScore: as_, avgGPA: ag)
        }.sorted { $0.semester < $1.semester }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("成绩趋势").font(.headline)
            Chart(semesterData) { item in
                LineMark(x: .value("学期", item.semester), y: .value("均分", item.avgScore))
                    .foregroundStyle(.blue.gradient)
                PointMark(x: .value("学期", item.semester), y: .value("均分", item.avgScore))
                    .foregroundStyle(.blue)
            }
            .chartYScale(domain: 0...100)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Color.clear.contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let frame = proxy.plotFrame {
                                    let origin = geo[frame].origin
                                    let width = geo[frame].width
                                    let idx = Int((location.x - origin.x) / max(width, 1) * CGFloat(semesterData.count))
                                    hovered = (idx >= 0 && idx < semesterData.count) ? semesterData[idx] : nil
                                }
                            case .ended:
                                hovered = nil
                            }
                        }
                }
            }
            .frame(height: 160)
            .padding(.vertical, 8)

            if let hovered {
                Text("\(hovered.semester)：均分 \(String(format: "%.1f", hovered.avgScore)) · 绩点 \(String(format: "%.2f", hovered.avgGPA))")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, Sp.s).padding(.vertical, 3)
                    .background(Capsule().fill(.ultraThinMaterial))
            }

            Text("绩点趋势").font(.subheadline).foregroundStyle(.secondary)
            Chart(semesterData) { item in
                LineMark(x: .value("学期", item.semester), y: .value("绩点", item.avgGPA * 25))
                    .foregroundStyle(.orange.gradient)
                PointMark(x: .value("学期", item.semester), y: .value("绩点", item.avgGPA * 25))
                    .foregroundStyle(.orange)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 120)
        }
        .padding()
    }

    func semName(_ s: String) -> String {
        let p = s.components(separatedBy: "-"); guard p.count >= 3 else { return s }
        return "\(String(p[0].suffix(2)))-\(String(p[1].suffix(2)))\(p[2]=="1" ? "秋" : "春")"
    }
}

// MARK: PDF导出

func exportGradesToPDF(records: [ScoreRecord]) {
    guard !records.isEmpty else { return }
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.pdf]
    savePanel.nameFieldStringValue = "BIT101_成绩单.pdf"
    savePanel.canCreateDirectories = true

    // 本应用是菜单栏 App：窗口全关后 activation policy 会变成 .accessory，
    // 此时直接弹保存面板会不可见/挂起。先强制回到前台再弹面板。
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    Task { @MainActor in
        let response = await savePanel.begin()
        guard response == .OK, let url = savePanel.url else { return }
        let data = generateGradePDF(records: records)
        try? data.write(to: url, options: .atomic)
    }
}

func generateGradePDF(records: [ScoreRecord]) -> Data {
    let pageWidth: CGFloat = 595
    let pageHeight: CGFloat = 842
    let margin: CGFloat = 40
    let headerHeight: CGFloat = 64   // 标题 + 表头
    let rowHeight: CGFloat = 20
    let colWidths: [CGFloat] = [70, 165, 45, 55, 55, 45, 75]
    let colTitles = ["课程号", "课程名称", "学分", "成绩", "绩点", "类型", "学期"]

    let pdfData = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
          let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        return Data()
    }
    // 注意：这里用 CoreText 直接在 CGContext 上绘制文字，
    // 不要切换全局 NSGraphicsContext.current —— 在主线程 + SwiftUI 活跃时这样做会崩（EXC_BREAKPOINT）。
    func draw(_ text: String, at p: CGPoint, font: NSFont, color: NSColor) {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color,
            ]))
        ctx.textPosition = p
        CTLineDraw(line, ctx)
    }

    let titleFont = NSFont.boldSystemFont(ofSize: 16)
    let headFont = NSFont.boldSystemFont(ofSize: 10)
    let bodyFont = NSFont.systemFont(ofSize: 10)

    // 按学期分组：学期变化处插入学期表头行
    struct Row { var isSem = false; var sem = ""; var rec: ScoreRecord? = nil }
    var rows: [Row] = []
    var lastSem = ""
    for r in records {
        let sem = semName(r.semester)
        if sem != lastSem {
            rows.append(Row(isSem: true, sem: sem))
            lastSem = sem
        }
        rows.append(Row(rec: r))
    }
    if rows.isEmpty { rows.append(Row(isSem: true, sem: "全部")) }

    let rowsPerPage = max(1, Int((pageHeight - margin * 2 - headerHeight) / rowHeight))
    let pageCount = max(1, Int(ceil(Double(rows.count) / Double(rowsPerPage))))

    for page in 0..<pageCount {
        ctx.beginPDFPage(nil)

        // 标题
        draw("BIT101 成绩单", at: CGPoint(x: margin, y: pageHeight - margin - 8),
             font: titleFont, color: .black)

        // 表头
        let headY = pageHeight - margin - headerHeight + 10
        var hx: CGFloat = margin
        for (j, t) in colTitles.enumerated() {
            draw(t, at: CGPoint(x: hx, y: headY), font: headFont, color: .black)
            hx += colWidths[j]
        }

        // 分割线
        ctx.setStrokeColor(NSColor.lightGray.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: headY - 6))
        ctx.addLine(to: CGPoint(x: pageWidth - margin, y: headY - 6))
        ctx.strokePath()

        // 数据行（含学期分组表头）
        let start = page * rowsPerPage
        let end = min(start + rowsPerPage, rows.count)
        var rowIndex = 0
        for i in start..<end {
            let row = rows[i]
            let yPos = headY - CGFloat(rowIndex + 2) * rowHeight
            rowIndex += 1
            if yPos < margin { continue }
            if row.isSem {
                // 学期表头：浅色底 + 加粗
                ctx.setFillColor(NSColor.lightGray.withAlphaComponent(0.25).cgColor)
                ctx.fill(CGRect(x: margin, y: yPos - 10, width: pageWidth - margin * 2, height: rowHeight))
                draw(row.sem, at: CGPoint(x: margin, y: yPos), font: headFont, color: .black)
            } else if let r = row.rec {
                let vals = [r.number, r.name, String(format: "%.0f", r.credit),
                            r.scoreText, r.gpaText, r.isNormal ? "正常" : "补考/重修", ""]
                var x: CGFloat = margin
                for (j, val) in vals.enumerated() {
                    draw(val, at: CGPoint(x: x, y: yPos), font: bodyFont,
                         color: j == 1 ? .black : NSColor.darkGray)
                    x += colWidths[j]
                }
            }
        }

        ctx.endPDFPage()
    }

    ctx.closePDF()
    return pdfData as Data
}

func semName(_ s: String) -> String {
    let p = s.components(separatedBy: "-"); guard p.count >= 3 else { return s }
    return "\(String(p[0].suffix(2)))-\(String(p[1].suffix(2)))\(p[2]=="1" ? "秋" : "春")"
}
