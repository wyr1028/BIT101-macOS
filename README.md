# BIT101-macOS

北京理工大学校园助手 macOS 客户端，基于 [BIT101 开放 API](https://bit101.flwfdd.xyz) 构建。

## 功能模块

### 日程
- **课表**：支持学期切换（2020 至今全部学期）、周次翻页，从学校教务系统实时获取 iCal 数据解析展示
- **DDL**：待学校教务接口支持后开放
- **空教室**：待学校教务接口支持后开放

### 地图
- 良乡校区与中关村校区切换，使用 MapKit 原生渲染
- 标注主要教学楼（综教 A/B、理教楼、理学楼 A/B/C、文萃楼、图书馆、体育馆、食堂）

### 画廊
- **话题**：社区帖子列表，支持推荐/热门/关注三种排序，无限滚动分页，点击进入详情查看完整内容与评论
- **文章**：校园文章列表，无限滚动分页，详情页展示正文与评论

### 学业
- **成绩查询**：从教务系统获取含平均分、最高分的详细成绩数据，自动计算绩点（BIT 标准分段映射），按学期组合筛选，显示个人加权均分/绩点与课程全局历史均值
- **课程评价**：课程评分列表，按评分排序，无限滚动分页

### 我的
- BIT101 统一身份认证登录（MD5 + AES-ECB-256 加密）
- 个人信息展示（头像、昵称、签名、身份标签、关注数、粉丝数）
- 明暗主题切换

## 技术实现

- **平台**：macOS 26，SwiftUI，最低部署目标 macOS 15
- **数据层**：RESTful API（bit101.flwfdd.xyz），`fake-cookie` + `webvpn-cookie` 双重认证
- **成绩解析**：26 列表头自动匹配，绩点按 BIT 标准从百分制成绩推算
- **课表解析**：iCal (VCALENDAR) 客户端解析为结构化课程数据，节次按北理工作息时间表映射
- **加密**：CommonCrypto AES-ECB-256 用于统一身份认证密码加密

## 项目结构

```
BIT101-macOS/
├── BIT101_macOSApp.swift              # 应用入口
├── ContentView.swift                  # 主布局（侧边栏导航 + 内容区路由）
├── Models/
│   ├── APIModels.swift                # 全部 API 响应模型
│   └── Course.swift                   # 课程数据模型与颜色池
├── Services/
│   ├── NetworkManager.swift           # 网络层（认证、成绩、课表、社区、评论）
│   └── CryptoUtils.swift              # MD5 + AES-ECB 加密
├── Views/
│   ├── ScheduleView.swift             # 课表网格视图
│   ├── GradeView.swift                # 成绩查询（含绩点计算与汇总）
│   ├── ProfileView.swift              # 个人中心（登录/信息/设置）
│   ├── TopicView.swift                # 社区话题列表与详情
│   ├── ArticleView.swift              # 文章列表与详情
│   ├── CourseReviewView.swift         # 课程评价列表
│   ├── MapView.swift                  # 校园地图
│   ├── DDLView.swift                  # DDL 提醒
│   └── EmptyRoomView.swift            # 空教室查询
├── Assets.xcassets/                   # 应用图标与强调色
└── BIT101-macOS.xcodeproj/            # Xcode 项目文件
```

## 构建

1. `git clone` 本项目
2. 使用 Xcode 26 打开 `BIT101-macOS.xcodeproj`
3. 选择 macOS 目标，⌘R 运行

<small style="color: #999;">
wyr：项目架构搭建、成绩原始表格渲染、课表网格布局、登录界面、侧边栏导航结构、校园地图建筑物标注。
AI（Gemini / DeepSeek）：BIT101 全部 API 对接与字段映射、绩点计算逻辑、iCal 解析器、液态玻璃卡片组件、社区评论与点赞交互、分页加载、学期筛选、数据模型设计、各类 Bug 诊断与修复。
</small>
