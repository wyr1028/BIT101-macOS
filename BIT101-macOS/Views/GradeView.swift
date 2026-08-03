//
//  GradeView.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import SwiftUI

struct GradeView: View {
    // 模拟成绩数据
    @State private var grades: [Grade] = [
        Grade(courseName: "高等数学 A(1)", credit: 5.0, score: 92, gpa: 4.0, semester: "2025-2026-1"),
        Grade(courseName: "大学物理 B(1)", credit: 3.0, score: 85, gpa: 3.5, semester: "2025-2026-1"),
        Grade(courseName: "程序设计基础", credit: 4.0, score: 95, gpa: 4.0, semester: "2025-2026-1"),
        Grade(courseName: "思想道德修养", credit: 2.0, score: 88, gpa: 3.7, semester: "2025-2026-1"),
        Grade(courseName: "线性代数", credit: 3.0, score: 78, gpa: 2.8, semester: "2024-2025-2")
    ]
    
    @State private var selectedSemester: String = "全选"
    private let semesters = ["全选", "2025-2026-1", "2024-2025-2"]
    
    // 根据选择的学期过滤成绩
    private var filteredGrades: [Grade] {
        if selectedSemester == "全选" {
            return grades
        } else {
            return grades.filter { $0.semester == selectedSemester }
        }
    }
    
    // 计算平均 GPA
    private var averageGPA: Double {
        guard !filteredGrades.isEmpty else { return 0.0 }
        let totalGPA = filteredGrades.reduce(0.0) { $0 + $1.gpa }
        return totalGPA / Double(filteredGrades.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部统计卡片与筛选菜单
            HStack {
                // 平均 GPA 卡片
                VStack(alignment: .leading, spacing: 4) {
                    Text("平均 GPA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", averageGPA))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
                
                // 学期筛选下拉框
                Picker("选择学期:", selection: $selectedSemester) {
                    ForEach(semesters, id: \.self) { semester in
                        Text(semester).tag(semester)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
            }
            .padding()
            
            Divider()
            
            // macOS 原生数据表格
            Table(filteredGrades) {
                TableColumn("课程名称", value: \.courseName)
                
                TableColumn("学期", value: \.semester)
                
                TableColumn("学分") { grade in
                    Text(String(format: "%.1f", grade.credit))
                }
                
                TableColumn("成绩") { grade in
                    Text("\(grade.score)")
                        .fontWeight(.semibold)
                        .foregroundColor(grade.score >= 90 ? .green : (grade.score < 60 ? .red : .primary))
                }
                
                TableColumn("绩点") { grade in
                    Text(String(format: "%.1f", grade.gpa))
                }
            }
        }
        .navigationTitle("成绩查询")
    }
}

#Preview {
    GradeView()
        .frame(width: 700, height: 500)
}
