//
//  SchoolAuthView.swift - 学校统一身份认证（WKWebView 交互式登录）
//
// 学校 SSO 目前有 USTC 风控验证码，纯 API 无法自动登录。
// 这里用 WKWebView 加载学校登录页，让用户交互式登录（验证码在真实浏览器内核中解决），
// 完成后从 WebView 的 cookie 存储中提取认证后的 wengine_vpn_ticketwebvpn_bit_edu_cn 会话 cookie。
//
import SwiftUI
import WebKit

let schoolLoginURL = URL(string: "https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421e3e44ed225397c1e7b0c9ce29b5b/cas/login?service=https%3A%2F%2Fwebvpn.bit.edu.cn%2Flogin%3Fcas_login%3Dtrue")!

final class SchoolAuthCoordinator: NSObject, WKUIDelegate {
    var onCookieFound: ((String) -> Void)?
    var onFinish: (() -> Void)?
    var cookieNames: Set<String> = ["wengine_vpn_ticketwebvpn_bit_edu_cn"]
    weak var webView: WKWebView?

    init(onCookieFound: @escaping (String) -> Void, onFinish: @escaping () -> Void) {
        self.onCookieFound = onCookieFound
        self.onFinish = onFinish
    }

    // MARK: WKUIDelegate —— wengine 会通过 window.open / 新窗口跳转，必须支持，否则报“禁止跨域访问”
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // 把 target=_blank 的跳转放到当前 webview 继续，避免被拦截
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func startMonitoring() {
        // 轮询 cookie 存储，直到拿到认证后的会话 cookie
        pollCookies()
    }

    private func pollCookies() {
        guard let store = webView?.configuration.websiteDataStore.httpCookieStore else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.pollCookies() }
            return
        }
        store.getAllCookies { [weak self] cookies in
            guard let self else { return }
            for cookie in cookies where self.cookieNames.contains(cookie.name) {
                if !cookie.value.isEmpty, cookie.value.count > 10 {
                    self.onCookieFound?("\(cookie.name)=\(cookie.value)")
                    self.onFinish?()
                    return
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.pollCookies() }
        }
    }
}

struct SchoolAuthWebView: NSViewRepresentable {
    let onCookieFound: (String) -> Void
    let onFinish: () -> Void

    func makeCoordinator() -> SchoolAuthCoordinator {
        SchoolAuthCoordinator(onCookieFound: onCookieFound, onFinish: onFinish)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // 持久化 cookie，与浏览器一致
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // 使用桌面浏览器 UA，避免学校系统对非浏览器环境做限制
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        context.coordinator.webView = webView
        let request = URLRequest(url: schoolLoginURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 30)
        webView.load(request)
        let coordinator = context.coordinator
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak coordinator] in
            coordinator?.startMonitoring()
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

extension SchoolAuthCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 页面加载完成时检查一次 cookie
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            for cookie in cookies where self.cookieNames.contains(cookie.name) {
                if !cookie.value.isEmpty, cookie.value.count > 10 {
                    self.onCookieFound?("\(cookie.name)=\(cookie.value)")
                    self.onFinish?()
                    return
                }
            }
        }
    }
}

/// 学校授权弹窗：显示 WKWebView 让用户登录学校系统
struct SchoolAuthSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var net = NetworkManager.shared
    @State private var result: String?
    @State private var done = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("学校统一身份认证", systemImage: "building.2.fill")
                    .font(.headline)
                Spacer()
                Button("关闭") { dismiss() }.buttonStyle(.glassSecondary)
                Button("完成") { dismiss() }.buttonStyle(.glass).disabled(!done)
            }
            .padding(12)

            GlassDivider()

            SchoolAuthWebView(onCookieFound: { cookie in
                net.webvpnCookie = cookie
                result = "认证成功 ✓"
                done = true
            }, onFinish: {})
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                if let result {
                    Text(result).font(.callout).foregroundColor(.green)
                } else {
                    Text("请在下方登录学校账号（如遇验证码请按页面提示完成）")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
        }
        // 学校登录页需要较大空间：默认 1000×760，可拖拽调整尺寸
        .frame(minWidth: 900, idealWidth: 1000, maxWidth: 1600,
               minHeight: 680, idealHeight: 760, maxHeight: 1200)
        .glassSheetBackground()
    }
}

/// 需要学校认证时的提示视图
struct SchoolAuthRequiredView: View {
    @ObservedObject var net = NetworkManager.shared
    let title: String
    @State private var showAuth = false

    var body: some View {
        VStack(spacing: 14) {
            ModuleIcon(icon: "building.2.fill", color: .secondary, size: 48)
            Text(title).font(Typo.header()).foregroundStyle(.secondary)
            Text(net.webvpnCookie.isEmpty
                 ? "教务数据需要先完成学校统一身份认证"
                 : "学校教务会话已失效，需要重新认证")
                .font(.callout).foregroundStyle(.tertiary)
            Text("登录时如遇验证码，请按页面提示完成")
                .font(.caption).foregroundStyle(.tertiary)
            Button {
                showAuth = true
            } label: {
                Label("去认证", systemImage: "person.badge.key.fill")
            }.buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAuth) { SchoolAuthSheet() }
    }
}
