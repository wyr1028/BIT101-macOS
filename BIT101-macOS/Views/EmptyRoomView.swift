//
//  EmptyRoomView.swift
//  BIT101-macOS
//

import SwiftUI

struct EmptyRoomView: View {
    var body: some View {
        ContentUnavailableView {
            Label("空教室查询", systemImage: "door.left.hand.open")
        } description: {
            Text("空教室查询功能即将上线，敬请期待")
        }
        .padding(40)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
