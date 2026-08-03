//
//  Course.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import SwiftUI

/// 课程数据结构模型
struct Course: Identifiable, Hashable {
    let id = UUID()
    let name: String       // 课程名称
    let location: String   // 上课地点
    let teacher: String    // 教师姓名
    let day: Int           // 星期几 (1: 周一, 5: 周五)
    let startSection: Int  // 开始节次 (1 - 12)
    let duration: Int      // 持续节数 (例如 2 节课)
    let color: Color       // 课程卡片颜色
}
