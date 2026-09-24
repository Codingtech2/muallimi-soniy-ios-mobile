import Foundation
import OSLog

/// Remote transport — which lock-screen / Control-Centre / headset buttons are
/// live, and where their presses go. Kept apart from `AudioController.swift`
/// only to hold that file within SwiftLint's length limits.
extension AudioController {
    private static let remoteLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "AudioController"
    )

    /// Clears the lock-screen entry without touching playback — e.g. when a
    /// page sequence has run out, so its last ayah doesn't linger there.
    func clearNowPlaying() {
        nowPlaying.clear()
        refreshRemoteTrackCommands()
    }

    /// Re-evaluates whether the lock-screen next / previous buttons can do
    /// anything. Runs whenever the handlers change and whenever the Now
    /// Playing entry is set or cleared — every point where the reader's
    /// active element (and so what next / previous would reach) moves.
    func refreshRemoteTrackCommands() {
        nowPlaying.setTrackCommandsEnabled(
            next: isRemoteSkipAvailable(by: 1),
            previous: isRemoteSkipAvailable(by: -1)
        )
    }

    /// Runs the reader's next (+1) / previous (-1) handler if it can act;
    /// `false` means there was nothing to move to.
    func performRemoteSkip(by offset: Int) -> Bool {
        guard isRemoteSkipAvailable(by: offset), let handler = remoteSkipHandler(for: offset) else {
            Self.remoteLogger.debug("remote skip \(offset): nothing to move to")
            return false
        }
        handler()
        return true
    }

    /// The headset / EarPods centre click: the reader's own play / pause
    /// while it is on screen, otherwise a plain pause / resume.
    func performRemoteTogglePlayPause() {
        Self.remoteLogger.debug("remote toggle play/pause (reader: \(self.onRemoteTogglePlayPause != nil))")
        if let handler = onRemoteTogglePlayPause {
            handler()
        } else {
            togglePlayPause()
        }
    }

    private func remoteSkipHandler(for offset: Int) -> (() -> Void)? {
        offset > 0 ? onRemoteNext : onRemotePrev
    }

    private func isRemoteSkipAvailable(by offset: Int) -> Bool {
        remoteSkipHandler(for: offset) != nil && (canRemoteSkip?(offset) ?? true)
    }
}
