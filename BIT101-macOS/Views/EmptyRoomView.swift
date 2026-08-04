import SwiftUI

struct EmptyRoomView: View {
    @State private var building = "综教"; @State private var weekday = 1
    @State private var section = 1; @State private var loading = false
    let buildings = ["综教", "理教", "文萃", "理学"]

    var body: some View {
        VStack(spacing: 16) {
            Text("空教室查询").font(.title3.bold())
            HStack(spacing: 12) {
                Picker("教学楼", selection: $building) {
                    ForEach(buildings, id: \.self) { Text($0).tag($0) }
                }.frame(width: 100)
                Picker("星期", selection: $weekday) {
                    ForEach(1...7, id: \.self) { Text("周\($0)").tag($0) }
                }.frame(width: 80)
                Picker("节次", selection: $section) {
                    ForEach(1...12, id: \.self) { Text("第\($0)节").tag($0) }
                }.frame(width: 90)
                Button("查询") { loading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { loading = false }
                }.buttonStyle(.borderedProminent).disabled(loading)
            }
            if loading { ProgressView() }
            else {
                Text("学校教务系统需独立认证\n请先在浏览器登录 webvpn.bit.edu.cn")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
