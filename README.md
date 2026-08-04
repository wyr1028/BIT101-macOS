# BIT101-macOS

北京理工大学校园助手 macOS 客户端，基于 [BIT101 开放 API](https://bit101.flwfdd.xyz) 构建，面向北京理工大学学生提供一站式校园信息体验。

这个项目以 SwiftUI 和 AppKit 为核心，打造了一个拥有原生 macOS 交互体验的校园助手应用，支持课表、成绩、课程评价、校园地图、社区内容和个人中心等功能。

## 项目亮点

### 1. 日程与学习管理
- 课表查看：支持学期切换、周次翻页、日期标注和系统日历导入
- DDL 与考试信息：集中浏览课程相关安排
- 空教室查询：可按教学楼、星期和节次筛选

### 2. 学业与成绩分析
- 成绩查询：支持完整成绩数据读取与学期筛选
- GPA / 加权均分统计：自动计算并展示学业表现
- 成绩趋势图：通过 Swift Charts 展示学期均分与绩点变化
- 成绩导出：支持 PDF 格式导出

### 3. 校园与社区体验
- 校园地图：支持良乡/中关村场景切换，并展示建筑标注
- 社区内容：话题、文章、评论、点赞、发帖与富文本内容渲染
- 多窗口体验：课表、成绩、话题等内容可在独立窗口中打开

### 4. macOS 原生体验
- 菜单栏后台模式：关闭主窗口后仍可保留菜单栏入口
- 课程提醒与勿扰模式：上课前提醒、上课期间自动开启 DND
- 本周课程浮窗：快速查看接下来一周的课程安排
- 深色/浅色/跟随系统三种外观模式

## 技术栈

- SwiftUI + AppKit：界面与窗口管理
- CommonCrypto：统一身份认证加密处理
- Swift Charts：成绩趋势可视化
- MapKit：校园地图展示与标注
- EventKit / .ics：系统日历导入
- UNUserNotificationCenter：课程提醒通知
- CFNotificationCenter：勿扰模式联动

## 运行方式

1. 在 Xcode 中打开项目文件
2. 打开 [BIT101-macOS.xcodeproj](BIT101-macOS.xcodeproj)
3. 选择目标设备或 macOS 桌面运行
4. 按 ⌘R 启动应用

## 项目结构

- [BIT101-macOS/AppDelegate.swift](BIT101-macOS/AppDelegate.swift)：应用生命周期与菜单栏逻辑
- [BIT101-macOS/ContentView.swift](BIT101-macOS/ContentView.swift)：主界面导航与侧边栏
- [BIT101-macOS/Services](BIT101-macOS/Services)：网络请求、加密、日历导入等服务层
- [BIT101-macOS/Views](BIT101-macOS/Views)：各功能页面与组件
- [BIT101-macOS/Models](BIT101-macOS/Models)：数据模型定义

## 更新日志

- 2026-08-03：项目初始化，完成基础页面框架与登录/成绩 UI
- 2026-08-04：接入 BIT101 API，完成登录认证、成绩与课表解析、绩点计算、社区内容与菜单栏后台体验

## 说明

本项目依赖 BIT101 的开放接口，使用前请确保相关服务可访问。若你要继续扩展功能，建议优先从 Services 与 Views 目录入手。
