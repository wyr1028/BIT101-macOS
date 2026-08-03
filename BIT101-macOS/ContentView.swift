//
//  ContentView.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import SwiftUI

struct ContentView: View {
    // 默认选中“我的课表”
    @State private var selectedTab: SidebarItem? = .schedule

    enum SidebarItem: Hashable {
        case schedule   // 课表
        case score      // 成绩
        case profile    // 个人/设置
    }

    var body: some View {
        NavigationSplitView {
            // 左侧边栏菜单
            List(selection: $selectedTab) {
                Label("我的课表", systemImage: "calendar")
                    .tag(SidebarItem.schedule)
                Label("成绩查询", systemImage: "graduationcap")
                    .tag(SidebarItem.score)
                Label("个人设置", systemImage: "person")
                    .tag(SidebarItem.profile)
            }
            .listStyle(.sidebar)
            .navigationTitle("BIT101")
        } detail: {
            // 右侧主显示区域
            switch selectedTab {
            case .schedule:
                ScheduleView()
            case .score:
                GradeView()
            case .profile:
                LoginView() // 👈 这里换成了刚才写好的登录界面！
            case .none:
                Text("请从左侧选择功能")
            }
        }
    }
}

#Preview {
    ContentView()
}
