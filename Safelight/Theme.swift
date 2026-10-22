import SwiftUI

/// The darkroom palette: everything is lit by one red safelight.
enum Darkroom {
    static let black = Color(red: 0.035, green: 0.016, blue: 0.016)
    static let wall = Color(red: 0.085, green: 0.035, blue: 0.03)
    static let panel = Color(red: 0.13, green: 0.045, blue: 0.04)
    static let safelight = Color(red: 0.89, green: 0.17, blue: 0.12)
    static let ember = Color(red: 0.45, green: 0.07, blue: 0.05)
    static let amber = Color(red: 0.97, green: 0.73, blue: 0.46)
    static let paper = Color(red: 0.95, green: 0.89, blue: 0.80)
    static let dim = Color(red: 0.66, green: 0.43, blue: 0.37)
    static let filmBase = Color(red: 0.17, green: 0.085, blue: 0.03)
    static let edgeprint = Color(red: 0.98, green: 0.55, blue: 0.18)

    static func title(_ size: CGFloat) -> Font { .custom("AmericanTypewriter-Bold", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("AmericanTypewriter", size: size) }
    static func stencil(_ size: CGFloat) -> Font { .custom("Courier-Bold", size: size) }
}

/// Black room, red glow from the lamp overhead, a little film grain.
struct DarkroomBackground: View {
    var lit: Bool

    var body: some View {
        ZStack {
            Darkroom.black
            RadialGradient(
                colors: [Darkroom.safelight.opacity(lit ? 0.36 : 0.10), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 4,
                endRadius: 560
            )
            .animation(.easeInOut(duration: 1.2), value: lit)
            FilmGrain()
                .opacity(0.07)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct FilmGrain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x5AFE_1167
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 33) / Double(UInt64(1) << 31)
            }
            let count = Int(size.width * size.height / 90)
            for _ in 0..<count {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 1.2, height: 1.2)
                context.fill(Path(rect), with: .color(.white.opacity(next() * 0.8)))
            }
        }
    }
}

/// The safelight lamp. Glows when the camera is on the bench.
struct SafelightLamp: View {
    var on: Bool
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Darkroom.ember.opacity(0.35))
                .frame(width: 48, height: 48)
            Circle()
                .fill(
                    RadialGradient(
                        colors: on
                            ? [Color(red: 1, green: 0.5, blue: 0.4), Darkroom.safelight, Darkroom.ember]
                            : [Darkroom.ember, Darkroom.wall],
                        center: .center,
                        startRadius: 1,
                        endRadius: 18
                    )
                )
                .frame(width: 34, height: 34)
                .shadow(color: Darkroom.safelight.opacity(on ? 0.9 : 0), radius: on ? (breathe ? 16 : 26) : 0)
            Circle()
                .stroke(Darkroom.dim.opacity(0.5), lineWidth: 2)
                .frame(width: 48, height: 48)
        }
        .animation(.easeInOut(duration: 0.6), value: on)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityLabel(on ? "Camera connected" : "Camera not connected")
    }
}

struct SectionLabel: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(Darkroom.stencil(15))
                .tracking(3)
                .foregroundStyle(Darkroom.safelight)
            Spacer()
            if let detail {
                Text(detail)
                    .font(Darkroom.body(13))
                    .foregroundStyle(Darkroom.dim)
            }
        }
    }
}

struct Panel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Darkroom.wall.opacity(0.88)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Darkroom.ember.opacity(0.7), lineWidth: 1))
    }
}

struct DarkroomButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        StyledLabel(configuration: configuration, prominent: prominent)
    }

    private struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Darkroom.title(16))
                .foregroundStyle(prominent ? Darkroom.black : Darkroom.amber)
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(prominent ? Darkroom.safelight : Darkroom.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Darkroom.safelight.opacity(prominent ? 0 : 0.55), lineWidth: 1)
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Darkroom.body(15))
            .foregroundStyle(Darkroom.paper)
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(Capsule().fill(Darkroom.panel))
            .overlay(Capsule().stroke(Darkroom.safelight.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 12, y: 4)
            .padding(.horizontal, 24)
    }
}
