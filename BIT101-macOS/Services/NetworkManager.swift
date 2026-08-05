import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let baseURL = "https://bit101.flwfdd.xyz"
    
    // MARK: - 持久化属性
    
    /// 学号
    @Published var studentID: String = UserDefaults.standard.string(forKey: "studentID") ?? ""
    
    /// BIT101 社区登录后的 fake_cookie（UserDefaults 存储，避免每次弹钥匙串权限）
    @Published var fakeCookie: String = UserDefaults.standard.string(forKey: "fakeCookie") ?? "" {
        didSet {
            UserDefaults.standard.set(fakeCookie, forKey: "fakeCookie")
            isLoggedIn = !fakeCookie.isEmpty
        }
    }

    /// 学校统一身份认证拿到的 webvpn-cookie（UserDefaults 存储）
    @Published var webvpnCookie: String = UserDefaults.standard.string(forKey: "webvpnCookie") ?? "" {
        didSet {
            UserDefaults.standard.set(webvpnCookie, forKey: "webvpnCookie")
        }
    }
    
    @Published var isLoggedIn: Bool = false

    private init() {
        self.isLoggedIn = !fakeCookie.isEmpty
    }

    /// 给教务类请求设置 webvpn-cookie 与标准 Cookie 头（课表/成绩：有会话就带，没有也照常请求）
    private func applyWebVPN(_ request: inout URLRequest) {
        guard !webvpnCookie.isEmpty else { return }
        request.setValue(webvpnCookie, forHTTPHeaderField: "webvpn-cookie")
        request.setValue(webvpnCookie, forHTTPHeaderField: "Cookie")
    }

    /// 严格模式的 webvpn 头设置：会话缺失时抛错（用于考试/空教室等必须走官方 webvpn 的功能）
    private func applyWebVPNRequired(_ request: inout URLRequest) throws {
        guard !webvpnCookie.isEmpty else {
            throw NSError(domain: "BIT101", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "未完成学校统一身份认证，无法获取教务数据"])
        }
        request.setValue(webvpnCookie, forHTTPHeaderField: "webvpn-cookie")
        request.setValue(webvpnCookie, forHTTPHeaderField: "Cookie")
    }

    /// 把课表/成绩接口的原始错误转成友好提示
    private func friendlyWebVPNError(status: Int) -> Error {
        let msg: String
        if webvpnCookie.isEmpty {
            msg = "课表暂不可用：尚未建立学校教务会话。考试、空教室等功能可在页面内完成学校认证。"
        } else {
            msg = "学校教务会话已失效，课表暂时无法获取。可在考试/空教室页面重新认证。"
        }
        return NSError(domain: "BIT101", code: status, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    private func friendlyMessage(_ apiMsg: String) -> String {
        if apiMsg.contains("参数错误") || apiMsg.contains("Orz") {
            if webvpnCookie.isEmpty {
                return "成绩暂不可用：尚未建立学校教务会话。"
            }
            return "学校教务会话已失效，成绩暂时无法获取。"
        }
        return apiMsg
    }

    /// 校验已保存的 webvpn 会话 cookie 是否仍然有效
    /// 通过请求一个需要认证的教务接口来判断：返回登录页说明会话失效，返回真实数据说明有效
    func verifyWebVPNSession() async -> Bool {
        guard !webvpnCookie.isEmpty else { return false }
        let wvpn = "https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421faef5b842238695c720999bcd6572a216b231105adc27d"
        guard let url = URL(string: wvpn + "/jwapp/sys/funauthapp/api/getAppConfig/wdkbby-5959167891382285.do") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue(webvpnCookie, forHTTPHeaderField: "Cookie")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return false }
            let text = String(data: data, encoding: .utf8) ?? ""
            // 未认证时会返回「统一身份认证平台」登录页
            if text.contains("统一身份认证平台") || text.contains("帐号登录或动态码登录") { return false }
            return data.count > 100
        } catch { return false }
    }
    
    // MARK: - 1. BIT101 社区账号登录
    
    func login(sid: String, password: String) async throws {
        studentID = sid
        UserDefaults.standard.set(sid, forKey: "studentID")
        
        guard let url = URL(string: "\(baseURL)/user/login") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let encryptedPassword = password.md5
        let bodyParams = ["sid": sid, "password": encryptedPassword]
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams)
        
        print("🚀 [1/3] 发送 BIT101 社区登录请求...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = (try? JSONDecoder().decode(LoginResponse.self, from: data))?.msg ?? "登录失败"
            throw NSError(domain: "BIT101", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        let loginResult = try JSONDecoder().decode(LoginResponse.self, from: data)
        guard let cookie = loginResult.fake_cookie else {
            throw URLError(.cannotParseResponse)
        }
        
        await MainActor.run {
            self.fakeCookie = cookie
            print("✅ [1/3] BIT101 社区登录成功！fakeCookie 已保存")
        }
        
        // 登录成功后，自动触发学校统一身份认证链路（换取真实 webvpn-cookie）
        try await performSchoolWebVPNAuth(sid: sid, rawPassword: password)
    }
    
    // MARK: - 2. 学校统一身份认证全流程
    
    func performSchoolWebVPNAuth(sid: String, rawPassword: String) async throws {
        print("🚀 [2/3] 开始学校统一身份认证初始化...")
        
        // Step A: 请求初始化接口获取 salt、execution 和 cookie
        guard let initURL = URL(string: "\(baseURL)/user/webvpn_verify_init") else {
            throw URLError(.badURL)
        }
        var initReq = URLRequest(url: initURL)
        initReq.httpMethod = "POST"
        initReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        initReq.httpBody = try? JSONSerialization.data(withJSONObject: ["sid": sid])
        
        let (initData, initResp) = try await URLSession.shared.data(for: initReq)
        guard (initResp as? HTTPURLResponse)?.statusCode == 200 else {
            print("❌ WebVPN 初始化失败")
            throw URLError(.badServerResponse)
        }
        
        let initResult = try JSONDecoder().decode(WebVPNInitResponse.self, from: initData)
        guard let salt = initResult.salt,
              let execution = initResult.execution,
              let initCookie = initResult.cookie else {
            print("❌ 未获取到学校认证所需的 salt/execution/cookie")
            throw URLError(.cannotParseResponse)
        }
        
        print("🔑 获得学校加密 Salt（前50字符）: \(String(salt.prefix(50)))...")
        
        // Step B: 使用 AES-ECB 加密密码（匹配学校 EncryptPassword.js）
        guard let encryptedPassword = encryptPasswordAES(password: rawPassword, salt: salt) else {
            print("❌ AES 加密密码失败")
            throw URLError(.cannotParseResponse)
        }
        print("🔐 经过 EncryptPassword 加密后的字符串: \(String(encryptedPassword.prefix(30)))...")
        
        // Step C: 提交统一身份验证（注意：必须携带 salt 参数！）
        guard let verifyURL = URL(string: "\(baseURL)/user/webvpn_verify") else {
            throw URLError(.badURL)
        }
        var verifyReq = URLRequest(url: verifyURL)
        verifyReq.httpMethod = "POST"
        verifyReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let verifyParams: [String: Any] = [
            "sid": sid,
            "salt": salt,
            "password": encryptedPassword,
            "execution": execution,
            "cookie": initCookie
        ]
        verifyReq.httpBody = try? JSONSerialization.data(withJSONObject: verifyParams)
        
        let (verifyData, verifyResp) = try await URLSession.shared.data(for: verifyReq)
        
        let statusCode = (verifyResp as? HTTPURLResponse)?.statusCode ?? 0
        print("📡 学校统一身份验证状态码: \(statusCode)")
        if let jsonStr = String(data: verifyData, encoding: .utf8) {
            print("📦 学校统一身份验证返回 JSON: \(jsonStr)")
        }
        
        guard statusCode == 200 else {
            let errorMsg = (try? JSONDecoder().decode(WebVPNVerifyResponse.self, from: verifyData))?.msg ?? "统一身份认证失败"
            throw NSError(domain: "BIT101", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // 初始化接口返回的 cookie 仅作参考，需要校验是否真的有效
        // （学校 SSO 目前有风控验证码，webvpn_verify 可能误报成功）
        await MainActor.run {
            self.webvpnCookie = initCookie
        }
        let valid = await verifyWebVPNSession()
        await MainActor.run {
            if !valid {
                self.webvpnCookie = ""
                print("⚠️ webvpn cookie 未通过校验（学校可能要求验证码），教务数据需通过应用内学校认证获取")
            } else {
                print("🎉 [2/3] 学校统一身份认证成功！已获得真实有效 webvpn-cookie")
            }
        }
    }
    
    // MARK: - 3. 成绩查询
    
    func fetchScores() async throws -> [[String]] {
        guard let url = URL(string: "\(baseURL)/score?detail=true") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        // bit101 Go 后端代理学校系统：必须带 webvpn-cookie（见 BIT101-GO api/handler/score.go）
        request.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        applyWebVPN(&request)

        print("🚀 [3/3] 发送真实成绩请求至: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 官方教务成绩接口响应状态码: \(httpResponse.statusCode)")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 成绩接口返回 JSON（前200字符）: \(String(jsonString.prefix(200)))")
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = (try? JSONDecoder().decode(ScoreResponse.self, from: data))?.msg ?? "获取成绩失败"
            throw NSError(domain: "BIT101", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: friendlyMessage(errorMsg)])
        }
        
        let scoreResult = try JSONDecoder().decode(ScoreResponse.self, from: data)
        guard let scores = scoreResult.data, !scores.isEmpty else {
            throw NSError(domain: "BIT101", code: 500, userInfo: [NSLocalizedDescriptionKey: "暂无成绩数据"])
        }
        
        print("✅ 成功解析官方教务真实成绩二维数组！共 \(scores.count) 行")
        return scores
    }
    
    // MARK: - 4. 课表获取（iCal 解析）
    
    /// 课表获取结果
    struct ScheduleResult {
        let events: [iCalEvent]
        let firstDay: Date
        let term: String
        let icalURL: String
    }
    
    func fetchSchedule(term: String? = nil) async throws -> ScheduleResult {
        // Step 1: 获取课表 iCal 文件 URL
        var urlString = "\(baseURL)/courses/schedule"
        if let term = term, !term.isEmpty {
            urlString += "?term=\(term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term)"
        }
        guard let scheduleURL = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: scheduleURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        // bit101 Go 后端代理学校系统：必须带 webvpn-cookie（见 BIT101-GO api/handler/course.go）
        request.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        applyWebVPN(&request)

        print("🚀 请求课表 URL: \(urlString)")
        let (scheduleData, scheduleResp) = try await URLSession.shared.data(for: request)
        
        let status = (scheduleResp as? HTTPURLResponse)?.statusCode ?? 0
        print("📡 课表响应状态: \(status)")
        guard status == 200 else {
            if let body = String(data: scheduleData, encoding: .utf8) { print("📦 课表错误: \(body.prefix(200))") }
            throw friendlyWebVPNError(status: status)
        }
        
        let scheduleResult = try JSONDecoder().decode(ScheduleResponse.self, from: scheduleData)
        print("📦 课表响应: \(scheduleResult.note ?? "无备注")")
        
        guard let icalURLString = scheduleResult.url,
              let icalURL = URL(string: icalURLString) else {
            throw NSError(domain: "BIT101", code: 500, userInfo: [NSLocalizedDescriptionKey: "未获取到课表文件链接"])
        }
        
        print("📥 下载 iCal 文件: \(icalURLString)")
        
        // Step 2: 下载 iCal 文件
        let (icalData, icalResp) = try await URLSession.shared.data(from: icalURL)
        guard (icalResp as? HTTPURLResponse)?.statusCode == 200,
              let icalString = String(data: icalData, encoding: .utf8) else {
            throw NSError(domain: "BIT101", code: 500, userInfo: [NSLocalizedDescriptionKey: "下载课表文件失败"])
        }
        
        // Step 3: 解析 iCal，计算学期第一天
        let (events, firstDay) = parseiCal(icalString)
        print("✅ 成功解析课表！共 \(events.count) 个课程事件")
        
        // 从 note 提取学期信息
        let term = scheduleResult.note ?? ""
        
        return ScheduleResult(events: events, firstDay: firstDay, term: term, icalURL: icalURLString)
    }
    
    // MARK: - 5. 检查登录状态
    
    func checkLoginStatus() async throws {
        guard let url = URL(string: "\(baseURL)/user/check") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        request.timeoutInterval = 10
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            await MainActor.run { self.logout() }
            throw NSError(domain: "BIT101", code: 401, userInfo: [NSLocalizedDescriptionKey: "登录已过期"])
        }
        
        print("✅ 登录状态有效")
    }
    
    // MARK: - 6. 更新用户信息
    
    func updateUserInfo(nickname: String? = nil, motto: String? = nil, avatarMid: String? = nil) async throws {
        guard let url = URL(string: "\(baseURL)/user/info") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        var body: [String: String] = [:]
        if let n = nickname { body["nickname"] = n }
        if let m = motto { body["motto"] = m }
        if let a = avatarMid { body["avatar"] = a }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
    
    // MARK: - 7. 上传图片
    
    func fetchUserInfo() async throws -> UserInfoResponse {
        guard let url = URL(string: "\(baseURL)/user/info") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(UserInfoResponse.self, from: data)
    }
    
    /// 获取头像 URL
    func avatarURL(for mid: String?) -> URL? {
        guard let mid = mid, !mid.isEmpty else { return nil }
        return URL(string: "\(baseURL)/upload/image/\(mid)")
    }
    
    // MARK: - 7. 帖子（话题）
    
    func fetchPosters(page: Int = 0, mode: String = "recommend", search: String? = nil) async throws -> [PosterItem] {
        var urlStr = "\(baseURL)/posters?page=\(page)"
        if !mode.isEmpty { urlStr += "&mode=\(mode)" }
        if let s = search, !s.isEmpty {
            urlStr += "&search=\(s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s)"
        }
        guard let url = URL(string: urlStr) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        req.timeoutInterval = 10
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([PosterItem].self, from: data)
    }
    
    // MARK: - 8. 文章
    
    func fetchPapers(page: Int = 0, search: String = "") async throws -> [PaperItem] {
        var urlStr = "\(baseURL)/papers?page=\(page)"
        if !search.isEmpty { urlStr += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)" }
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([PaperItem].self, from: data)
    }
    
    // MARK: - 9. 课程评价
    
    func fetchCourses(page: Int = 0, order: String = "rate", search: String? = nil) async throws -> [CourseItem] {
        var urlStr = "\(baseURL)/courses?page=\(page)&order=\(order)"
        if let s = search, !s.isEmpty { urlStr += "&search=\(s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s)" }
        guard let url = URL(string: urlStr) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        req.timeoutInterval = 10
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([CourseItem].self, from: data)
    }
    
    // MARK: - 10. 点赞/取消点赞
    
    func toggleLike(obj: String) async throws -> (liked: Bool, count: Int) {
        guard let url = URL(string: "\(baseURL)/reaction/like") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["obj": obj])
        let (likeData, _) = try await URLSession.shared.data(for: req)
        struct LikeResp: Codable { let like: Bool; let like_num: Int }
        let r = try JSONDecoder().decode(LikeResp.self, from: likeData)
        return (r.like, r.like_num)
    }
    
    // MARK: - 11. 获取评论
    
    func fetchComments(obj: String, page: Int = 0) async throws -> [CommentItem] {
        guard let url = URL(string: "\(baseURL)/reaction/comments?obj=\(obj)&page=\(page)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        req.timeoutInterval = 10
        let (cmtData, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode([CommentItem].self, from: cmtData)
    }
    
    // MARK: - 12. 帖子详情
    
    func fetchPosterDetail(id: Int) async throws -> PosterDetail {
        guard let url = URL(string: "\(baseURL)/posters/\(id)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        let (posterData, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(PosterDetail.self, from: posterData)
    }
    
    // MARK: - 13. 文章详情
    
    func fetchPaperDetail(id: Int) async throws -> PaperDetail {
        guard let url = URL(string: "\(baseURL)/papers/\(id)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        if !fakeCookie.isEmpty { req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(PaperDetail.self, from: data)
    }
    
    // MARK: - 14. 发送评论
    
    func sendComment(obj: String, text: String, replyObj: String? = nil, replyUid: Int? = nil) async throws {
        guard let url = URL(string: "\(baseURL)/reaction/comments") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        var body: [String: Any] = ["obj": obj, "text": text]
        if let ro = replyObj { body["reply_obj"] = ro }
        if let ru = replyUid { body["reply_uid"] = ru }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
    
    // MARK: - 15. 消息
    
    func fetchMessages() async throws -> ([MessageItem], Int) {
        guard let url = URL(string: "\(baseURL)/messages") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        let (msgData, _) = try await URLSession.shared.data(for: req)
        let msgs = try JSONDecoder().decode([MessageItem].self, from: msgData)
        // 获取未读数
        var unread = 0
        if let u = URL(string: "\(baseURL)/messages/unread_num") {
            var r = URLRequest(url: u); r.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
            if let (d, _) = try? await URLSession.shared.data(for: r) {
                struct UR: Codable { let num: Int }
                unread = (try? JSONDecoder().decode(UR.self, from: d))?.num ?? 0
            }
        }
        return (msgs, unread)
    }
    
    // MARK: - 15. 发帖
    
    func createPoster(title: String, text: String, anonymous: Bool = false, tags: [String] = []) async throws {
        guard let url = URL(string: "\(baseURL)/posters") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        let body: [String: Any] = ["title": title, "text": text, "anonymous": anonymous, "tags": tags]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
    
    // MARK: - 15.1 发布文章

    func createPaper(title: String, intro: String = "", content: String) async throws {
        guard let url = URL(string: "\(baseURL)/papers") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        let body: [String: Any] = [
            "title": title,
            "intro": intro,
            "content": content  // EditorJS JSON 字符串
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }

    // MARK: - 15.2 关注 / 粉丝

    func toggleFollow(uid: Int) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/user/follow/\(uid)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        let (data, _) = try await URLSession.shared.data(for: req)
        struct R: Codable { let follow: Bool? }
        return (try? JSONDecoder().decode(R.self, from: data))?.follow ?? false
    }

    func fetchFollowings() async throws -> [UserAPI] {
        guard let url = URL(string: "\(baseURL)/user/followings") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONDecoder().decode([UserAPI].self, from: data)) ?? []
    }

    func fetchFollowers() async throws -> [UserAPI] {
        guard let url = URL(string: "\(baseURL)/user/followers") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONDecoder().decode([UserAPI].self, from: data)) ?? []
    }

    // MARK: - 15.3 课程详情与评价

    struct CourseDetail: Codable {
        let id: Int?
        let name: String?
        let number: String?
        let teachers_name: String?
        let rate: Double?
        let comment_num: Int?
        let intro: String?
    }

    func fetchCourseDetail(id: Int) async throws -> CourseDetail {
        guard let url = URL(string: "\(baseURL)/courses/\(id)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(CourseDetail.self, from: data)
    }

    func sendCourseComment(courseID: Int, text: String, rate: Double) async throws {
        // 课程评价走评论接口，obj 格式为 course{id}
        try await sendComment(obj: "course\(courseID)", text: text)
    }

    // MARK: - 16. 可信成绩单
    
    func fetchScoreReport() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/score/report") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(webvpnCookie, forHTTPHeaderField: "webvpn-cookie")
        let (reportData, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable { let data: [String]? }
        return (try? JSONDecoder().decode(Resp.self, from: reportData))?.data ?? []
    }
    
    // MARK: - 16. 学校教务直连（空教室）

    /// 空教室查询结果
    struct EmptyRoom: Codable, Identifiable {
        let id = UUID()
        let name: String      // 教室名（含楼名）
        let section: String   // 可用节次
        let campus: String    // 校区
    }

    func fetchEmptyClassrooms(building: String, weekday: Int, section: Int) async throws -> [EmptyRoom] {
        let wvpn = "https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421faef5b842238695c720999bcd6572a216b231105adc27d"
        guard let url = URL(string: "\(wvpn)/jwapp/sys/functionPageAddUrl/emptyClassroom.do") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(webvpnCookie, forHTTPHeaderField: "Cookie")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = "JASO_TAB_MAIN_ID=\(section)&KXSD=\(weekday)&".data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try parseEmptyRooms(data)
    }

    private func parseEmptyRooms(_ data: Data) throws -> [EmptyRoom] {
        let text = String(data: data, encoding: .utf8) ?? ""
        // 未认证时返回登录页
        if text.contains("统一身份认证") || text.contains("帐号登录或动态码登录") {
            throw NSError(domain: "BIT101", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "学校教务会话已失效，请重新完成学校统一身份认证"])
        }
        // 新教务 jwapp 返回 JSON: {"datas": {"rows": [...]}} 或 {"datas": {"emptyClassroom": {"rows":[...]}}}
        if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let datas = j["datas"] as? [String: Any] {
            var rows: [[String: Any]] = []
            for (_, v) in datas {
                if let arr = v as? [[String: Any]] { rows = arr; break }
                if let obj = v as? [String: Any], let arr = obj["rows"] as? [[String: Any]] { rows = arr; break }
            }
            if !rows.isEmpty {
                var out: [EmptyRoom] = []
                for r in rows {
                    let name = (r["JASO_TAB_MC"] as? String) ?? (r["JASO_TAB"] as? String) ?? ""
                    let sec = (r["XSD"] as? String) ?? ""
                    let campus = (r["XNXQMC"] as? String) ?? ""
                    if !name.isEmpty { out.append(EmptyRoom(name: name, section: sec, campus: campus)) }
                }
                if !out.isEmpty { return out }
            }
        }
        // HTML 表格兜底
        return parseEmptyRoomHTML(text)
    }

    private func parseEmptyRoomHTML(_ html: String) -> [EmptyRoom] {
        var out: [EmptyRoom] = []
        let rows = html.components(separatedBy: "<tr")
        for row in rows.dropFirst() {
            let cells = row.components(separatedBy: "<td")
            var vals: [String] = []
            for c in cells.dropFirst() {
                if let s = c.firstIndex(of: ">") {
                    var v = String(c[c.index(after: s)...])
                    v = v.components(separatedBy: "<")[0]
                    vals.append(v.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            if vals.count >= 2, !vals[0].isEmpty {
                out.append(EmptyRoom(name: vals[0], section: vals.count > 1 ? vals[1] : "", campus: vals.count > 2 ? vals[2] : ""))
            }
        }
        return out
    }

    // MARK: - 17. 考试查询

    /// 考试条目
    struct ExamItem: Codable, Identifiable {
        let id = UUID()
        let name: String
        let date: String
        let time: String
        let location: String
        let seat: String
        let term: String
    }

    func fetchExams(term: String? = nil) async throws -> [ExamItem] {
        let wvpn = "https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421faef5b842238695c720999bcd6572a216b231105adc27d"
        guard let url = URL(string: "\(wvpn)/jwapp/sys/studentExamQuery/examQuery.do") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(webvpnCookie, forHTTPHeaderField: "Cookie")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = "".data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try parseExams(data)
    }

    private func parseExams(_ data: Data) throws -> [ExamItem] {
        let text = String(data: data, encoding: .utf8) ?? ""
        if text.contains("统一身份认证") || text.contains("帐号登录或动态码登录") {
            throw NSError(domain: "BIT101", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "学校教务会话已失效，请重新完成学校统一身份认证"])
        }
        if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let datas = j["datas"] as? [String: Any] {
            var rows: [[String: Any]] = []
            for (_, v) in datas {
                if let arr = v as? [[String: Any]] { rows = arr; break }
                if let obj = v as? [String: Any], let arr = obj["rows"] as? [[String: Any]] { rows = arr; break }
            }
            if !rows.isEmpty {
                var out: [ExamItem] = []
                for r in rows {
                    let name = (r["KCM"] as? String) ?? (r["KCMC"] as? String) ?? ""
                    let date = (r["KSRQ"] as? String) ?? ""
                    let time = (r["KSSJ"] as? String) ?? ""
                    let loc = (r["CDMC"] as? String) ?? (r["KSDD"] as? String) ?? ""
                    let seat = (r["ZWH"] as? String) ?? ""
                    let term = (r["XNXQMC"] as? String) ?? ""
                    if !name.isEmpty { out.append(ExamItem(name: name, date: date, time: time, location: loc, seat: seat, term: term)) }
                }
                return out
            }
        }
        return parseExamHTML(text)
    }

    private func parseExamHTML(_ html: String) -> [ExamItem] {
        var out: [ExamItem] = []
        let rows = html.components(separatedBy: "<tr")
        for row in rows.dropFirst() {
            let cells = row.components(separatedBy: "<td")
            var vals: [String] = []
            for c in cells.dropFirst() {
                if let s = c.firstIndex(of: ">") {
                    var v = String(c[c.index(after: s)...])
                    v = v.components(separatedBy: "<")[0]
                    vals.append(v.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
            if vals.count >= 3, !vals[0].isEmpty {
                out.append(ExamItem(name: vals[0], date: vals.count > 1 ? vals[1] : "",
                                    time: vals.count > 2 ? vals[2] : "",
                                    location: vals.count > 3 ? vals[3] : "",
                                    seat: vals.count > 4 ? vals[4] : "",
                                    term: vals.count > 5 ? vals[5] : ""))
            }
        }
        return out
    }
    
    // MARK: - 18. 获取课程历史均分
    
    func fetchCourseHistories(courseNumbers: [String]) async -> [String: CourseHistoryItem] {
        // 使用 fake-cookie 进行认证
        guard !fakeCookie.isEmpty else { return [:] }

        var results: [String: CourseHistoryItem] = [:]

        // 分块限制并发（每批 5 个），避免一次性打爆接口
        for chunkStart in stride(from: 0, to: courseNumbers.count, by: 5) {
            let slice = Array(courseNumbers[chunkStart..<min(chunkStart + 5, courseNumbers.count)])
            await withTaskGroup(of: (String, CourseHistoryItem?).self) { group in
                for number in slice {
                    group.addTask {
                        let item = await self.fetchOneCourseHistory(number: number)
                        return (number, item)
                    }
                }
                for await (number, item) in group {
                    if let item = item {
                        results[number] = item
                    }
                }
            }
        }

        return results
    }
    
    private func fetchOneCourseHistory(number: String) async -> CourseHistoryItem? {
        let encoded = number.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? number
        guard let url = URL(string: "\(baseURL)/courses/histories/\(encoded)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(fakeCookie, forHTTPHeaderField: "fake-cookie")
        request.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            
            let histories = try JSONDecoder().decode([CourseHistoryItem].self, from: data)
            // 返回最近一个学期（第一个）的数据
            return histories.first
        } catch {
            return nil
        }
    }
    
    // MARK: - iCal 解析器

    func parseiCal(_ icalString: String) -> (events: [iCalEvent], firstDay: Date) {
        var events: [iCalEvent] = []
        let lines = icalString.components(separatedBy: .newlines)
        
        var currentSummary = ""
        var currentLocation = ""
        var currentDescription = ""
        var currentDTStart: Date?
        var currentDTEnd: Date?
        var inEvent = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                currentSummary = ""
                currentLocation = ""
                currentDescription = ""
                currentDTStart = nil
                currentDTEnd = nil
            } else if trimmed == "END:VEVENT" {
                inEvent = false
                
                guard let start = currentDTStart,
                      let end = currentDTEnd,
                      !currentSummary.isEmpty else { continue }
                
                let calendar = Calendar(identifier: .gregorian)
                let dayOfWeek = calendar.component(.weekday, from: start)  // 1=周日, 2=周一...
                
                // 从上课时间推算节次（使用北理工作息时间表）
                let startHour = calendar.component(.hour, from: start)
                let startMinute = calendar.component(.minute, from: start)
                let endHour = calendar.component(.hour, from: end)
                let endMinute = calendar.component(.minute, from: end)
                
                let startSection = sectionFromTime(hour: startHour, minute: startMinute)
                // 计算持续节数：统计 [start, end) 区间内开始的节次
                let startMins = startHour * 60 + startMinute
                let endMins = endHour * 60 + endMinute
                let sectionStarts = [(8,0,1),(8,50,2),(9,55,3),(10,45,4),(11,35,5),
                                     (13,20,6),(14,10,7),(15,15,8),(16,5,9),(16,55,10),
                                     (18,30,11),(19,20,12),(20,10,13)]
                let duration = max(1, sectionStarts.filter { h, m, _ in
                    let t = h * 60 + m
                    return t >= startMins && t < endMins
                }.count)
                
                // 从 description 提取教师名
                let descParts = currentDescription.components(separatedBy: " | ")
                let teacher = descParts.first?.trimmingCharacters(in: .whitespaces) ?? ""
                let weekDesc = descParts.count > 1 ? descParts[1].trimmingCharacters(in: .whitespaces) : ""
                
                // 清理 location 中的换行
                let cleanLocation = currentLocation.replacingOccurrences(of: "\\n", with: " ")
                
                events.append(iCalEvent(
                    summary: currentSummary,
                    location: cleanLocation,
                    teacher: teacher,
                    startDate: start,
                    endDate: end,
                    dayOfWeek: dayOfWeek,
                    startSection: startSection,
                    duration: duration,
                    weekDescription: weekDesc
                ))
            } else if inEvent {
                if trimmed.hasPrefix("SUMMARY:") {
                    currentSummary = String(trimmed.dropFirst(8))
                } else if trimmed.hasPrefix("LOCATION:") {
                    currentLocation = String(trimmed.dropFirst(9))
                } else if trimmed.hasPrefix("DESCRIPTION:") {
                    currentDescription = String(trimmed.dropFirst(12))
                } else if trimmed.hasPrefix("DTSTART") {
                    // DTSTART;TZID=Asia/Shanghai:20250901T000000
                    if let colonIndex = trimmed.lastIndex(of: ":") {
                        let dateStr = String(trimmed[trimmed.index(after: colonIndex)...])
                        currentDTStart = dateFormatter.date(from: dateStr)
                    }
                } else if trimmed.hasPrefix("DTEND") {
                    if let colonIndex = trimmed.lastIndex(of: ":") {
                        let dateStr = String(trimmed[trimmed.index(after: colonIndex)...])
                        currentDTEnd = dateFormatter.date(from: dateStr)
                    }
                }
            }
        }
                // 计算学期第一天：找到所有事件中最早日期所在周的周一
        let calendar = Calendar(identifier: .gregorian)
        var firstDay = Date()
        if let earliest = events.map(\.startDate).min() {
            let weekday = calendar.component(.weekday, from: earliest)
            // weekday: 1=周日, 2=周一... 找到最近的上一个周一
            let mondayOffset = weekday == 1 ? -6 : 2 - weekday
            firstDay = calendar.date(byAdding: .day, value: mondayOffset, to: earliest) ?? earliest
            // 清除时分秒
            firstDay = calendar.startOfDay(for: firstDay)
        }
        
        return (events, firstDay)
    }
    
    /// 根据时间推算节次（北理工作息时间表）
    func sectionFromTime(hour: Int, minute: Int) -> Int {
        let timeTable: [(startH: Int, startM: Int, section: Int)] = [
            (8, 0, 1), (8, 50, 2), (9, 55, 3), (10, 45, 4), (11, 35, 5),
            (13, 20, 6), (14, 10, 7), (15, 15, 8), (16, 5, 9), (16, 55, 10),
            (18, 30, 11), (19, 20, 12), (20, 10, 13)
        ]
        
        let totalMinutes = hour * 60 + minute
        
        var bestSection = 1
        for entry in timeTable {
            let entryMinutes = entry.startH * 60 + entry.startM
            if totalMinutes >= entryMinutes {
                bestSection = entry.section
            }
        }
        return bestSection
    }
    
    // MARK: - 退出登录
    
    func logout() {
        self.fakeCookie = ""
        self.webvpnCookie = ""
        self.isLoggedIn = false
        // 保留学号以便下次快速登录
        print("👋 已退出登录")
    }
}
