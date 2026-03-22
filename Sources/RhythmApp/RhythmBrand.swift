import SwiftUI

enum RhythmBrand {
    static let panelBackgroundTop = Color(red: 0.09, green: 0.13, blue: 0.20)
    static let panelBackgroundBottom = Color(red: 0.05, green: 0.08, blue: 0.14)
    static let cardFill = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.14)
    static let accent = Color(red: 0.22, green: 0.84, blue: 0.76)
    static let accentSecondary = Color(red: 0.47, green: 0.70, blue: 0.99)
    static let warning = Color(red: 1.00, green: 0.71, blue: 0.32)
}

struct RhythmLogoMark: View {
    var size: CGFloat = 24
    var detailed: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            RhythmBrand.accent.opacity(0.35),
                            RhythmBrand.panelBackgroundTop
                        ],
                        center: .topLeading,
                        startRadius: size * 0.05,
                        endRadius: size * 0.95
                    )
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [RhythmBrand.accent, RhythmBrand.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.8, size * 0.1)
                )

            RhythmPulseShape()
                .stroke(
                    detailed
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [.white.opacity(0.95), RhythmBrand.accent.opacity(0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.95)),
                    style: StrokeStyle(
                        lineWidth: max(1.4, size * 0.1),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(size * 0.16)
        }
        .frame(width: size, height: size)
        .shadow(color: RhythmBrand.accent.opacity(0.32), radius: size * 0.24, y: size * 0.06)
    }
}

struct RhythmMenuBarLabel: View {
    var body: some View {
        RhythmLogoMark(size: 16, detailed: false)
            .frame(width: 18, height: 18)
            .accessibilityLabel("Rhythm")
    }
}

private struct RhythmPulseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.25, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.16))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.53, y: rect.maxY - rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.31))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.80, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.96, y: midY))
        return path
    }
}
