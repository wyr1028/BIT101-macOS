# BIT101-macOS

北京理工大学校园助手 macOS 客户端，基于 [BIT101 开放 API](https://bit101.flwfdd.xyz) 构建，面向北京理工大学学生提供一站式校园信息体验。

以 SwiftUI + AppKit 为核心，采用 **Liquid Glass 液态玻璃设计语言**，融合原生 macOS 交互（菜单栏、Dock、全局快捷键、拖放），覆盖课表、成绩、课程评价、校园地图、社区内容和个人中心等完整功能。

## 设计系统

采用统一的液态玻璃设计系统（`Views/DesignSystem.swift`）：

- **玻璃表面**：半透明材质 + 连续曲率圆角（superellipse）+ 顶部镜面高光 + 底部切边 + 柔和投影
- **深浅色自适应**：深色模式使用暗色玻璃 tint，不泛白发灰；环境光背景按模式调整亮度
- **设计令牌**：间距 `Sp`、圆角 `Radius`、字体 `Typo`、动效 `Anim` 全局统一
- **动效**：GSAP 动效原则的 SwiftUI 实现——卡片入场淡入上浮、悬停微交互、页面切换淡入淡出、弹簧反馈
- **统一状态视图**：加载 / 空 / 错误态均为玻璃卡片居中展示

## 项目亮点

### 1. 日程与学习管理
- 课表查看：学期切换、周次翻页、**今天高亮**、系统日历导入
- DDL 与考试信息：集中浏览课程相关安排
- 空教室查询：可按教学楼、星期和节次筛选
- 课程块右键复制 / 拖放到其他 App（备忘录等）

### 2. 学业与成绩分析
- 成绩查询：完整成绩数据读取与学期筛选
- GPA / 加权均分统计：自动计算（含五级制换算、重修取最高）
- 成绩趋势图：Swift Charts 展示学期均分与绩点变化
- 成绩导出：PDF 导出（CoreText 绘制，稳定不崩溃）；单科右键单独导出 / 复制 / 拖放

### 3. 校园与社区体验
- 校园地图：良乡/中关村场景切换 + 建筑搜索标注
- 社区内容：话题、文章、评论、点赞、发帖与 EditorJS 富文本渲染
- 多窗口体验：话题 / 课程 / 消息详情可在独立窗口中打开（带玻璃背景）

### 4. macOS 独占功能（手机端无法实现）
- **菜单栏后台模式**：关闭主窗口后驻留菜单栏，下拉面板显示今日课程（**高度按内容自适应**），每次打开自动刷新
- **菜单栏倒计时**：状态栏图标旁实时显示「⏱x′」直到下节课
- **全局快捷键**：`Cmd+Shift+B` 后台唤出菜单栏面板（需在系统设置授予「输入监控」权限）
- **键盘快捷键**：`Cmd+1..5` 直达五大模块、`Cmd+⌥M` 切换浮动课表
- **浮动置顶迷你课表**：always-on-top 小窗，跨空间、全屏也悬浮
- **Dock 右键菜单**：显示主窗口 / 设置 / 退出
- **Dock 角标**：消息未读数角标
- **右键上下文菜单**：课程 / 成绩 / 帖子快速复制、导出
- **拖放导出**：课程与成绩可直接拖成文本到其他 App
- **通知操作按钮**：课程提醒带「查看课表 / 知道了」；点击直达课表
- **上课自动勿扰**：上课期间自动开启系统勿扰、下课恢复
- **深色 / 浅色 / 跟随系统** 三种外观模式

## 技术栈

- SwiftUI + AppKit：界面、窗口与菜单栏管理
- CoreText：PDF 成绩单绘制（稳定、无崩溃）
- CommonCrypto：统一身份认证加密
- Swift Charts：成绩趋势可视化
- MapKit：校园地图
- EventKit / .ics：系统日历导入
- UNUserNotificationCenter：课程提醒 + 操作按钮
- CFNotificationCenter：勿扰模式联动
- WebKit：学校统一身份认证交互式登录

## 运行方式

1. 在 Xcode 中打开项目
2. 打开 [BIT101-macOS.xcodeproj](BIT101-macOS.xcodeproj)
3. 选择 macOS 桌面运行
4. 按 ⌘R 启动应用

## 项目结构

- [BIT101-macOS/AppDelegate.swift](BIT101-macOS/AppDelegate.swift)：应用生命周期、菜单栏、Dock 菜单、全局快捷键、通知
- [BIT101-macOS/BIT101_macOSApp.swift](BIT101-macOS/BIT101_macOSApp.swift)：入口与键盘快捷键
- [BIT101-macOS/ContentView.swift](BIT101-macOS/ContentView.swift)：主界面导航与侧边栏
- [BIT101-macOS/Views/DesignSystem.swift](BIT101-macOS/Views/DesignSystem.swift)：液态玻璃设计系统与组件
- [BIT101-macOS/Views/StateViews.swift](BIT101-macOS/Views/StateViews.swift)：统一加载 / 空 / 错误态
- [BIT101-macOS/Services](BIT101-macOS/Services)：网络请求、加密、缓存、日历导入
- [BIT101-macOS/Views](BIT101-macOS/Views)：各功能页面
- [BIT101-macOS/Models](BIT101-macOS/Models)：数据模型定义

## 更新日志

- 2026-08-03：项目初始化，完成基础页面框架与登录 / 成绩 UI
- 2026-08-04：接入 BIT101 API，完成登录认证、成绩与课表解析、绩点计算、社区内容与菜单栏后台体验
- 2026-08-05：全面液态玻璃化（连续曲率、深浅色自适应、环境光背景）；统一状态视图与动效；修复 PDF 导出崩溃与弹窗出界；新增 macOS 独占功能（键盘快捷键、Dock 菜单、右键菜单、拖放、全局快捷键、通知操作、浮动置顶课表、菜单栏倒计时、自适应下拉）

## 说明

本项目依赖 BIT101 的开放接口，使用前请确保相关服务可访问。若你要继续扩展功能，建议优先从 Services 与 Views 目录入手。
