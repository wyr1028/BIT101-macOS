//
//  CalendarImport.swift - 直接使用原始iCal文件导入
//
import AppKit

func importScheduleToCalendar(icalURL: String) {
    guard let url = URL(string: icalURL) else { return }

    URLSession.shared.dataTask(with: url) { data, _, error in
        guard let data = data, let icalString = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("BIT101_课表.ics")
            try? icalString.write(to: tmp, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tmp)
        }
    }.resume()
}
