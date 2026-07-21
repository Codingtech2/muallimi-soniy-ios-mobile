import Foundation
import MediaPlayer

/// Bridges playback to the system Now Playing UI (lock screen / Control Center)
/// and the remote command centre — the native counterpart of the web
/// `mediaSession.ts`.
///
/// The reader assigns the four command closures (`onPlay` / `onPause` /
/// `onNext` / `onPrev`) and calls `update(...)` whenever the active element or
/// play state changes, then `clear()` on stop.
@MainActor
final class NowPlayingController {

    // MARK: - Remote-command closures (assigned by the reader)

    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrev: (() -> Void)?

    private var isConfigured = false

    init() {
        configureCommands()
    }

    // MARK: - Remote commands

    /// Wires the play / pause / next / previous remote commands once. Handlers
    /// run on the main thread (where remote command events are delivered), so
    /// `MainActor.assumeIsolated` safely reaches the main-actor closures.
    private func configureCommands() {
        guard !isConfigured else { return }
        isConfigured = true
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ -> MPRemoteCommandHandlerStatus in
            MainActor.assumeIsolated {
                guard let handler = self?.onPlay else { return .noSuchContent }
                handler()
                return .success
            }
        }
        center.pauseCommand.addTarget { [weak self] _ -> MPRemoteCommandHandlerStatus in
            MainActor.assumeIsolated {
                guard let handler = self?.onPause else { return .noSuchContent }
                handler()
                return .success
            }
        }
        center.nextTrackCommand.addTarget { [weak self] _ -> MPRemoteCommandHandlerStatus in
            MainActor.assumeIsolated {
                guard let handler = self?.onNext else { return .noSuchContent }
                handler()
                return .success
            }
        }
        center.previousTrackCommand.addTarget { [weak self] _ -> MPRemoteCommandHandlerStatus in
            MainActor.assumeIsolated {
                guard let handler = self?.onPrev else { return .noSuchContent }
                handler()
                return .success
            }
        }
    }

    // MARK: - Metadata

    /// Updates the Now Playing info centre. Per the web media session:
    /// `title` = element arabic, `artist` = element uzbek, `album` = lesson title.
    func update(
        title: String,
        artist: String,
        album: String,
        duration: Double = 0,
        elapsed: Double = 0,
        rate: Double = 1
    ) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyAlbumTitle] = album
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Convenience overload filling `title` / `artist` straight from an element.
    func update(
        element: Element,
        album: String,
        duration: Double = 0,
        elapsed: Double = 0,
        rate: Double = 1
    ) {
        update(
            title: element.arabic,
            artist: element.uzbek,
            album: album,
            duration: duration,
            elapsed: elapsed,
            rate: rate
        )
    }

    /// Updates just the playback rate on the existing Now Playing info so the
    /// lock-screen play/pause state follows real playback, without rebuilding the
    /// metadata. No-op when no metadata is currently set (so it never spawns an
    /// empty, title-less Now Playing entry).
    func setPlaybackRate(_ rate: Double) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clears the Now Playing info (on stop or when leaving the reader).
    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
