//
//  LoginView.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var networkManager = NetworkManager.shared
    
    @State private var studentID: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            if networkManager.isLoggedIn {
                // MARK: - 已登录界面
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.green)
                    
                    Text("已成功登录 BIT101")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("凭证: \(networkManager.fakeCookie)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    
                    Button("退出登录", role: .destructive) {
                        networkManager.logout()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 40)
            } else {
                // MARK: - 未登录输入表单
                VStack(spacing: 8) {
                    Image(systemName: "graduationcap.circle.fill")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.accentColor)
                    
                    Text("登录 BIT101")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 10)
                
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("学号").font(.caption).foregroundStyle(.secondary)
                        TextField("例如: 312020xxxx", text: $studentID)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("密码").font(.caption).foregroundStyle(.secondary)
                        SecureField("统一身份认证密码", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .frame(width: 280)
                
                Button(action: handleLogin) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Text(isLoading ? "登录中..." : "登 录")
                            .fontWeight(.medium)
                    }
                    .frame(width: 280, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .disabled(studentID.isEmpty || password.isEmpty || isLoading)
            }
            Spacer()
        }
        .padding(.top, 40)
        .padding(.horizontal)
        .navigationTitle("个人中心")
    }
    
    private func handleLogin() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                try await NetworkManager.shared.login(studentID: studentID, password: password)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "登录失败，请重试"
                }
            }
        }
    }
}
