//
//  DesignSystem.swift - 液态玻璃（Liquid Glass）设计系统
//
//  遵循 UI UX Pro Max 玻璃态规则：
//  - 浅色模式玻璃底 ≥80% 不透明度，描边清晰可见（白 0.45）
//  - 深色模式描边白 0.18，顶部内高光增强玻璃质感
//  - 文字深色保证 4.5:1 对比度；交互反馈 150-300ms
//
import SwiftUI

// MARK: - 品牌色

extension Color {
    static let bitOrange = Color(red: 1.0, green: 0.604, blue: 0.341)
    static let bitBlue   = Color(red: 0.0, green: 0.671, blue: 0.839)

    /// 各模块主题色（亮色中调，深浅色玻璃上都清晰醒目）
    static let moduleSchedule = Color(red: 0.56, green: 0.47, blue: 0.98)   // 日程·亮靛蓝
    static let moduleMap      = Color(red: 0.27, green: 0.78, blue: 0.57)   // 地图·亮绿
    static let moduleGallery  = Color(red: 1.00, green: 0.60, blue: 0.28)   // 话廊·亮橙
    static let moduleScore    = Color(red: 0.98, green: 0.43, blue: 0.62)   // 学业·亮粉
    static let moduleMine     = Color(red: 0.32, green: 0.58, blue: 0.98)   // 我的·亮蓝
}

// MARK: - 设计令牌（8pt 网格）

enum Sp {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let pill: CGFloat = 999
}

enum Typo {
    static func stat(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .rounded).weight(.bold)
    }
    static func header(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .rounded).weight(.bold)
    }
    static func body(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .default)
    }
    static func caption(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .rounded)
    }
}

// MARK: - 背景（正常系统色，保留极淡色调供玻璃采样）

struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            // 环境光（液态玻璃 scene）：多角度椭圆光晕，给玻璃提供清晰可采样的层次
            Ellipse()
                .fill(Color.blue.opacity(scheme == .dark ? 0.10 : 0.16))
                .blur(radius: 120)
                .frame(width: 720, height: 520).rotationEffect(.degrees(-20))
                .offset(x: -320, y: -280)
            Ellipse()
                .fill(Color.bitOrange.opacity(scheme == .dark ? 0.08 : 0.14))
                .blur(radius: 140)
                .frame(width: 760, height: 560).rotationEffect(.degrees(25))
                .offset(x: 340, y: 300)
            Ellipse()
                .fill(Color.teal.opacity(scheme == .dark ? 0.07 : 0.10))
                .blur(radius: 150)
                .frame(width: 640, height: 500).rotationEffect(.degrees(12))
                .offset(x: 300, y: -380)
            Ellipse()
                .fill(Color(red: 0.95, green: 0.88, blue: 0.80).opacity(scheme == .dark ? 0.05 : 0.12))
                .blur(radius: 130)
                .frame(width: 600, height: 480).rotationEffect(.degrees(-12))
                .offset(x: -300, y: 360)
        }
        .ignoresSafeArea()
        // 离屏合成：运动/缩放时不再逐帧重算模糊，避免掉帧和背景色闪变
        .drawingGroup()
    }
}

// MARK: - 玻璃表面

/// 玻璃圆角形状
struct GlassSurfaceStyle: ViewModifier {
    var corner: CGFloat = Radius.lg
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous).fill(.ultraThinMaterial)
            }
            // 低 tint 玻璃：让环境光透出，与侧边栏观感一致
            .glassEffect(.regular.tint(scheme == .dark ? .black.opacity(0.35) : .white.opacity(0.22)),
                         in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(scheme == .dark ? .white.opacity(0.15) : .white.opacity(0.22), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                // 顶部内高光：玻璃光泽关键
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.12 : 0.30), .clear],
                                         startPoint: .top, endPoint: .center))
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                // 底部内暗线：玻璃下沿切边（液态玻璃 specular）
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(colors: [.clear, .black.opacity(scheme == .dark ? 0.28 : 0.04)],
                                         startPoint: .top, endPoint: .bottom))
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(scheme == .dark ? 0.28 : 0.05), radius: 8, x: 0, y: 3)
    }
}

extension View {
    /// 完整玻璃卡片（含内边距）
    func glassCard(_ corner: CGFloat = Radius.lg) -> some View {
        padding(14).modifier(GlassSurfaceStyle(corner: corner))
    }
    /// 仅玻璃背景（由视图自行控制内边距）
    func glassSurface(_ corner: CGFloat = Radius.lg) -> some View {
        modifier(GlassSurfaceStyle(corner: corner))
    }
}

// MARK: - 统计磁贴

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(color.gradient))
            Text(value)
                .font(Typo.stat())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Sp.m)
        .glassSurface(Radius.lg)
    }
}

// MARK: - 胶囊筛选 Chip

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, Sp.m)
                .padding(.vertical, 5)
                .background {
                    if selected {
                        Capsule().fill(.tint)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
                .foregroundColor(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(Anim.soft(), value: selected)
    }
}

// MARK: - 模块图标

struct ModuleIcon: View {
    let icon: String
    let color: Color
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(color.gradient))
    }
}

// MARK: - 玻璃按钮（主操作用系统 .glass；此处提供次级/危险变体）

/// 次级按钮：玻璃底 + 细描边胶囊（替代 .bordered）
struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, Sp.m)
            .padding(.vertical, 5)
            .background {
                Capsule().fill(.ultraThinMaterial)
            }
            .overlay {
                Capsule().strokeBorder(.secondary.opacity(0.4), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 危险按钮：玻璃底 + 红字（替代 .borderedProminent 红色）
struct GlassDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.red)
            .padding(.horizontal, Sp.m)
            .padding(.vertical, 5)
            .background {
                Capsule().fill(.ultraThinMaterial)
            }
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassSecondaryButtonStyle {
    static var glassSecondary: GlassSecondaryButtonStyle { .init() }
}
extension ButtonStyle where Self == GlassDestructiveButtonStyle {
    static var glassDestructive: GlassDestructiveButtonStyle { .init() }
}

// MARK: - 统一搜索框（GlassSearchField）

struct GlassSearchField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Sp.xs) {
            Image(systemName: "magnifyingglass")
                .font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain).font(.callout)
                .onSubmit { onSubmit?() }
            if !text.isEmpty {
                Button {
                    text = ""
                    onSubmit?()
                } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.tertiary)
                    .wideHitArea(20)
            }
        }
        .padding(.horizontal, Sp.s)
        .padding(.vertical, Sp.xs + 1)
        .glassSurface(Radius.sm)
    }
}

// MARK: - 可点卡片的悬停反馈（hover 提亮描边，150-300ms，不位移布局）

struct HoverCardStyle: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.tint.opacity(hovering ? 0.55 : 0.0), lineWidth: 1.5)
            }
            .scaleEffect(hovering ? 1.012 : 1.0)
            .onHover { h in
                withAnimation(Anim.soft(Anim.quick)) { hovering = h }
            }
    }
}

extension View {
    /// 可点卡片的悬停反馈（轻微描边提亮 + 1% 放大，不位移布局）
    func hoverCard() -> some View {
        modifier(HoverCardStyle())
    }
}

// MARK: - 页面头部

/// 统一页面头部：模块色图标 + 主标题 + 副标题 + 右侧动作区
/// 用法：`PageHeader(icon:title:tint:) {}` 或 `PageHeader(icon:title:tint:) { 动作按钮 }`
struct PageHeader<Actions: View>: View {
    let icon: String
    let title: String
    var subtitle: String?
    var tint: Color
    let actions: () -> Actions

    init(icon: String, title: String, subtitle: String? = nil, tint: Color = .bitBlue,
         @ViewBuilder actions: @escaping () -> Actions) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.actions = actions
    }

    var body: some View {
        HStack(spacing: 12) {
            ModuleIcon(icon: icon, color: tint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.header()).foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            actions()
        }
        .padding(.horizontal, Sp.l)
        .padding(.top, Sp.m)
        .padding(.bottom, Sp.s)
    }
}

// MARK: - 玻璃输入框

/// 玻璃化输入框（替代 .textFieldStyle(.roundedBorder)），聚焦时有模块色描边
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var onSubmit: (() -> Void)? = nil
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Sp.xs) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.callout)
            .focused($focused)
            .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, Sp.s)
        .padding(.vertical, Sp.xs + 1)
        .glassSurface(Radius.sm)
        .overlay {
            if focused {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(.tint.opacity(0.6), lineWidth: 2)
            }
        }
    }
}

// MARK: - 圆形头像

/// 圆形头像（图片 / 首字 / 图标三态），复用 ModuleIcon 的渐变语言
struct GlassAvatar: View {
    var url: URL? = nil
    var name: String = ""
    var icon: String = "person.fill"
    var color: Color = .bitBlue
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private var fallback: some View {
        ZStack {
            Circle().fill(color.gradient)
            if name.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - 细分隔线

/// 发丝细分隔线（替代裸 Divider）
struct GlassDivider: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, inset)
    }
}

// MARK: - 玻璃列表行

/// 玻璃化列表行容器（替代原生 List 行，供消息 / 关注列表等使用）
struct GlassListItem<Content: View>: View {
    var corner: CGFloat = Radius.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Sp.m)
            .glassSurface(corner)
            .hoverCard()
    }
}

// MARK: - 独立详情窗口背景

/// 独立详情窗口 / 弹窗的玻璃背景包装（openDetailWindow 打开的窗口没有外层背景）
/// 填满可用空间并裁剪，避免内容/背景超出窗口边界（出界）。内边距由各详情视图自行控制。
struct DetailGlassBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            LiquidGlassBackground()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
    }
}

// MARK: - 统一评论卡片

/// 玻璃化评论行（含回复），供话题/文章/课程评价共用
struct CommentCard: View {
    let nickname: String?
    let text: String?
    let time: String?
    var subs: [CommentItem]? = nil

    var body: some View {
        GlassListItem(corner: Radius.md) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GlassAvatar(name: nickname ?? "", size: 22)
                    Text(nickname ?? "用户").font(.caption.weight(.semibold))
                    Spacer()
                    Text(time ?? "").font(.caption2).foregroundStyle(.secondary)
                }
                Text(text ?? "").font(.callout)
                if let subs {
                    ForEach(subs) { s in
                        HStack(alignment: .top, spacing: 6) {
                            Text("↳").font(.caption2).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.user?.nickname ?? "").font(.caption.weight(.semibold))
                                Text(s.text ?? "").font(.caption)
                            }
                        }
                        .padding(.leading, Sp.m)
                    }
                }
            }
        }
    }
}

// MARK: - Sheet / 弹窗玻璃背景

extension View {
    /// 让 sheet / 弹窗拥有与应用一致的液态玻璃背景
    func glassSheetBackground() -> some View {
        background(LiquidGlassBackground())
    }
}

// MARK: - 动效令牌（GSAP 动效原则的 SwiftUI 实现）

enum Anim {
    /// 微交互：悬停/按压（150ms）
    static let quick = 0.15
    /// 常规过渡（200ms）
    static let normal = 0.2
    /// 入场/较大过渡（300ms）
    static let slow = 0.3
    /// 标准出场缓动（easeOut，快入慢出）
    static func soft(_ duration: Double = Anim.normal) -> Animation {
        .easeOut(duration: duration)
    }
    /// 弹簧微交互（有轻微回弹，用于 hover 放大等）
    static func spring() -> Animation {
        .spring(duration: 0.4, bounce: 0.12)
    }
}

/// 卡片入场：淡入 + 轻微上浮（轻量，保证流畅）
struct EntranceStyle: ViewModifier {
    @State private var visible = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 4)
            .onAppear {
                withAnimation(Anim.soft(0.16).delay(delay)) { visible = true }
            }
    }
}

extension View {
    /// 卡片入场动画（淡入 + 上浮 6pt）
    func entrance(delay: Double = 0) -> some View {
        modifier(EntranceStyle(delay: delay))
    }
}

/// 复制文本到剪贴板（右键菜单 / 按钮用）
func copyText(_ s: String) {
    let p = NSPasteboard.general
    p.clearContents()
    p.setString(s, forType: .string)
}

extension View {
    /// 扩大点击范围：整个按钮区域都可点，不必精确点中图标/文字
    func wideHitArea(_ min: CGFloat = 26) -> some View {
        frame(minWidth: min, minHeight: min)
            .contentShape(Rectangle())
    }

    /// 条件隐藏标题栏默认的侧边栏切换按钮
    @ViewBuilder
    func hideSidebarToggle(_ hide: Bool) -> some View {
        if hide {
            toolbar(removing: ToolbarDefaultItemKind.sidebarToggle)
        } else {
            self
        }
    }
}

// MARK: - 窗口宽度监听

/// 上报当前窗口内容宽度（用于窄窗口自动收起侧边栏）
struct WindowWidthReader: NSViewRepresentable {
    var onChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> WidthView {
        let v = WidthView()
        v.onChange = onChange
        return v
    }
    func updateNSView(_ nsView: WidthView, context: Context) {
        nsView.onChange = onChange
    }

    final class WidthView: NSView {
        var onChange: ((CGFloat) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let win = window else { return }
            let report: (Notification?) -> Void = { [weak self] _ in
                guard let self, let w = self.window else { return }
                self.onChange?(w.contentLayoutRect.width)
            }
            NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: win, queue: .main, using: report)
            report(nil)
        }

        override var intrinsicContentSize: NSSize { NSSize(width: 1, height: 1) }
    }
}
