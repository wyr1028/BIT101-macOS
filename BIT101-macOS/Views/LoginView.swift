//
//  LoginView.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import SwiftUI

struct LoginView: View {
    @State private var studentID: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部 Logo 与标题
            VStack(spacing: 8) {
                Image(systemName: "graduationcap.circle.fill")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.accentColor)
                
                Text("登录 BIT101")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("输入北京理工大学统一身份认证账号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)
            
            // 输入表单卡片
            VStack(alignment: .leading, spacing: 14) {
                // 学号输入框
                VStack(alignment: .leading, spacing: 4) {
                    Text("学号")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("例如: 312020xxxx", text: $studentID)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 密码输入框
                VStack(alignment: .leading, spacing: 4) {
                    Text("密码")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    SecureField("统一身份认证密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 错误提示文字
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .frame(width: 280)
            
            // 登录按钮
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
            
            Spacer()
        }
        .padding(.top, 40)
        .padding(.horizontal)
        .navigationTitle("个人中心")
    }
    
    // 点击登录触发的逻辑
    private func handleLogin() {
        errorMessage = nil
        isLoading = true
        
        // 模拟 1.5 秒网络请求耗时
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            // TODO: 调用 NetworkManager 完成真实 API 登录
        }
    }
}

#Preview {
    LoginView()
        .frame(width: 500, height: 400)
}
