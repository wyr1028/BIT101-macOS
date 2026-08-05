//
//  StateViews.swift - 统一的状态视图（加载/错误/空）
//
import SwiftUI

/// 统一错误视图：渐变图标 + 信息 + 重试/次级按钮（玻璃卡居中）
struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Sp.m) {
            ModuleIcon(icon: "exclamationmark.triangle.fill", color: .orange, size: 46)
            Text(message)
                .font(Typo.body())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            if let secondaryTitle, let secondaryAction {
                HStack(spacing: Sp.s) {
                    Button(secondaryTitle) { secondaryAction() }.buttonStyle(.glassSecondary)
                    if let retry { Button("重试") { retry() }.buttonStyle(.glass) }
                }
            } else if let retry {
                Button("重试") { retry() }.buttonStyle(.glass)
            }
        }
        .padding(.vertical, Sp.l)
        .frame(maxWidth: 340)
        .glassCard(Radius.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 统一空状态视图（玻璃卡居中）
struct EmptyStateView: View {
    let title: String
    let icon: String
    var description: String? = nil

    var body: some View {
        VStack(spacing: Sp.m) {
            ModuleIcon(icon: icon, color: .secondary, size: 46)
            Text(title).font(Typo.body()).foregroundStyle(.primary)
            if let description {
                Text(description).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, Sp.l)
        .frame(maxWidth: 320)
        .glassCard(Radius.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 统一加载视图：玻璃卡 + 进度圈，居中
struct LoadingStateView: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .padding(Sp.l)
            .glassCard(Radius.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
