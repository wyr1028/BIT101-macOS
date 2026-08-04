//
//  ContentView.swift
//
import SwiftUI

extension Color {
    static let bitOrange = Color(red: 1.0, green: 0.604, blue: 0.341)
    static let bitBlue   = Color(red: 0.0, green: 0.671, blue: 0.839)
}

struct ContentView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var selection: NavItem? = .schedule
    @State private var sidebarVisible = true

    enum NavItem: String, CaseIterable, Identifiable {
        case schedule="课表", ddl="DDL", exam="考试", emptyRoom="空教室"
        case map="校园地图"
        case grades="成绩", courses="课程评价"
        case gallery="话题", papers="文章"
        case messages="消息"
        case profile="个人"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .schedule:"calendar";case .ddl:"clock";case .exam:"pencil.and.list.clipboard"
            case .emptyRoom:"door.left.hand.open";case .map:"map"
            case .grades:"chart.bar.doc.horizontal";case .courses:"star"
            case .gallery:"bubble.left.and.bubble.right";case .papers:"doc.richtext"
            case .messages:"envelope";case .profile:"person.crop.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            if let sel = selection {
                detailView(for: sel)
                    .animation(.easeInOut(duration: 0.25), value: selection)
            } else {
                ContentUnavailableView("选择一项", systemImage: "sidebar.left")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                row(.schedule)
                row(.ddl)
                row(.exam)
                row(.emptyRoom)
            } header: {
                HStack(spacing: 10) {
                    Image(systemName: "books.vertical.fill").font(.title3).foregroundStyle(.blue.gradient)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("BIT101").font(.headline)
                        Text("北理助手").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 12)
                .textCase(nil)
            }
            Section("校园") { row(.map) }
            Section("学业") { row(.grades); row(.courses) }
            Section("社区") { row(.gallery); row(.papers) }
            Section("消息") { row(.messages) }
            Section("个人") { row(.profile) }
        }
        .listStyle(.sidebar)
    }

    private func row(_ item: NavItem) -> some View {
        Label(item.rawValue, systemImage: item.icon)
            .font(.system(size: 13))
            .padding(.vertical, 2)
            .padding(.leading, 4)
            .tag(item)
    }

    @ViewBuilder
    private func detailView(for item: NavItem) -> some View {
        switch item {
        case .schedule:  ScheduleView()
        case .ddl:       DDLView()
        case .exam:      ExamView()
        case .emptyRoom: EmptyRoomView()
        case .map:       MapView()
        case .grades:    GradeView()
        case .courses:   CourseReviewView()
        case .gallery:   TopicView()
        case .papers:    ArticleView()
        case .messages:  MessagesView()
        case .profile:   ProfileView()
        }
    }
}

struct ExamView: View {
    var body: some View {
        ContentUnavailableView { Label("考试安排", systemImage:"pencil.and.list.clipboard") }
    }
}
