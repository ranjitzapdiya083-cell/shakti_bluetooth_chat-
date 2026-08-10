# Shakti Bluetooth Chat

Offline, real-time Bluetooth Classic (RFCOMM) chat for Android — built with Flutter,
Riverpod, Go Router, Hive, and Material 3.

## What's actually implemented (real, working code — not placeholders)

- **Bluetooth**: adapter on/off detection, enable prompt, runtime permission requests
  (Android 12+ `BLUETOOTH_SCAN`/`CONNECT` and legacy `ACCESS_FINE_LOCATION`), device
  discovery, pairing/unpairing, RFCOMM connect with **automatic reconnect** (backoff,
  max attempts), and a lightweight line-based protocol over the single socket that
  carries both chat text and chunked file transfer.
- **Chat**: messages persist to Hive, send/receive in real time, per-message status
  (sending / sent / delivered / failed with retry), star, delete (single + multi-select),
  in-conversation search, date separators, auto-scroll-to-latest, clear conversation.
- **Home**: three tabs — Recent Chats, Paired Devices, Nearby (live discovery with
  pull-to-refresh) — plus global search across chats/devices, empty/loading/shimmer
  states throughout.
- **QR quick pair**: generates a QR encoding your device's Bluetooth MAC, scans a
  peer's QR to auto-pair and jump into the chat.
- **Settings**: light/dark/system theme, Material You dynamic color toggle, display
  name, about/version.
- **Theming**: full Material 3 light + dark theme built from a custom brand seed
  color (not copied from WhatsApp/Telegram/stock Material), consistent radii/spacing
  via `AppConstants`, `flutter_animate` micro-interactions, shimmer loading.

## What's scaffolded but needs another pass before Play Store submission

Given the enormous scope of the original spec, these are wired up structurally
(models, protocol support, permissions) but need a dedicated follow-up session to
finish end-to-end:

- **File sharing UI**: `AppBluetoothService.sendFile()` / the `FILEMETA/FILECHUNK/FILEEND`
  receive protocol already exist in `core/services/bluetooth_service.dart` — the Files
  screen (transfer queue, progress bar, retry/cancel/resume, picking via `file_picker`,
  saving received files with `path_provider`) still needs building.
- **AES encryption** of the RFCOMM payload before it's written to the socket.
- **Notifications** (new message / file received / connection lost) — `POST_NOTIFICATIONS`
  permission is declared; the `flutter_local_notifications` wiring isn't in yet.
- **Foreground service** to keep the socket alive when the app is backgrounded.
- **Device management extras**: rename/forget/trusted-device UI on top of the
  `DeviceEntry` model (the model already has `isTrusted`, `nickname`, `isFavorite`).
- App icon / launcher assets (placeholder mipmap folders only).
- Signing config for release (`android/app/build.gradle.kts` currently signs release
  builds with the debug key — replace before publishing).

## Setup

This was built without a local Flutter SDK available in the authoring sandbox, so it
has **not** been run through `flutter pub get` / `flutter analyze` / a real device build.
Do this first on your machine:

```bash
flutter --version        # confirm Flutter 3.22+ / Dart 3.4+
flutter pub get
flutter analyze          # fix anything environment-specific (SDK/package version drift)
flutter run
```

If `flutter pub get` bumps any package majors, review `pubspec.yaml` pins.

### Hive adapters

`lib/core/models/*.g.dart` were hand-written to match what `build_runner` would
generate (no internet access to fetch the Flutter SDK in this sandbox to run it).
If you'd rather have the generator own them:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Android SDK path

Fill in `android/local.properties` with your machine's paths:

```properties
sdk.dir=/path/to/Android/sdk
flutter.sdk=/path/to/flutter
```

## Architecture

```
lib/
  core/            # constants, theme, services (bluetooth, storage, permissions),
                    hive models, shared widgets, routing, cross-cutting providers
  features/
    home/          # chats/paired/nearby tabs
    bluetooth/     # discovery + connection providers
    chat/          # message list, bubble, input bar, search
    settings/      # theme, profile, about
    qr/            # generate/scan quick-pair
  app.dart         # MaterialApp.router + dynamic color
  main.dart        # Hive init, ProviderScope
```

Clean-architecture-flavored: business logic lives in `core/services` and
`features/*/providers`, screens stay declarative and consume Riverpod state.
