# Muallimi Soniy — iOS

Ahmad Hodiy Maqsudiyning "Muallimi Soniy" (1892) arab alifbosi darsligining native iOS ilovasi. Har element (harf/bo'g'in/so'z/oyat) bosilganda to'g'ri mahrajdan o'qilgan audio ijro etiladi. Kontent web (PWA) versiyasi bilan **1:1** — yagona manba.

## Texnologiyalar

| Qatlam | Ishlatilgan |
|--------|-------------|
| Til | Swift 5 (language mode), Swift 6 toolchain |
| UI | SwiftUI, **iOS 17.0+** (iPhone + iPad) |
| State | Observation framework (`@Observable`), `@MainActor` default isolation |
| Audio | AVFoundation (`AVAudioPlayer`), MediaPlayer (Now Playing / remote command), `AVAudioSession` (background playback) |
| Crypto | CryptoKit (`SHA256` — yuklangan audio yaxlitligini tekshirish) |
| Shrift | CoreText (`CTFontManager`) — custom Noto Naskh Arabic Muallimi + Amiri Quran (mad uchun) |
| Arxiv | O'z ichida yozilgan minimal STORED-ZIP extractor (uchinchi tomon kutubxonasi yo'q) |
| Bog'liqliklar | **Hech qanday** — SPM/CocoaPods/Carthage ishlatilmaydi |
| Xcode | 16+ (`objectVersion 77`, file-system synchronized groups) |

## Arxitektura

- **Kontent**: `book.json` (52 sahifa, 1885 element, 4 til), `i18n/legal/settings.json`, shriftlar, `audio-manifest.json` — ilovaga **bundle** qilingan (~2 MB). `ContentStore` (`@Observable`) yuklaydi va 52 sahifani global ketma-ketlikka tekislaydi.
- **Render**: `PageDispatcher` kitob sahifa raqamini 51 ta **bespoke** SwiftUI view'dan biriga (`Page0View`…`Page50View`) yo'naltiradi. Har view umumiy primitivlardan (`ArabicElementView`, `WordRow`, `Verse`, `SurahTitle`, `SectionTitle/Divider`) tuziladi. Reader = `HorizontalBookPager` (52 sahifa gorizontal paging).
- **Audio**: har element o'z mp3 chunk'i bilan. `AudioEngine` (`AVAudioPlayer` + segment/repeat/loop), `AudioController` (`@Observable`). Element bosilsa — chunk ijro etiladi.
- **Offline**: audio (127 MB, 1757 fayl) bundle'ga KIRMAYDI — birinchi ochilishda GitHub Release'dan (`content-2.0.0` → `audio.zip`, STORED) yuklab olinadi, `Application Support/media/` ga ochiladi, har fayl **sha256** bilan tekshiriladi (`AudioDownloadManager`). Shundan keyin ilova internetsiz to'liq ishlaydi.

## Kontent tarqatish

- **Bundle** (kichik, ilova bilan): `book.json`, i18n, shriftlar, `audio-manifest.json`.
- **GitHub Release** (`content-2.0.0`): `audio.zip` (127 MB, 1757 mp3). Manba: `https://github.com/Codingtech2/muallimi-soniy-ios-mobile/releases`.
- Web va iOS bir xil kontent paketidan oziqlanadi (`contentVersion` bilan solishtiriladi).

## Build va ishga tushirish

```
Xcode 16+ da MuallimiSoniy.xcodeproj ni oching
Scheme: MuallimiSoniy   Target: iOS 17+ (simulyator yoki qurilma)
Dependency o'rnatish SHART EMAS — hech qanday tashqi paket yo'q.
```

Bundle ID: `uz.vipads.MuallimiSoniy`. Qurilmada background audio uchun "Background Modes → Audio" yoqilgan.

## Loyiha strukturasi (`MuallimiSoniy/`)

```
App/            RootTabView
Models/         Codable domen modellari (Chapter, Lesson, Page, Element, LocalizedString)
Data/           ContentStore (@Observable)
DesignSystem/   Theme (ranglar, light default), Fonts (CTFontManager registratsiya)
Components/     Umumiy UI primitivlar (ArabicElementView, WordRow, Verse, ...)
Features/       Home, Contents, Settings, Reader/
                  Reader/Pages/  — 51 ta bespoke sahifa view + shared komponentlar
Audio/          AudioEngine, AudioController, MediaLocator, NowPlayingController, AudioSession
Offline/        AudioDownloadManager, ZipStore (STORED-zip), AudioManifest
Resources/      book.json, i18n/legal/settings.json, audio-manifest.json, Fonts/
```

## Bog'liq loyiha

Kontentning yagona manbai — web (PWA) versiyasi: [muallimisoniy.uz](https://muallimisoniy.uz). Sahifa layout'lari o'sha repodagi `RenderedPage.tsx` dan 1:1 ko'chirilgan.

## Litsenziya

Ochiq kodli. (Litsenziya fayli qo'shiladi.)
