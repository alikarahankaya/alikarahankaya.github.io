import Foundation
import MediaPlayer

/// What was playing.
///
/// Read the limitation before relying on this: `systemMusicPlayer` only sees
/// Apple Music and the local library. Spotify, YouTube Music and every other
/// third-party player are invisible to it, and no API exists that would make
/// them visible. So this returns nothing rather often, and nothing in the
/// interface may assume a track exists.
@MainActor
public enum NowPlaying {
    public static func current() -> String? {
        let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem
        guard let item else { return nil }
        let title = item.title
        let artist = item.artist
        switch (title, artist) {
        case let (title?, artist?): return "\(title) · \(artist)"
        case let (title?, nil): return title
        default: return nil
        }
    }
}
