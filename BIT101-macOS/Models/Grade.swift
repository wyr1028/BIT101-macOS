//
//  Grade.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import SwiftUI

/// 单门课程成绩模型
struct Grade: Identifiable, Hashable {
    let id = UUID()
    let courseName: String  // 课程名称
    let credit: Double      // 学分
    let score: Int          // 卷面分/最终成绩
    let gpa: Double         // 绩点
    let semester: String    // 学期（如 "2025-2026-1"）
}
