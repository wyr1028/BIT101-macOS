import SwiftUI

struct DDLView: View {
    @ObservedObject var net = NetworkManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.checkmark").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("DDL 提醒").font(.title2).foregroundStyle(.secondary)
            Text("此功能需要学校乐学系统认证\n请在浏览器中登录乐学后同步日历")
                .font(.callout).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            Button("打开乐学") {
                if let url = URL(string: "https://lexue.bit.edu.cn") {
                    NSWorkspace.shared.open(url)
                }
            }.buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

// EmptyRoomView 在独立文件中定义
// ExamView 在独立文件中定义
