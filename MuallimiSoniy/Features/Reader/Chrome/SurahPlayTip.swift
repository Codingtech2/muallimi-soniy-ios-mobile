import SwiftUI
import TipKit

/// A one-time tip on the surah pages, pointing at ▶: it plays the surah from
/// start to end and stops, while a tap on a single ayah plays just that ayah.
/// The caller passes the words in the reader's language (String Catalog).
/// TipKit keeps it closed for good once ▶ has been used or the tip is closed.
nonisolated struct SurahPlayTip: Tip {
    var titleText = ""
    var messageText = ""

    var title: Text { Text(titleText) }
    var message: Text? { Text(messageText) }
    var image: Image? { Image(systemName: "play.circle.fill") }

    /// ▶ was used on a surah page, so the tip has done its job.
    static func markUsed() {
        SurahPlayTip().invalidate(reason: .actionPerformed)
    }
}
