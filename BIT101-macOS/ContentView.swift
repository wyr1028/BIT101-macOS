//
//  ContentView.swift - 应用壳层（液态玻璃 + 两级操作逻辑树）
//
//  操作逻辑树：
//    日程 ─┬─ 课表        （二级菜单置于左侧导航栏，前方小 padding 缩进）
//          ├─ 考试
//          ├─ 空教室
//          └─ DDL
//    地图 ── 校园地图
//    话廊 ─┬─ 话题
//          └─ 文章
//    学业 ─┬─ 成绩
//          └─ 课程评价
//    我的 ─┬─ 个人
//          └─ 消息
//
import SwiftUI

// MARK: - 页面（叶子节点）

enum Page: String, CaseIterable, Identifiable {
    case timetable = "课表"
    case exam = "考试"
    case emptyRoom = "空教室"
    case ddl = "DDL"
    case map = "校园地图"
    case topic = "话题"
    case paper = "文章"
    case grades = "成绩"
    case courses = "课程评价"
    case profile = "个人"
    case messages = "消息"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timetable: "calendar"
        case .exam: "pencil.and.list.clipboard"
        case .emptyRoom: "door.left.hand.open"
        case .ddl: "clock"
        case .map: "map"
        case .topic: "bubble.left.and.bubble.right"
        case .paper: "doc.richtext"
        case .grades: "chart.bar.doc.horizontal"
        case .courses: "star"
        case .profile: "person.crop.circle"
        case .messages: "envelope"
        }
    }

    var section: MainSection {
        switch self {
        case .timetable, .exam, .emptyRoom, .ddl: .schedule
        case .map: .map
        case .topic, .paper: .gallery
        case .grades, .courses: .score
        case .profile, .messages: .mine
        }
    }
}

// MARK: - 模块（父节点）

enum MainSection: String, CaseIterable, Identifiable {
    case schedule = "日程"
    case map = "地图"
    case gallery = "话廊"
    case score = "学业"
    case mine = "我的"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .schedule: "calendar"
        case .map: "map"
        case .gallery: "bubble.left.and.bubble.right"
        case .score: "chart.bar.doc.horizontal"
        case .mine: "person.crop.circle"
        }
    }

    var tint: Color {
        switch self {
        case .schedule: .moduleSchedule
        case .map: .moduleMap
        case .gallery: .moduleGallery
        case .score: .moduleScore
        case .mine: .moduleMine
        }
    }

    var pages: [Page] {
        switch self {
        case .schedule: [.timetable, .exam, .emptyRoom, .ddl]
        case .map: [.map]
        case .gallery: [.topic, .paper]
        case .score: [.grades, .courses]
        case .mine: [.profile, .messages]
        }
    }
}

// MARK: - 壳层

struct ContentView: View {
    @ObservedObject var net = NetworkManager.shared
    @State private var selection: Page? = .timetable
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var windowWidth: CGFloat = 1000

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar
                    .navigationSplitViewColumnWidth(min: 210, ideal: 234, max: 280)
            } detail: {
                // 主内容区整体铺液态玻璃背景（详情列默认不透明，需要自己垫玻璃）
                ZStack {
                    LiquidGlassBackground()
                    Group {
                        if let sel = selection {
                            pageView(for: sel)
                        } else {
                            ContentUnavailableView("选择一项", systemImage: "sidebar.left")
                        }
                    }
                }
            }
        }
        // 窄窗口自动收起侧边栏；宽回 900 自动展开
        .background(WindowWidthReader { width in
            windowWidth = width
            if width < 900 {
                if columnVisibility != .detailOnly { columnVisibility = .detailOnly }
            } else if columnVisibility == .detailOnly {
                columnVisibility = .all
            }
        })
        // 窗口过窄时隐藏标题栏自带的侧边栏切换按钮
        .hideSidebarToggle(windowWidth < 900)
        .onReceive(NotificationCenter.default.publisher(for: .openNavItem)) { note in
            handleDeepLink(note)
        }
        .onAppear {
            // 命令行深链：BIT101-macOS -openPage 成绩 （调试/快捷直达）
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-openPage"), i + 1 < args.count,
               let page = Page(rawValue: args[i + 1]) {
                selection = page
            }
        }
    }

    // MARK: 侧边栏（两级：模块 + 缩进二级菜单）

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                // 应用标识
                HStack(spacing: 10) {
                    ModuleIcon(icon: "books.vertical.fill", color: .bitOrange, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BIT101")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("北理助手").font(Typo.caption()).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, Sp.m)
                .textCase(nil)

                ForEach(Array(MainSection.allCases.enumerated()), id: \.element.id) { idx, sec in
                    // 模块之间的细分隔线
                    if idx > 0 {
                        GlassDivider(inset: Sp.s)
                            .padding(.vertical, 2)
                    }
                    // 模块（父节点）
                    HStack(spacing: 8) {
                        ModuleIcon(icon: sec.icon, color: sec.tint, size: 18)
                        Text(sec.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(sec.tint.opacity(0.9))
                        Spacer()
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .padding(.leading, 16)

                    // 二级菜单（叶子节点，前方小 padding 缩进）
                    ForEach(sec.pages) { page in
                        SidebarRow(page: page, tint: sec.tint)
                    }
                }

                // 快捷键提示
                Text("⌘1–5 切模块 · ⌘⌥M 浮动课表 · ⌘⇧B 菜单栏")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 14).padding(.top, 10)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial.opacity(0.7))
    }

    /// 侧边栏叶节点行：模块色图标 + hover 反馈（选中态由系统高亮提供）
    private struct SidebarRow: View {
        let page: Page
        let tint: Color
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 7) {
                Image(systemName: page.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(page.rawValue)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .padding(.leading, 32)
            .padding(.trailing, 12)
            .contentShape(Rectangle())
            .onHover { h in
                withAnimation(Anim.soft(Anim.quick)) { hovering = h }
            }
            .background {
                if hovering {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint.opacity(0.12))
                }
            }
            // 选中高亮适中收窄（非整行贴满、非小胶囊）
            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
            .tag(page)
        }
    }

    // MARK: 页面分发

    @ViewBuilder
    private func pageView(for page: Page) -> some View {
        switch page {
        case .timetable: ScheduleView()
        case .exam: ExamView()
        case .emptyRoom: EmptyRoomView()
        case .ddl: DDLView()
        case .map: MapView()
        case .topic: TopicView()
        case .paper: ArticleView()
        case .grades: GradeView()
        case .courses: CourseReviewView()
        case .profile: ProfileView()
        case .messages: MessagesView()
        }
    }

    // MARK: 深链（通知点击 → 打开对应页面）

    private func handleDeepLink(_ note: Notification) {
        guard let item = note.userInfo?["item"] as? String else { return }
        switch item {
        case "课表": selection = .timetable
        case "消息": selection = .messages
        default:
            if let page = Page(rawValue: item) { selection = page }
        }
    }
}
