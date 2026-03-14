import SwiftUI

// MARK: - Color Palette

extension Color {
    // Backgrounds
    static let lunaBackground    = Color(hex: "080810")
    static let lunaSurface       = Color(hex: "0F0F1A")
    static let lunaCard          = Color(hex: "161625")
    static let lunaElevated      = Color(hex: "1E1E30")

    // Accents
    static let lunaAccent        = Color(hex: "7C3AED")   // Deep purple
    static let lunaAccentLight   = Color(hex: "A78BFA")   // Soft purple
    static let lunaGlow          = Color(hex: "6D28D9")   // Glow purple
    static let lunaCyan          = Color(hex: "06B6D4")   // Electric cyan
    static let lunaGold          = Color(hex: "F59E0B")   // Warm gold
    static let lunaPink          = Color(hex: "EC4899")   // Hot pink

    // Text
    static let lunaTextPrimary   = Color.white
    static let lunaTextSecondary = Color(hex: "A0A0B8")
    static let lunaTextMuted     = Color(hex: "606080")

    // Gradients helper
    static let lunaHeroGradient = LinearGradient(
        colors: [.clear, Color(hex: "080810").opacity(0.6), Color(hex: "080810")],
        startPoint: .top,
        endPoint: .bottom
    )

    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

enum LunaFont {
    static func hero() -> Font { .system(size: 34, weight: .black, design: .rounded) }
    static func title1() -> Font { .system(size: 24, weight: .bold, design: .rounded) }
    static func title2() -> Font { .system(size: 20, weight: .bold, design: .rounded) }
    static func title3() -> Font { .system(size: 17, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 15, weight: .regular, design: .rounded) }
    static func caption() -> Font { .system(size: 12, weight: .medium, design: .rounded) }
    static func tag() -> Font { .system(size: 11, weight: .bold, design: .rounded) }
    // Monospaced for numbers (time, stats)
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
}

// MARK: - Gradients

extension LinearGradient {
    static let lunaAccentGradient = LinearGradient(
        colors: [Color.lunaAccent, Color.lunaCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let lunaPurpleGradient = LinearGradient(
        colors: [Color.lunaGlow, Color.lunaAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let lunaDarkGradient = LinearGradient(
        colors: [Color.lunaSurface, Color.lunaBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Press Style (replaces _onButtonGesture)

struct LunaPressStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.lunaSnappy, value: configuration.isPressed)
    }
}

// MARK: - View Modifiers

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.6))
            .background(Color.lunaCard.opacity(0.7))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct AccentButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(LunaFont.body())
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(LinearGradient.lunaAccentGradient)
            .cornerRadius(50)
            .shadow(color: Color.lunaAccent.opacity(0.5), radius: 12, x: 0, y: 4)
    }
}

struct SecondaryButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(LunaFont.body())
            .fontWeight(.semibold)
            .foregroundColor(.lunaTextPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.lunaElevated)
            .cornerRadius(50)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func accentButton() -> some View {
        modifier(AccentButton())
    }

    func secondaryButton() -> some View {
        modifier(SecondaryButton())
    }

    func lunaGlow(color: Color = .lunaAccent, radius: CGFloat = 20) -> some View {
        self.shadow(color: color.opacity(0.4), radius: radius)
    }
}

// MARK: - Haptics

enum LunaHaptic {
    static func light()    { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()    { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success()  { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Animations

extension Animation {
    static let lunaSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let lunaSnappy = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let lunaSmooth = Animation.easeInOut(duration: 0.35)
}

// MARK: - Corner Radius Helpers

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Luna Progress Bar

struct LunaProgressBar: View {
    let progress: Double
    var height: CGFloat = 3
    var color: Color = .lunaAccentLight

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: height)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * CGFloat(progress)), height: height)
            }
        }
        .frame(height: height)
    }
}
