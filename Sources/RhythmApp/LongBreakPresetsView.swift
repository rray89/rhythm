import RhythmCore
import SwiftUI

struct LongBreakPresetsView: View {
    let language: AppLanguage
    let onStart: (BreakPreset) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var strings: AppStrings {
        AppStrings(language: language)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(BreakPreset.longBreaks) { preset in
                BreakPresetButton(
                    preset: preset,
                    strings: strings,
                    action: { onStart(preset) }
                )
            }
        }
    }
}

private struct BreakPresetButton: View {
    let preset: BreakPreset
    let strings: AppStrings
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(strings.breakPresetTitle(preset.kind))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(strings.breakDurationValue(preset.durationSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var symbolName: String {
        switch preset.kind {
        case .standard:
            return "pause.circle"
        case .meal:
            return "fork.knife"
        case .gym:
            return "figure.strengthtraining.traditional"
        case .nap:
            return "bed.double"
        case .errand:
            return "bag"
        case .duolingo:
            return "text.book.closed"
        case .walk:
            return "figure.walk"
        }
    }
}
