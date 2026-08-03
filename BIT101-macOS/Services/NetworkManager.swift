//
//  NetworkManager.swift
//  BIT101-macOS
//
//  Created by wyr on 2026/8/3.
//

import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var fakeCookie: String = UserDefaults.standard.string(forKey: "fakeCookie") ?? "" {
        didSet {
            UserDefaults.standard.set(fakeCookie, forKey: "fakeCookie")
            isLoggedIn = !fakeCookie.isEmpty
        }
    }
    
    @Published var isLoggedIn: Bool = false
    
    private init() {
        self.isLoggedIn = !fakeCookie.isEmpty
    }
    
    func login(studentID: String, password: String) async throws {
        // 模拟网络请求耗时 1 秒
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // 保存 fake-cookie，并标记为已登录
            self.fakeCookie = "fake_cookie_session_\(studentID)"
        }
    }
    
    func logout() {
        self.fakeCookie = ""
        self.isLoggedIn = false
    }
}
