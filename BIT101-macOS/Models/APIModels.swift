import Foundation

// MARK: - 用户模块

/// BIT101 社区登录 Response
struct LoginResponse: Codable {
    let fake_cookie: String?
    let msg: String?
}

/// 学校统一身份验证初始化 Response
struct WebVPNInitResponse: Codable {
    let salt: String?
    let cookie: String?
    let execution: String?
    let captcha: String?
    let msg: String?
}

/// 学校统一身份验证提交 Response
struct WebVPNVerifyResponse: Codable {
    let token: String?
    let code: String?       // 验证码，String 类型
    let msg: String?
}

/// 登录状态检查 Response
struct CheckLoginResponse: Codable {
    let msg: String?
}

/// 用户信息 Response（/user/info 返回 user + follow 信息）
struct UserInfoResponse: Codable {
    let user: UserAPI?
    let following_num: Int64?
    let follower_num: Int64?
    let following: Bool?
    let follower: Bool?
    let own: Bool?
    let msg: String?
    
    var nickname: String? { user?.nickname }
    var motto: String? { user?.motto }
    var avatarMid: String? { user?.avatar?.mid }
    var identityName: String? { user?.identity?.text }
}

struct UserAPI: Codable {
    let id: Int?
    let nickname: String?
    let motto: String?
    let avatar: ImageAPI?
    let identity: IdentityAPI?
}

struct ImageAPI: Codable {
    let mid: String?
    let url: String?
}

struct IdentityAPI: Codable {
    let id: Int?
    let text: String?         // "普通用户"
    let color: String?
}

// MARK: - 社区内容模块

/// 帖子 Response（/posters 返回 PosterAPI 列表）
struct PosterItem: Codable, Identifiable {
    let id: Int?
    let title: String?
    let text: String?
    let update_time: String?
    let uid: Int?
    let like_num: Int?
    let comment_num: Int?
    let user: UserAPI?
    let tags: [String]?
    let anonymous: Bool?
    var identity: Int { id ?? 0 }
}

/// 文章 Response（/papers 返回 PaperAPI 列表）
struct PaperItem: Codable, Identifiable {
    let id: Int?
    let title: String?
    let intro: String?        // 注意：字段名是 intro 不是 text
    let update_time: String?
    let like_num: Int?
    let comment_num: Int?
    var identity: Int { id ?? 0 }
}

/// 课程 Response（对应 /courses）
struct CourseItem: Codable, Identifiable {
    let id: Int?
    let name: String?
    let number: String?
    let teachers_name: String?
    let like_num: Int?
    let comment_num: Int?
    let rate: Double?
    var identity: Int { id ?? 0 }
}

// MARK: - 成绩模块

/// 成绩 Response
struct ScoreResponse: Codable {
    let data: [[String]]?
    let msg: String?
}

// MARK: - 课表模块

/// 课表 Response（返回 iCal 文件 URL）
struct ScheduleResponse: Codable {
    let url: String?
    let note: String?
    let msg: String?
}

/// iCal 解析后的课程事件
struct iCalEvent {
    let summary: String        // 课程名
    let location: String       // 教室
    let teacher: String        // 教师（从 description 提取）
    let startDate: Date        // 开始时间
    let endDate: Date          // 结束时间
    let dayOfWeek: Int         // 星期几 (1-7, 1=周日)
    let startSection: Int      // 开始节次（从时间推算）
    let duration: Int          // 持续节数
    let weekDescription: String // 上课周次描述
}

// MARK: - 课程历史模块

/// 课程历史 Response（单门课程各学期的均分数据）
struct CourseHistoryItem: Codable {
    let term: String?             // 学期，如 "2025-2026-1"
    let avg_score: Double?        // 平均分
    let max_score: Double?        // 最高分
    let student_num: Int?         // 学生人数
}

/// 成绩汇总统计
struct GradeSummary {
    let totalAvgScore: Double    // 个人加权平均分
    let totalGPA: Double         // 个人加权平均绩点
    let totalCredits: Double     // 总学分
    let courseCount: Int         // 课程数量
    let globalAvgScore: Double?  // 全局课程历史加权平均分（可选）
    let globalAvgGPA: Double?    // 全局课程历史加权平均绩点（可选）
}

// MARK: - 评论 & 详情

/// 评论条目
struct CommentItem: Codable, Identifiable {
    let id: Int?
    let text: String?
    let create_time: String?
    let user: UserAPI?
    let like: Bool?
    let like_num: Int?
    let own: Bool?
    let reply_user: UserAPI?
    let sub: [CommentItem]?
    var identity: Int { id ?? 0 }
}

/// 帖子详情
struct PosterDetail: Codable {
    let id: Int?
    let title: String?
    let text: String?
    let create_time: String?
    let update_time: String?
    let uid: Int?
    let anonymous: Bool?
    let like_num: Int?
    let comment_num: Int?
    let user: UserAPI?
    let images: [ImageAPI]?
    let tags: [String]?
    let like: Bool?
    let own: Bool?
    let claim: ClaimItem?
}

/// 文章详情
struct PaperDetail: Codable {
    let id: Int?
    let title: String?
    let intro: String?
    let content: String?
    let update_time: String?
    let update_user: UserAPI?
    let like_num: Int?
    let comment_num: Int?
    let like: Bool?
    let own: Bool?
}

struct ClaimItem: Codable {
    let id: Int?
    let name: String?
}
