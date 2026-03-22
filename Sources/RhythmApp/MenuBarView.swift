import AppKit
import RhythmCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            statusSection
            configSection
            sessionsSection
            actionSection
        }
        .padding(14)
        .frame(width: 390)
        .background(
            LinearGradient(
                colors: [RhythmBrand.panelBackgroundTop, RhythmBrand.panelBackgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Circle()
                    .fill(RhythmBrand.accent.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .offset(x: 140, y: -120)
            )
        )
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            RhythmLogoMark(size: 28, detailed: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rhythm")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.98))
                Text("Find your computer rhythm")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Text(timerEngine.mode == .focusing ? "专注" : "休息")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(timerEngine.mode == .focusing ? RhythmBrand.accent : RhythmBrand.warning)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )
        }
        .padding(12)
        .background(cardBackground)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("当前节奏")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
            if timerEngine.mode == .focusing {
                Text("距离休息还有")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
                Text(formatDuration(timerEngine.secondsUntilBreak))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } else {
                Text("休息遮罩已显示，按 ESC 可跳过")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("节奏设置")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))

            HStack {
                Text("专注时长")
                    .foregroundStyle(.white.opacity(0.93))
                Spacer()
                Stepper(
                    value: Binding(
                        get: { settingsStore.focusMinutes },
                        set: { settingsStore.focusMinutes = $0 }
                    ),
                    in: 1 ... 240
                ) {
                    Text("\(settingsStore.focusMinutes) 分钟")
                        .frame(width: 100, alignment: .trailing)
                        .foregroundStyle(.white.opacity(0.95))
                }
                .frame(width: 180)
            }

            HStack {
                Text("休息时长")
                    .foregroundStyle(.white.opacity(0.93))
                Spacer()
                Stepper(
                    value: Binding(
                        get: { settingsStore.restMinutes },
                        set: { settingsStore.restMinutes = $0 }
                    ),
                    in: 1 ... 90
                ) {
                    Text("\(settingsStore.restMinutes) 分钟")
                        .frame(width: 100, alignment: .trailing)
                        .foregroundStyle(.white.opacity(0.95))
                }
                .frame(width: 180)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近记录")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
                Spacer()
                Text("\(sessionStore.sessions.count) 次")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.50))
            }

            if sessionStore.sessions.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                ForEach(sessionStore.sessions.prefix(5)) { session in
                    HStack {
                        Text(timeLabel(session.startedAt))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text(
                            session.skipped
                                ? "跳过 \(formatDuration(session.actualRestSeconds))"
                                : "完成 \(formatDuration(session.actualRestSeconds))"
                        )
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(session.skipped ? RhythmBrand.warning : RhythmBrand.accent)
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var actionSection: some View {
        HStack {
            if timerEngine.mode == .focusing {
                Button("立即休息") {
                    timerEngine.startBreakNow()
                }
                .buttonStyle(.borderedProminent)
                .tint(RhythmBrand.accent.opacity(0.90))
            } else {
                Button("跳过本次休息") {
                    timerEngine.skipBreak()
                }
                .buttonStyle(.borderedProminent)
                .tint(RhythmBrand.warning.opacity(0.90))
            }

            Button("重置计时") {
                timerEngine.resetCycle()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(RhythmBrand.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(RhythmBrand.cardStroke, lineWidth: 1)
            )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minute = max(0, seconds) / 60
        let second = max(0, seconds) % 60
        return String(format: "%02d:%02d", minute, second)
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
