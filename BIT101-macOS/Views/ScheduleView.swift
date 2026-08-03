//
//  ScheduleView.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import SwiftUI

struct ScheduleView: View {
    // 假数据：模拟 5 门课
    @State private var courses: [Course] = [
        Course(name: "高等数学 A", location: "理学楼 201", teacher: "张教授", day: 1, startSection: 1, duration: 2, color: .blue),
        Course(name: "大学物理 B", location: "综实楼 402", teacher: "李教授", day: 2, startSection: 3, duration: 2, color: .orange),
        Course(name: "程序设计基础 (C++)", location: "实验中心", teacher: "王老师", day: 3, startSection: 5, duration: 3, color: .green),
        Course(name: "思想道德修养", location: "教二楼 101", teacher: "赵老师", day: 4, startSection: 1, duration: 2, color: .purple),
        Course(name: "线性代数", location: "理学楼 105", teacher: "刘教授", day: 5, startSection: 7, duration: 2, color: .pink)
    ]
    
    private let weekDays = ["周一", "周二", "周三", "周四", "周五"]
    private let totalSections = 10
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部星期表头
            HStack(spacing: 6) {
                Text("节次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 45)
                
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Divider()
                .padding(.bottom, 4)
            
            // 课表网格主体
            ScrollView {
                HStack(alignment: .top, spacing: 6) {
                    // 左侧节次数字列
                    VStack(spacing: 6) {
                        ForEach(1...totalSections, id: \.self) { section in
                            Text("\(section)")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .frame(width: 45, height: 60)
                        }
                    }
                    
                    // 周一到周五 5 列网格
                    ForEach(1...5, id: \.self) { day in
                        ZStack(alignment: .top) {
                            // 空白灰色格子背景
                            VStack(spacing: 6) {
                                ForEach(1...totalSections, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.05))
                                        .frame(height: 60)
                                }
                            }
                            
                            // 渲染这天有的课程
                            ForEach(courses.filter { $0.day == day }) { course in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(2)
                                    Spacer()
                                    Text(course.location)
                                        .font(.system(size: 10))
                                    Text(course.teacher)
                                        .font(.system(size: 10))
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: CGFloat(course.duration) * 60 + CGFloat(course.duration - 1) * 6)
                                .background(course.color.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(course.color.opacity(0.8), lineWidth: 1.5)
                                )
                                .cornerRadius(8)
                                .offset(y: CGFloat(course.startSection - 1) * (60 + 6))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("我的课表")
    }
}
