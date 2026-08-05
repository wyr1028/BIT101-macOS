import SwiftUI

struct DDLView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var sessionOK: Bool?
    @State private var checking = false

    var body: some View {
        Group {
            if net.webvpnCookie.isEmpty {
                SchoolAuthRequiredView(title: "DDL 提醒")
            } else {
                VStack(spacing: 18) {
                    ModuleIcon(icon: "clock.badge.checkmark", color: .moduleSchedule, size: 56)
                    Text("DDL 提醒").font(Typo.header(.title2))
                    Text("课程作业、考试等 DDL 来自学校的乐学系统。\n完成认证后可在乐学中同步日历，这里将汇总你的 DDL。")
                        .font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    // 会话状态
                    HStack(spacing: 8) {
                        if checking {
                            ProgressView().controlSize(.small)
                            Text("正在检查教务会话…").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Circle().fill(sessionOK == true ? Color.green : Color.orange).frame(width: 8, height: 8)
                            Text(sessionOK == true ? "教务会话有效" : "教务会话未验证")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Button("打开乐学") {
                            if let url = URL(string: "https://lexue.bit.edu.cn") {
                                NSWorkspace.shared.open(url)
                            }
                        }.buttonStyle(.glassSecondary)

                        Button("重新认证") { openAuth = true }.buttonStyle(.glass)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassSurface()
            }
        }
        .sheet(isPresented: $openAuth) { SchoolAuthSheet() }
        .navigationTitle("DDL")
        .task { await check() }
    }

    @State private var openAuth = false

    func check() async {
        checking = true
        let ok = await net.verifyWebVPNSession()
        await MainActor.run { sessionOK = ok; checking = false }
    }
}
