//
//  MapView.swift - 校园地图
//
import SwiftUI
import MapKit

struct MapView: View {
    @State private var campus: Campus = .liangxiang
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.7306, longitude: 116.1714),
        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)))

    enum Campus: String, CaseIterable { case liangxiang = "良乡校区", zhongguancun = "中关村校区" }

    var body: some View {
        VStack(spacing: 0) {
            Picker("校区", selection: $campus) {
                ForEach(Campus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 300)
            .padding(.vertical, 8)
            .onChange(of: campus) { _, c in
                withAnimation { position = .region(MKCoordinateRegion(center: coord(c), span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))) }
            }
            Map(position: $position) {
                ForEach(buildings(campus), id: \.name) { Marker($0.name, coordinate: $0.coord) }
            }
            .mapStyle(.standard(elevation: .realistic))
            .padding(10)
        }
    }

    private func coord(_ c: Campus) -> CLLocationCoordinate2D {
        c == .liangxiang ? CLLocationCoordinate2D(latitude: 39.7306, longitude: 116.1714)
                         : CLLocationCoordinate2D(latitude: 39.9593, longitude: 116.3168)
    }
    private func buildings(_ c: Campus) -> [(name: String, coord: CLLocationCoordinate2D)] {
        c == .liangxiang
            ? [("综教A", 39.733193, 116.170654), ("综教B", 39.733184, 116.171878), ("理教楼", 39.730116, 116.171359),
               ("理学A", 39.728886, 116.171800), ("理学B", 39.729267, 116.171739), ("理学C", 39.729633, 116.171778),
               ("文萃楼", 39.732606, 116.174479), ("体育馆", 39.731844, 116.176544), ("图书馆", 39.7321, 116.1725),
               ("北食堂", 39.7342, 116.1720), ("南食堂", 39.7285, 116.1702), ("工训楼", 39.726286, 116.173760)]
                .map { ($0.0, CLLocationCoordinate2D(latitude: $0.1, longitude: $0.2)) }
            : [("中教楼", 39.9593, 116.3168), ("研究生楼", 39.9600, 116.3175), ("体育馆", 39.9610, 116.3158)]
                .map { ($0.0, CLLocationCoordinate2D(latitude: $0.1, longitude: $0.2)) }
    }
}
