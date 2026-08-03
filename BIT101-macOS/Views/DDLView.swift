//
//  DDLView.swift
//  BIT101-macOS
//

import SwiftUI

struct DDLView: View {
    var body: some View {
        ContentUnavailableView {
            Label("暂无待办事项", systemImage: "clock.badge.checkmark")
        } description: {
            Text("DDL提醒功能需要学校教务系统接口支持\n该功能暂未开放，敬请期待")
        }
        .padding(40)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
