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
            .frame(height: 160)
            .padding(.vertical, 8)

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
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.pdf]
    savePanel.nameFieldStringValue = "BIT101_成绩单.pdf"

    savePanel.begin { response in
        guard response == .OK, let url = savePanel.url else { return }
        let pdf = generateGradePDF(records: records)
        try? pdf.write(to: url)
    }
}

func generateGradePDF(records: [ScoreRecord]) -> Data {
    let pageWidth: CGFloat = 595
    let pageHeight: CGFloat = 842
    let margin: CGFloat = 40
    let colWidths: [CGFloat] = [60, 160, 50, 60, 60, 50, 100]
    let pdfData = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    guard let ctx = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: &mediaBox, nil) else {
        return Data()
    }

    for (i, record) in records.enumerated() {
        let yPos = pageHeight - margin - CGFloat(i + 1) * 22
        if yPos < margin { continue }
        if i == 0 {
            ctx.beginPDFPage(nil)
            ctx.setFillColor(NSColor.black.cgColor)
            let title = "BIT101 成绩单" as NSString
            title.draw(at: CGPoint(x: margin, y: pageHeight - margin), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 16)])
        }

        let vals = [record.number, record.name, String(format: "%.0f", record.credit),
                    record.scoreText, record.gpaText, record.isNormal ? "正常" : "补考",
                    semName(record.semester)]
        var x: CGFloat = margin
        for (j, val) in vals.enumerated() {
            let str = val as NSString
            str.draw(at: CGPoint(x: x, y: yPos), withAttributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: j == 1 ? NSColor.black : NSColor.darkGray
            ])
            x += colWidths[j]
        }

        if (i + 1) % 30 == 0 || i == records.count - 1 {
            ctx.endPDFPage()
            if i < records.count - 1 {
                ctx.beginPDFPage(nil)
            }
        }
    }

    ctx.closePDF()
    return pdfData as Data
}

func semName(_ s: String) -> String {
    let p = s.components(separatedBy: "-"); guard p.count >= 3 else { return s }
    return "\(String(p[0].suffix(2)))-\(String(p[1].suffix(2)))\(p[2]=="1" ? "秋" : "春")"
}
