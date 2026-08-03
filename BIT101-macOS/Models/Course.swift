//
//  Course.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import SwiftUI

/// 课程数据结构模型（从 iCal 解析后使用）
struct Course: Identifiable, Hashable {
    let id = UUID()
    let name: String       // 课程名称
    let location: String   // 上课地点
    let teacher: String    // 教师姓名
    let day: Int           // 星期几 (1: 周日, 2: 周一, ...根据 Apple 的 Calendar weekday)
    let startSection: Int  // 开始节次 (1 - 13)
    let duration: Int      // 持续节数
    let weekDescription: String // 上课周次描述
    let color: Color       // 课程卡片颜色
    
    /// 从 iCalEvent 创建 Course
    static func from(iCalEvent event: iCalEvent, color: Color) -> Course {
        // Apple Calendar: weekday 1=周日, 2=周一...7=周六
        // 我们的 day 映射: 1=周一, 2=周二...5=周五
        let day: Int
        switch event.dayOfWeek {
        case 1: day = 7   // 周日 -> day 7
        case 2: day = 1   // 周一 -> day 1
        case 3: day = 2
        case 4: day = 3
        case 5: day = 4
        case 6: day = 5
        case 7: day = 6   // 周六 -> day 6
        default: day = event.dayOfWeek
        }
        
        return Course(
            name: event.summary,
            location: event.location,
            teacher: event.teacher,
            day: day,
            startSection: event.startSection,
            duration: event.duration,
            weekDescription: event.weekDescription,
            color: color
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id
    }
}

/// 课程颜色池（根据课程名 hash 分配稳定颜色）
struct CourseColorPool {
    static let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .mint, .indigo, .red, .cyan]
    
    static func color(for courseName: String) -> Color {
        var hash = 0
        for char in courseName.utf8 {
            hash = ((hash << 5) &- hash) &+ Int(char)
        }
        let index = abs(hash) % colors.count
        return colors[index]
    }
}
