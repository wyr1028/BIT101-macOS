import SwiftUI

struct EmptyRoomView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var building = "综教"
    @State private var weekday = 1
    @State private var section = 1
    @State private var loading = false
    @State private var err: String?
    @State private var rooms: [NetworkManager.EmptyRoom] = []
    @State private var searched = false

    let buildings = ["综教", "理教", "文萃", "理学"]

    var body: some View {
        Group {
            if net.webvpnCookie.isEmpty {
                SchoolAuthRequiredView(title: "空教室查询")
            } else {
                VStack(spacing: 0) {
                    // 筛选栏（标题统一走标题栏）
                    HStack(spacing: 8) {
                        Picker("教学楼", selection: $building) {
                            ForEach(buildings, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu).controlSize(.small)
                        Picker("星期", selection: $weekday) {
                            ForEach(1...7, id: \.self) { Text("周\($0)").tag($0) }
                        }
                        .pickerStyle(.menu).controlSize(.small)
                        Picker("节次", selection: $section) {
                            ForEach(1...12, id: \.self) { Text("第\($0)节").tag($0) }
                        }
                        .pickerStyle(.menu).controlSize(.small)
                        Button {
                            Task { await search() }
                        } label: {
                            loading ? AnyView(ProgressView().controlSize(.small).frame(width: 56)) : AnyView(Text("查询").frame(width: 56))
                        }
                        .buttonStyle(.glass).disabled(loading)
                    }
                    .padding(.horizontal, Sp.l).padding(.vertical, Sp.m)
                    if let err {
                        Text(err).font(.caption).foregroundColor(.orange).multilineTextAlignment(.center)
                            .padding(.horizontal, Sp.l).padding(.top, 2)
                    }
                    GlassDivider(inset: Sp.l)

                    if !searched {
                        EmptyStateView(title: "选择条件后查询", icon: "door.left.hand.open", description: "查询指定教学楼、星期、节次的空闲教室")
                    } else if loading && rooms.isEmpty {
                        LoadingStateView()
                    } else if rooms.isEmpty {
                        EmptyStateView(title: "没有空闲教室", icon: "door.closed", description: "该时段没有符合条件的空闲教室")
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                                ForEach(rooms) { room in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(room.name).font(.callout.weight(.medium)).lineLimit(1)
                                        if !room.section.isEmpty {
                                            Text("可用节次：\(room.section)").font(.caption2).foregroundStyle(.secondary)
                                        }
                                        if !room.campus.isEmpty {
                                            Text(room.campus).font(.caption2).foregroundStyle(.tertiary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .glassSurface(10)
                                    .entrance()
                                    .overlay(alignment: .topTrailing) {
                                        FavoriteIconButton(id: "room\(room.name)")
                                            .padding(6)
                                    }
                                }
                            }.padding(Sp.l)
                        }
                    }
                }
            }
        }
        .navigationTitle("空教室")
    }

    func search() async {
        loading = true; err = nil; searched = true
        do {
            let list = try await net.fetchEmptyClassrooms(building: building, weekday: weekday, section: section)
            await MainActor.run { rooms = list; loading = false }
        } catch {
            await MainActor.run {
                err = error.localizedDescription
                rooms = []
                loading = false
            }
        }
    }
}
