//
//  WindowHelper.swift
//
import SwiftUI
import AppKit

struct DetailWindow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        // 填满窗口（不设固定最小宽，避免窗口缩小时内容溢出）
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

func openDetailWindow<Content: View>(title: String, width: CGFloat = 480, height: CGFloat = 560, @ViewBuilder content: @escaping () -> Content) {
    let win = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered, defer: false
    )
    win.title = title
    win.isReleasedWhenClosed = false
    win.titlebarAppearsTransparent = true   // 透明标题栏，玻璃延伸上去更精致
    win.setContentSize(NSSize(width: width, height: height))
    // 最小可调尺寸：防止缩得过窄导致内容溢出窗口被裁切
    win.contentMinSize = NSSize(width: 440, height: 560)
    win.center()

    let hosting = NSHostingView(rootView: DetailWindow(content: content))
    hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
    hosting.autoresizingMask = [.width, .height]
    win.contentView = hosting
    win.makeKeyAndOrderFront(nil)
}
