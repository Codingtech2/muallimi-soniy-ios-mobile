import SwiftUI

/// Sits above `ReaderControlBar` (under a hifz strip, if any) while the audio
/// pack is downloading — or its last attempt failed — and the sheet that
/// tracks it is closed, so the download stays visible until it is done.
/// Tapping it reopens `AudioDownloadSheet`. Every colour comes from
/// `\.readingTheme`, like `HifzStatusStrip` and the control bar.
struct AudioDownloadStrip: View {
    /// The running stage ("Yuklanmoqda…") or the failure title.
    let title: String
    /// Overall 0…1 progress; `nil` once the download has failed.
    let fraction: Double?
    /// VoiceOver hint for the tap ("opens the download details").
    let openLabel: String
    let onTap: () -> Void

    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.layoutMetrics) private var layoutMetrics

    private var percent: String? {
        fraction.map { "\(AudioDownloadStatus.percent($0))%" }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6 * layoutMetrics.uiScale) {
                HStack(spacing: 10 * layoutMetrics.uiScale) {
                    Image(systemName: fraction == nil ? "exclamationmark.triangle.fill" : "arrow.down.circle")
                        .foregroundStyle(fraction == nil ? Color.red : readingTheme.textSecondary)
                    Text(title)
                        .foregroundStyle(readingTheme.textMain)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let percent {
                        Text(percent)
                            .monospacedDigit()
                            .foregroundStyle(readingTheme.textSecondary)
                    } else {
                        Image(systemName: "chevron.up")
                            .foregroundStyle(readingTheme.textMuted)
                    }
                }
                .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
                if let fraction {
                    ProgressView(value: fraction)
                        .tint(AppColor.primary)
                }
            }
            .padding(.horizontal, 16 * layoutMetrics.uiScale)
            .padding(.vertical, 10 * layoutMetrics.uiScale)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Opaque like the control bar: the page scrolls under this inset.
        .background(readingTheme.cardFill)
        .background(readingTheme.pageFill)
        .overlay(alignment: .top) {
            Rectangle().fill(readingTheme.divider).frame(height: 0.5)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(percent ?? "")
        .accessibilityHint(openLabel)
        .accessibilityAddTraits([.isButton, .updatesFrequently])
    }
}
