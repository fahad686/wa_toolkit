# WA Toolkit

**By [mef tech](https://github.com/meftech)**

**Save WhatsApp statuses, recover deleted messages, download media from links, and lock sensitive files in a secure vault — all on your device.**

Android Flutter app with a Material 3 dashboard for four tools: **Status Saver**, **Deleted Messages**, **Media Downloader**, and **Secure Vault**. Supports regular WhatsApp and WhatsApp Business separately. Light, dark, and system themes.

---

## GitHub description (short)

Use this as your repository description:

> Android Flutter app to save WhatsApp & Business statuses, capture deleted chat notifications, download YouTube/media links (360p–4K), and store files in a PIN-protected vault. Private, on-device.

---

## Features

### Dashboard
- Feature cards with live stats (statuses, messages, vault, downloads)
- **Global search** across saved statuses and captured messages
- **Onboarding guide** for first-time setup
- **Theme picker** — System / Light / Dark (persisted)

### Status Saver
- Auto-scans WhatsApp `.Statuses` folder via Storage Access Framework (SAF)
- Separate tabs for **WhatsApp** and **WhatsApp Business**
- 24-hour cache for unsaved statuses (mirrors WhatsApp expiry)
- Video thumbnails, **stories-style swipe viewer**, share, gallery export
- Fast background scan (every 20s) to catch statuses deleted quickly on WhatsApp
- **Filters** — images, videos, favorites, today, last 7 days, collections, contact search
- **Bulk select** — save, move to vault, or delete multiple statuses at once
- **Favorites & collections** — star statuses and tag them into custom groups
- **Auto-save rules** — optionally auto-save new statuses (videos only, optional)
- Save in app, repair missing files

### Deleted Messages
- Captures WhatsApp & Business notifications locally (requires notification access)
- **Search** by sender or message text
- **Filters** — saved only, deleted only, group chats
- **Conversation view** — messages grouped by contact/thread
- **Export** — share captured messages as text
- **Deleted-message alerts** — local notification when a deleted message is detected
- View full message with sender name and timestamp
- Save important messages to a saved list
- Works when messages are removed — based on notification capture, not WhatsApp database access

### Media Downloader
- **Share from any app** (YouTube, Instagram, TikTok, Facebook, browser, etc.) — WA Toolkit appears in the Android share menu
- Paste a link and fetch available download formats
- **YouTube** — video (360p, 480p, 720p, 1080p, 2K, 4K) and audio (multiple bitrates)
- **Instagram** — reels and video posts
- **TikTok** — video posts and shared links
- **Facebook** — reels and videos (HD/SD when available)
- **X (Twitter)** — video tweets (multiple bitrates when available)
- **Snapchat** — spotlight/public links (when exposed in page metadata)
- **Pinterest** — video pins and images
- **Vimeo** — progressive quality options
- **Dailymotion** — multiple quality options
- **Direct file links** — MP4, MP3, images, and other media URLs
- **HLS streams** (`.m3u8`) — quality variants when available
- **Download manager** — active queue, progress, retry, cancel, in-app playback, library tabs
- Files saved to app storage (`downloads/videos`, `downloads/audio`, `downloads/files`)

> **Not supported:** DRM-protected services (Netflix, Spotify, Apple Music, Prime Video, etc.) — these cannot be downloaded by design.

### Secure Vault
- PIN + optional fingerprint unlock
- Move sensitive statuses into hidden, protected storage
- **Vault folders** — organize items into custom folders
- **Decoy PIN** — opens an empty vault if someone enters the wrong PIN
- **Auto-move prompt** — optionally ask to move to vault after saving a status

### Also included
- Material 3 UI with light / dark / system theme
- Usage stats on the home screen
- Settings for folder access, auto-save, vault, and alerts

---

## Screenshots

_Add screenshots here after publishing._

---

## Getting started

### Requirements
- Flutter SDK `>=3.3.0`
- Android device or emulator (Android 7+; notification and share features need a real device)

### Run

```bash
flutter pub get
flutter run
```

### First-time setup

1. **Status Saver** — Grant folder access and select:
   - WhatsApp: `Android/media/com.whatsapp/WhatsApp/Media/.Statuses`
   - Business: `Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses`
2. Open WhatsApp and **view statuses** first, then pull to refresh in the app.
3. **Deleted Messages** — Enable notification listener access for this app in Android settings.
4. **Vault** — Set a PIN on first use.
5. **Media Downloader** — Share a link from YouTube or any app, or paste a URL in the downloader screen.

---

## Permissions

| Permission | Why |
|------------|-----|
| Storage Access Framework | Read WhatsApp status media folder |
| Notification listener | Capture incoming WhatsApp message notifications |
| Post notifications | Alert when a deleted message is captured |
| Biometric | Optional vault unlock |
| Internet | Media downloader (YouTube, direct links, HLS) |

No personal data is sent to external servers. Statuses, messages, and downloads stay on your device. YouTube resolution uses the public stream manifest on-device via `youtube_explode_dart`.

---

## Project structure

```
lib/
├── main.dart
├── app/                         # Bootstrap, theme, app root, share-intent routing
├── features/
│   ├── dashboard/               # Home screen, global search, onboarding
│   ├── deleted_messages/        # Notification capture, search, conversations
│   ├── media_downloader/        # Link resolvers, download manager, variant picker
│   ├── status_saver/            # Status saver shell
│   └── vault/                   # Vault shell
├── models/                      # Hive models (StatusItem, etc.)
├── services/                    # Scanner, cache, gallery, share, vault, preferences
├── screens/                     # Status tabs, viewer, settings
└── widgets/                     # Tiles, grids, action buttons
```

---

## Regenerate Hive adapters

After changing `StatusItem`, `CapturedMessage`, or `DownloadTask` fields:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Platform notes

- **Android only** for status sync, notification capture, and share-intent downloads. iOS cannot read WhatsApp files or listen to other apps' notifications in the same way.
- Uses SAF on Android 11+ — no broad `MANAGE_EXTERNAL_STORAGE` permission.
- **Deleted messages** depend on notifications being shown by WhatsApp. Messages received while the app has no permission, or with notifications disabled, cannot be recovered.
- **Media Downloader** supports YouTube, Instagram, TikTok, Facebook, X/Twitter, Snapchat, Pinterest, Vimeo, Dailymotion, direct media URLs, and HLS. Only download content you have the right to save. DRM services (Netflix, Spotify, etc.) are not supported.
- Core library desugaring is enabled in `android/app/build.gradle.kts` (required by `flutter_local_notifications`).

---

## Tech stack

Flutter · Hive · SAF (`saf_util` / `saf_stream`) · `youtube_explode_dart` · Dio · `video_thumbnail` · `notification_listener_service` · `flutter_local_notifications` · `local_auth` · `gal` · Material 3

---

## Disclaimer

This app is not affiliated with WhatsApp, YouTube, or Meta. Use it responsibly and only for content you have the right to save. Respect others' privacy and local laws.
