import SwiftUI

/// First-run screen. Explains the app, then offers a ONE-tap audio download
/// (~127 MB) with real-time progress so playback later is fully offline with no
/// per-tap network stalls. The download runs on the shared `AudioDownloadManager`,
/// so "Boshlash" can dismiss onboarding while it keeps downloading in the
/// background (progress stays visible in Sozlamalar → Offline audio).
struct OnboardingView: View {
    @Environment(AudioDownloadManager.self) private var manager
    /// Called when the user is ready to enter the app (downloaded, skipped, or
    /// chose to continue in the background).
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            identity
            Spacer().frame(height: 40)
            features
            Spacer(minLength: 28)
            downloadSection
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea())
    }

    // MARK: - Identity

    private var identity: some View {
        VStack(spacing: 16) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 168)
                .accessibilityHidden(true)
            Text("Muallimi Soniy")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textMain)
            Text("Ahmad Hodiy Maqsudiy — arab alifbosi darsligi")
                .font(.subheadline)
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(
                symbol: "waveform",
                title: "Toʻgʻri mahrajdan audio",
                subtitle: "Har harf, boʻgʻin va soʻz aniq talaffuz bilan"
            )
            FeatureRow(
                symbol: "book.pages.fill",
                title: "52 sahifa — butun kitob",
                subtitle: "Alifbodan suralar va duolargacha, bespoke koʻrinish"
            )
            FeatureRow(
                symbol: "wifi.slash",
                title: "Internetsiz ishlaydi",
                subtitle: "Audioni bir marta yuklab oling — keyin oflayn, uzilishsiz"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Download section (state machine over AudioDownloadManager.phase)

    @ViewBuilder
    private var downloadSection: some View {
        switch state {
        case .idle:
            VStack(spacing: 12) {
                Text("Ilovadan toʻliq foydalanish uchun audioni (~127 MB) yuklab oling.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textMuted)
                    .multilineTextAlignment(.center)
                primaryButton("Audio yuklab olish", systemImage: "arrow.down.circle.fill") {
                    Task { await manager.ensureReady() }
                }
                skipButton("Keyinroq yuklayman")
            }

        case .working(let label, let fraction):
            VStack(spacing: 12) {
                ProgressView(value: fraction)
                    .tint(AppColor.primary)
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textMuted)
                    .monospacedDigit()
                // The download continues in the background if they enter now.
                primaryButton("Boshlash", systemImage: "play.fill", action: onDone)
                Text("Yuklab olish fonda davom etadi")
                    .font(.caption2)
                    .foregroundStyle(AppColor.textMuted)
            }

        case .ready:
            VStack(spacing: 12) {
                Label("Audio tayyor — ilova oflayn ishlaydi", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
                primaryButton("Boshlash", systemImage: "play.fill", action: onDone)
            }

        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                primaryButton("Qayta urinish", systemImage: "arrow.clockwise") {
                    Task { await manager.ensureReady() }
                }
                skipButton("Yuklamasdan boshlash")
            }
        }
    }

    // MARK: - State mapping

    private enum State {
        case idle
        case working(label: String, fraction: Double)
        case ready
        case failed(String)
    }

    private var state: State {
        switch manager.phase {
        case .ready: return .ready
        case .failed(let m): return .failed(m)
        case .checking: return .working(label: "Tayyorlanmoqda…", fraction: 0)
        case .downloading(let f): return .working(label: "Yuklanmoqda… \(Int((f * 100).rounded()))%", fraction: f)
        case .extracting(let f): return .working(label: "Ochilmoqda…", fraction: f)
        case .verifying(let f): return .working(label: "Tekshirilmoqda…", fraction: f)
        case .idle: return manager.isReady ? .ready : .idle
        }
    }

    // MARK: - Building blocks

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func skipButton(_ title: String) -> some View {
        Button(title, action: onDone)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppColor.textMuted)
            .padding(.top, 2)
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.primary)
                .frame(width: 40, height: 40)
                .background(AppColor.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textMain)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
