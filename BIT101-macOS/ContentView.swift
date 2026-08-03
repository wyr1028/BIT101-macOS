//
//  ContentView.swift
//
import SwiftUI

struct ContentView: View {
    @State private var selected: Tab = .schedule

    enum Tab: String, CaseIterable {
        case schedule = "日程"
        case map = "地图"
        case gallery = "画廊"
        case study = "学业"
        case profile = "我的"

        var icon: String {
            switch self {
            case .schedule: "calendar"
            case .map: "map"
            case .gallery: "photo.on.rectangle.angled"
            case .study: "graduationcap"
            case .profile: "person.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 28)).foregroundColor(.accentColor)
                    Text("BIT101")
                        .font(.system(.title3, design: .rounded).bold())
                    Text("北理助手").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 16).padding(.bottom, 24)

                Divider().padding(.horizontal, 16)

                VStack(spacing: 4) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Button { selected = t } label: {
                            VStack(spacing: 6) {
                                Image(systemName: t.icon).font(.system(size: 22)).frame(height: 26)
                                Text(t.rawValue).font(.system(size: 11))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(selected == t ? RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.15)) : RoundedRectangle(cornerRadius: 12).fill(Color.clear))
                            .foregroundColor(selected == t ? .accentColor : .secondary)
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain).padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 8)

                Spacer()
            }
            .frame(minWidth: 80, idealWidth: 90)
            .background(.regularMaterial)
        } detail: {
            switch selected {
            case .schedule: ScheduleHub()
            case .map: MapView()
            case .gallery: GalleryHub()
            case .study: StudyHub()
            case .profile: ProfileView()
            }
        }
    }
}

// MARK: - 日程

struct ScheduleHub: View {
    @State private var sub = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sub) {
                Text("课表").tag(0); Text("DDL").tag(1); Text("空教室").tag(2)
            }.pickerStyle(.segmented).padding(.horizontal, 40).padding(.vertical, 8)
            Divider()
            Group { switch sub { case 0: ScheduleView(); case 1: DDLView(); default: EmptyRoomView() } }
        }
    }
}

// MARK: - 画廊

struct GalleryHub: View {
    @State private var sub = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sub) {
                Text("话题").tag(0); Text("文章").tag(1)
            }.pickerStyle(.segmented).padding(.horizontal, 50).padding(.vertical, 8)
            Divider()
            Group { if sub == 0 { TopicView() } else { ArticleView() } }
        }
    }
}

// MARK: - 学业

struct StudyHub: View {
    @State private var sub = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sub) {
                Text("成绩").tag(0); Text("课程评价").tag(1)
            }.pickerStyle(.segmented).padding(.horizontal, 50).padding(.vertical, 8)
            Divider()
            Group { if sub == 0 { GradeView() } else { CourseReviewView() } }
        }
    }
}

#Preview { ContentView() }
