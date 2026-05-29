import AppKit
import RhythmCore
import SwiftUI

struct AboutRhythmView: View {
    @ObservedObject var settingsStore: SettingsStore
    let updater: UpdaterProviding

    @State private var iconHover = false
    @State private var updaterRevision = 0

    private var strings: AppStrings {
        AppStrings(language: settingsStore.effectiveAppLanguage)
    }

    private var releaseInfo: RhythmReleaseInfo {
        RhythmReleaseInfo.fromBundle()
    }

    private var autoUpdateBinding: Binding<Bool> {
        Binding(
            get: { updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates },
            set: { newValue in
                UserDefaults.standard.set(newValue, forKey: "rhythmAutoUpdateEnabled")
                updater.automaticallyChecksForUpdates = newValue
                updater.automaticallyDownloadsUpdates = newValue
            }
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            appIdentitySection
            linkSection
            updateSection
            copyrightSection
        }
        .padding(.top, 28)
        .padding(.horizontal, 42)
        .padding(.bottom, 28)
        .frame(width: 520)
        .onReceive(updater.objectWillChange) { _ in
            updaterRevision += 1
        }
    }

    private var appIdentitySection: some View {
        VStack(spacing: 10) {
            Button(action: { openURL("https://github.com/rray89/rhythm") }) {
                appIcon
                    .frame(width: 92, height: 92)
                    .scaleEffect(iconHover ? 1.04 : 1.0)
                    .shadow(color: iconHover ? .accentColor.opacity(0.24) : .clear, radius: 6)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    iconHover = hovering
                }
            }

            VStack(spacing: 4) {
                Text("Rhythm")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(releaseInfo.versionDisplay)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if let buildDisplay = releaseInfo.buildDisplay(language: settingsStore.effectiveAppLanguage) {
                    Text(buildDisplay)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(strings.aboutTagline)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = NSApplication.shared.applicationIconImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.teal.gradient)
                RhythmMenuLogo(size: 56)
                    .foregroundStyle(.white)
            }
        }
    }

    private var linkSection: some View {
        VStack(spacing: 0) {
            Divider()
            AboutLinkRow(
                systemImage: "chevron.left.slash.chevron.right",
                title: strings.githubLinkTitle,
                detail: "github.com/rray89/rhythm",
                action: { openURL("https://github.com/rray89/rhythm") }
            )
            AboutLinkRow(
                systemImage: "tag",
                title: strings.releasesLinkTitle,
                detail: "github.com/rray89/rhythm/releases",
                action: { openURL("https://github.com/rray89/rhythm/releases") }
            )
            AboutLinkRow(
                systemImage: "doc",
                title: strings.licenseLinkTitle,
                detail: strings.licenseValue,
                action: { openURL("https://github.com/rray89/rhythm/blob/main/LICENSE") }
            )
            Divider()
        }
    }

    private var updateSection: some View {
        VStack(spacing: 10) {
            Toggle(strings.autoUpdateToggleTitle, isOn: autoUpdateBinding)
                .toggleStyle(.checkbox)
                .disabled(!updater.canCheckForUpdates)

            HStack(spacing: 10) {
                Button(strings.checkForUpdatesButton) {
                    updater.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(!updater.canCheckForUpdates)

                if updater.isUpdateReadyToInstall {
                    Button(strings.installUpdateButton) {
                        updater.installUpdate()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(updateStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var updateStatusText: String {
        if updater.isUpdateReadyToInstall {
            return strings.updaterReadyToInstallLabel
        }
        let message = updater.availability.localizedMessage(language: settingsStore.effectiveAppLanguage)
        return updater.canCheckForUpdates ? strings.directReleaseOnlyLabel : message
    }

    private var copyrightSection: some View {
        Text("© 2026 Rhythm. MIT License.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct AboutLinkRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }
}
