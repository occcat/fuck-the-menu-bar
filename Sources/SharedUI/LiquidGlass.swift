import AppKit
import SwiftUI

/// Liquid Glass design system shared by the overlay and (later) the settings UI.
///
/// On macOS 26+ built with the Xcode 26 SDK (Swift 6.2+), surfaces use the native
/// `glassEffect` / `GlassEffectContainer` APIs. On older systems or older SDKs they fall
/// back to a Material + specular rim approximation. The fallback honours
/// "Reduce Transparency"; native glass handles accessibility settings itself.
public enum LiquidGlassStyle {
    case regular
    case clear
    case tinted(Color)

    var tintColor: Color? {
        if case let .tinted(color) = self { return color }
        return nil
    }

    var fallbackMaterial: Material {
        switch self {
        case .regular, .tinted: .thinMaterial
        case .clear: .ultraThinMaterial
        }
    }
}

public enum LiquidGlass {
    /// `true` when the native Liquid Glass APIs are compiled in and available at runtime.
    public static var isNativelyAvailable: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            return true
        }
        #endif
        return false
    }
}

/// Motion tokens. `base` is the user-facing `AppearanceSettings.animationDuration`.
public enum LiquidMotion {
    public static func duration(base: Double) -> Double {
        min(max(base * 1.6, 0.2), 0.7)
    }

    public static func spring(base: Double, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: duration(base: base), bounce: 0.22)
    }

    /// How long a window must stay large so a removal transition can finish without clipping.
    public static func settleDuration(base: Double, reduceMotion: Bool) -> Double {
        reduceMotion ? 0.14 : duration(base: base) + 0.08
    }
}

public extension View {
    /// Places a Liquid Glass surface behind the view, clipped to `shape`.
    func liquidGlass<S: Shape>(
        _ style: LiquidGlassStyle = .regular,
        in shape: S,
        interactive: Bool = false
    ) -> some View {
        modifier(LiquidGlassSurface(shape: shape, style: style, interactive: interactive))
    }

    /// Adds a glass sheen *above* the view (native clear glass on macOS 26, rim highlight otherwise).
    /// Useful on top of opaque content that must stay opaque, e.g. the menu bar masks.
    func liquidGlassHighlight<S: Shape>(in shape: S) -> some View {
        modifier(LiquidGlassHighlight(shape: shape))
    }
}

/// Groups glass surfaces so they can blend and morph (native `GlassEffectContainer` on macOS 26).
public struct LiquidGlassGroup<Content: View>: View {
    private let spacing: CGFloat?
    private let content: Content

    public init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

struct LiquidGlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let style: LiquidGlassStyle
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(nativeGlass, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    private var nativeGlass: Glass {
        let glass: Glass
        switch style {
        case .regular:
            glass = .regular
        case .clear:
            glass = .clear
        case let .tinted(color):
            glass = Glass.regular.tint(color)
        }
        return interactive ? glass.interactive() : glass
    }
    #endif

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(Color(nsColor: .windowBackgroundColor))
                    } else {
                        shape.fill(style.fallbackMaterial)
                        if let tint = style.tintColor {
                            shape.fill(tint.opacity(0.18))
                        }
                    }
                }
                .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
            }
            .overlay {
                LiquidGlassRim(shape: shape)
            }
    }
}

struct LiquidGlassHighlight<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.overlay {
                Color.clear
                    .glassEffect(.clear, in: shape)
                    .allowsHitTesting(false)
            }
        } else {
            content.overlay { LiquidGlassRim(shape: shape) }
        }
        #else
        content.overlay { LiquidGlassRim(shape: shape) }
        #endif
    }
}

/// Specular rim used by the pre-macOS 26 fallback.
struct LiquidGlassRim<S: Shape>: View {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        shape
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDark ? 0.32 : 0.6),
                        Color.white.opacity(0.04),
                        Color.white.opacity(isDark ? 0.14 : 0.3),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
            .allowsHitTesting(false)
    }
}
