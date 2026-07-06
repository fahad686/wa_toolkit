# WA Toolkit

**By [mef tech](https://github.com/meftech)**

**Save WhatsApp statuses, capture messages from notifications, and lock sensitive media in a secure vault — all on your device.**

Android Flutter app with a simple dashboard for three tools: **Status Saver**, **Deleted Messages**, and **Secure Vault**. Supports regular WhatsApp and WhatsApp Business separately. Light, dark, and system themes.

---

## GitHub description (short)

Use this as your repository description:

> Android Flutter app to save WhatsApp & Business statuses (24h cache), capture chat notifications before they disappear, and store media in a PIN-protected vault. Private, on-device only.

---

## Features

### Status Saver
- Auto-scans WhatsApp `.Statuses` folder via Storage Access Framework (SAF)
- Separate tabs for **WhatsApp** and **WhatsApp Business**
- 24-hour cache for unsaved statuses (mirrors WhatsApp expiry)
- Video thumbnails, full-screen viewer, share, gallery export
- Fast background scan (every 20s) to catch statuses deleted quickly on WhatsApp
- Save in app, repair missing files, filter by images/videos

### Deleted Messages
- Captures WhatsApp & Business notifications locally (requires notification access)
- View full message with sender name and timestamp
- Save important messages to a saved list
- Works when messages are removed — based on notification capture, not WhatsApp database access

### Secure Vault
- PIN + optional fingerprint unlock
- Move sensitive statuses into hidden, protected storage

### Also included
- Generic media downloader (connect your own licensed API)
- Material 3 UI with light / dark / system theme

---

## Screenshots

_Add screenshots here after publishing._

---

## Getting started

### Requirements
- Flutter SDK `>=3.3.0`
- Android device or emulator (Android 7+; notification features need a real device)

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

---

## Permissions

| Permission | Why |
|------------|-----|
| Storage Access Framework | Read WhatsApp status media folder |
| Notification listener | Capture incoming WhatsApp message notifications |
| Biometric | Optional vault unlock |
| Internet | Downloader tab only |

No data is sent to external servers. Media and messages stay on your device.

---

## Project structure

```
lib/
├── main.dart
├── app/                    # Bootstrap, theme, app root
├── features/
│   ├── dashboard/          # Home screen
│   ├── deleted_messages/   # Notification capture + message store
│   ├── status_saver/       # Status saver shell
│   └── vault/              # Vault shell
├── models/                 # Hive models (StatusItem, etc.)
├── services/               # Scanner, cache, gallery, share, vault, thumbnails
├── screens/                # Status tabs, viewer, settings
└── widgets/                # Tiles, grids, action buttons
```

---

## Regenerate Hive adapters

After changing `StatusItem` or `CapturedMessage` fields:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Platform notes

- **Android only** for status sync and notification capture. iOS cannot read WhatsApp files or listen to other apps' notifications in the same way.
- Uses SAF on Android 11+ — no broad `MANAGE_EXTERNAL_STORAGE` permission.
- **Deleted messages** depend on notifications being shown by WhatsApp. Messages received while the app has no permission, or with notifications disabled, cannot be recovered.
- Point `DownloaderService.resolveVariants()` at your own API for licensed direct download URLs.

---

## Tech stack

Flutter · Hive · SAF (`saf_util` / `saf_stream`) · `video_thumbnail` · `notification_listener_service` · `local_auth` · Material 3

---

## Disclaimer

This app is not affiliated with WhatsApp or Meta. Use it responsibly and only for content you have the right to save. Respect others' privacy and local laws.
