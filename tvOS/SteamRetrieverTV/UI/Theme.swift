// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// "Steam Retriever Big Picture": Big Picture's navy feel, no Valve logos or artwork.

import SwiftUI

enum Theme {
    static let background = Color(hex: 0x171D25)
    static let panel = Color(hex: 0x1B2838)
    static let accent = Color(hex: 0x2A475E)
    static let highlight = Color(hex: 0x66C0F4)
    static let brass = Color(hex: 0xC9A25C)       // Sprocket's goggles; used sparingly
    static let text = Color(hex: 0xE6EDF3)
    static let subtext = Color(hex: 0x8F98A0)
    static let good = Color(hex: 0x5BA32B)
    static let bad = Color(hex: 0xD9534F)

    static let tileCorner: CGFloat = 14
    static let posterSize = CGSize(width: 220, height: 330)
    static let navWidth: CGFloat = 330
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Focus = the tile scales up with a soft blue glow.
struct TileButtonStyle: ButtonStyle {
    var corner: CGFloat = Theme.tileCorner

    func makeBody(configuration: Configuration) -> some View {
        TileBody(configuration: configuration, corner: corner)
    }

    private struct TileBody: View {
        let configuration: ButtonStyleConfiguration
        let corner: CGFloat
        @Environment(\.isFocused) private var focused

        var body: some View {
            configuration.label
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Theme.highlight.opacity(focused ? 0.9 : 0), lineWidth: 3)
                )
                .shadow(color: Theme.highlight.opacity(focused ? 0.55 : 0), radius: focused ? 28 : 0)
                .scaleEffect(configuration.isPressed ? 1.02 : (focused ? 1.1 : 1))
                .animation(.easeOut(duration: 0.16), value: focused)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }
    }
}

/// Flat rows (side nav, setup steps, settings buttons).
struct RowButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration, selected: selected)
    }

    private struct RowBody: View {
        let configuration: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isFocused) private var focused

        var body: some View {
            configuration.label
                .font(.system(size: 30, weight: focused || selected ? .semibold : .regular))
                .foregroundStyle(focused ? Theme.background : (selected ? Theme.highlight : Theme.text))
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(focused ? Theme.highlight : (selected ? Theme.accent.opacity(0.6) : .clear))
                )
                .scaleEffect(focused ? 1.03 : 1)
                .animation(.easeOut(duration: 0.14), value: focused)
        }
    }
}

/// The big blue Play button and other primary actions.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryBody(configuration: configuration)
    }

    private struct PrimaryBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var focused
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(enabled ? (focused ? Theme.background : Theme.text) : Theme.subtext)
                .padding(.horizontal, 48)
                .padding(.vertical, 18)
                .background(
                    Capsule().fill(enabled ? (focused ? Theme.highlight : Theme.accent) : Theme.panel)
                )
                .shadow(color: Theme.highlight.opacity(focused && enabled ? 0.5 : 0), radius: 20)
                .scaleEffect(focused ? 1.08 : 1)
                .animation(.easeOut(duration: 0.14), value: focused)
        }
    }
}

struct EnvBadge: View {
    let env: GameEnv

    var body: some View {
        Label(env.label, systemImage: env == .mac ? "apple.logo" : "pc")
            .font(.system(size: 22, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.accent))
            .foregroundStyle(Theme.text)
    }
}

/// Sprocket, the Steam Retriever pup.
struct SprocketBadge: View {
    var size: CGFloat = 260
    @State private var bob = false

    var body: some View {
        Image("Sprocket")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(y: bob ? -8 : 8)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: bob)
            .onAppear { bob = true }
            .accessibilityLabel("Sprocket")
    }
}
