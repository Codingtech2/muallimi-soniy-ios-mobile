import SwiftUI

/// The single-row audio bar — the SwiftUI port of the web `AudioControls`.
///
/// Reads the shared `AudioController` from the environment so its scrubber and
/// play / pause glyph stay live as playback progresses. Layout (one row): prev,
/// play-pause, next, elapsed time, a seekable progress bar, total time, and a
/// loop toggle. No speed control — playback is always 1× (user decision).
///
/// The play-pause / prev / next intents are owned by the reader (they depend on
/// the active element and sequential state), so they arrive as closures. Seeking
/// is self-contained and calls `AudioController.seek` directly.
struct AudioControls: View {
    @Environment(AudioController.self) private var audio

    /// Whether loop mode is on (drives the toggle's active styling).
    let loopOn: Bool
    /// Accessibility label for the loop button (localised "Takror").
    let loopLabel: String
    /// Localised accessibility labels for the transport buttons.
    let playLabel: String
    let pauseLabel: String
    let prevLabel: String
    let nextLabel: String
    let onPlayPause: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void
    let onToggleLoop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            skipButton("backward.end.fill", label: prevLabel, action: onPrev)
            playButton
            skipButton("forward.end.fill", label: nextLabel, action: onNext)

            Text(Self.formatTime(audio.currentTime))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(AppColor.textMuted)
                .frame(width: 34, alignment: .trailing)

            progressBar

            Text(Self.formatTime(audio.duration))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(AppColor.textMuted)
                .frame(width: 34, alignment: .leading)

            loopButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // Floating Liquid-Glass audio bar (real glass on iOS 26, frosted material
        // + hairline below). The solid-green play button stays the primary action.
        .glassCard(cornerRadius: 24)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Buttons

    private var playButton: some View {
        Button(action: onPlayPause) {
            Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .bold))
                // Web `text-bg-dark`: the page-background token, so the glyph
                // flips with the theme (light on light green, dark on dark green).
                .foregroundStyle(AppColor.background)
                .offset(x: audio.isPlaying ? 0 : 1)  // web `ml-0.5` on the play glyph
                .frame(width: 40, height: 40)
                .background(AppColor.primary, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(audio.isPlaying ? pauseLabel : playLabel)
    }

    private var loopButton: some View {
        Button(action: onToggleLoop) {
            Image(systemName: "repeat")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(loopOn ? AppColor.primary : AppColor.textMuted)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(loopOn ? AppColor.primary.opacity(0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loopLabel)
    }

    private func skipButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColor.textMuted)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Seekable progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = audio.duration > 0 ? CGFloat(audio.currentTime / audio.duration) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.divider).frame(height: 4)
                Capsule().fill(AppColor.primary).frame(width: max(0, width * pct), height: 4)
                Circle()
                    .fill(AppColor.primary)
                    .frame(width: 12, height: 12)
                    .shadow(color: AppColor.primaryGlow, radius: 4, x: 0, y: 0)
                    .offset(x: min(max(width * pct - 6, 0), width - 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard audio.duration > 0, width > 0 else { return }
                        let ratio = min(max(value.location.x / width, 0), 1)
                        audio.seek(Double(ratio) * audio.duration)
                    }
            )
        }
        .frame(height: 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatting

    /// `m:ss`, matching the web `formatTime`. Guards against NaN / negative
    /// durations (an unloaded track reports `0`).
    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#if DEBUG
#Preview("AudioControls") {
    VStack {
        Spacer()
        AudioControls(
            loopOn: true,
            loopLabel: "Takror",
            playLabel: "Ijro",
            pauseLabel: "Pauza",
            prevLabel: "Oldingi",
            nextLabel: "Keyingi",
            onPlayPause: {},
            onPrev: {},
            onNext: {},
            onToggleLoop: {}
        )
        .environment(AudioController())
    }
    .background(AppColor.background)
}
#endif
