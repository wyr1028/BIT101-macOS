//
//  WindowHelper.swift
//
import SwiftUI
import AppKit

struct DetailWindow<Content: View>: View {
    let title: String
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(minWidth: width, minHeight: height)
            .onAppear {
                if let window = NSApp.keyWindow ?? NSApp.windows.last {
                    window.title = title
                    window.setContentSize(NSSize(width: width, height: height))
                }
            }
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
    win.center()

    let hosting = NSHostingView(rootView: DetailWindow(title: title, width: width, height: height, content: content))
    win.contentView = hosting
    win.makeKeyAndOrderFront(nil)
}
