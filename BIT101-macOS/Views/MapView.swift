//
//  MapView.swift - 校园地图
//
import SwiftUI
import MapKit

struct MapView: View {
    @State private var campus: Campus = .liangxiang
    @State private var search = ""
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.7306, longitude: 116.1714),
        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)))

    enum Campus: String, CaseIterable { case liangxiang = "良乡校区", zhongguancun = "中关村校区" }

    var filteredBuildings: [(name: String, coord: CLLocationCoordinate2D)] {
        let all = buildings(campus)
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.contains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("校区", selection: $campus) {
                    ForEach(Campus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 240)
                .onChange(of: campus) { _, c in
                    withAnimation { center(to: coord(c)) }
                    search = ""
                }

                GlassSearchField(placeholder: "搜索建筑", text: $search)
                    .frame(width: 180)
                .onChange(of: search) { _, new in
                    if let first = filteredBuildings.first {
                        withAnimation { center(to: first.coord) }
                    }
                }

                Button { locateMe() } label: { Image(systemName: "location.fill") }
                    .buttonStyle(.glassSecondary)
                    .help("定位到当前位置")
                Spacer()
            }
            .padding(.vertical, 8).padding(.horizontal, 12)

            Map(position: $position) {
                ForEach(filteredBuildings, id: \.name) { Marker($0.name, coordinate: $0.coord) }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .padding(10)

            if !search.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredBuildings, id: \.name) { b in
                            Text(b.name).font(.caption).padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().strokeBorder(.secondary.opacity(0.2), lineWidth: 1))
                        }
                    }.padding(.horizontal, 12).padding(.bottom, 8)
                }
            }
        }
        .navigationTitle("校园地图")
    }

    private func center(to c: CLLocationCoordinate2D) {
        position = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)))
    }

    private func locateMe() {
        // 系统会请求定位权限；由 Map 的 UserAnnotation 呈现
    }

    private func coord(_ c: Campus) -> CLLocationCoordinate2D {
        c == .liangxiang ? CLLocationCoordinate2D(latitude: 39.7306, longitude: 116.1714)
                         : CLLocationCoordinate2D(latitude: 39.9593, longitude: 116.3168)
    }

    private func buildings(_ c: Campus) -> [(name: String, coord: CLLocationCoordinate2D)] {
        if c == .liangxiang {
            return [
                ("综教A", 39.733193, 116.170654), ("综教B", 39.733184, 116.171878),
                ("理教楼", 39.730116, 116.171359), ("理学A", 39.728886, 116.171800),
                ("理学B", 39.729267, 116.171739), ("理学C", 39.729633, 116.171778),
                ("文萃楼", 39.732606, 116.174479), ("体育馆", 39.731844, 116.176544),
                ("图书馆", 39.7321, 116.1725), ("北食堂", 39.7342, 116.1720),
                ("南食堂", 39.7285, 116.1702), ("工训楼", 39.726286, 116.173760),
                ("校医院", 39.7298, 116.1752), ("学生服务中心", 39.7309, 116.1735),
                ("学术交流中心", 39.7339, 116.1698), ("行政楼", 39.7328, 116.1692),
                ("综合服务楼", 39.7316, 116.1769), ("北校区食堂", 39.7361, 116.1732),
            ].map { ($0.0, CLLocationCoordinate2D(latitude: $0.1, longitude: $0.2)) }
        } else {
            return [
                ("中心教学楼", 39.9593, 116.3168), ("信息科学实验楼", 39.9600, 116.3175),
                ("体育馆", 39.9610, 116.3158), ("主楼", 39.9590, 116.3156),
                ("图书馆", 39.9585, 116.3162), ("学生活动中心", 39.9606, 116.3172),
                ("国防科技园", 39.9602, 116.3148), ("校医院", 39.9580, 116.3152),
            ].map { ($0.0, CLLocationCoordinate2D(latitude: $0.1, longitude: $0.2)) }
        }
    }
}
