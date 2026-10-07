# mcro

An Android app for creating **micro-apps** — tiny programs built from
plain **HTML, CSS, and JavaScript**. Write code in a three-tab editor,
preview it live in a WebView, and keep everything on-device.

Built with Flutter (the app shell) + `webview_flutter` (running the
micro-apps).

## Features (MVP)

- **Gallery** — list of saved micro-apps with last-edited time,
  duplicate/delete actions, and an empty state.
- **Editor** — separate HTML / CSS / JS tabs with a monospace code
  field, rename, save (with unsaved-changes protection on back).
- **Run** — full-screen WebView preview with floating close/reload
  controls; the CSS and JS are injected into the markup automatically,
  so fragments *and* full documents work.
- **Device APIs** — micro-apps can use geolocation and SMS through a
  small JavaScript bridge (`mcro.geolocation`, `mcro.sms`, and a
  standard `navigator.geolocation` implementation).
- **Storage** — each micro-app is a JSON file
  (`<app-documents>/micro_apps/<id>.json`), no account, no network.

## Project layout

```
lib/
  main.dart                      App entry, dark Material theme
  models/micro_app.dart          MicroApp model + starter template
  services/storage_service.dart  JSON-per-app persistence
  services/preview_builder.dart  HTML+CSS+JS -> runnable document
  services/bridge_js.dart        Bridge JS injected into micro-apps
  services/micro_app_bridge.dart JS <-> Dart dispatcher
  services/platform_services.dart MethodChannel wrapper (permissions/location/SMS)
  screens/gallery_screen.dart    Home: list / create / delete
  screens/editor_screen.dart     HTML/CSS/JS tab editor
  screens/preview_screen.dart    Full-screen WebView runner
test/                            Unit + widget tests
android/                         Android host project (incl. MainActivity.kt
                                 native channels for location/SMS)
.github/workflows/ci.yml         CI: analyze, test, build APK
```

## Building

The CI pipeline is the source of truth (`.github/workflows/ci.yml`):

1. `flutter create --platforms=android --project-name mcro --org dev.mcro .`
   — generates platform files that are not committed
   (`gradle-wrapper.jar`, launcher icons).
2. `flutter pub get`
3. `flutter analyze --no-fatal-infos`
4. `flutter test`
5. `flutter build apk` → `build/app/outputs/flutter-apk/app-release.apk`

To build locally, install a stable Flutter SDK and run the same steps
(step 1 is only needed once, or after cleaning `android/`).

Release builds are signed with the debug key so CI needs no secrets —
swap in a real signing config before publishing to an app store.

## Micro-app APIs

Every micro-app gets a `mcro` object on `window` plus a standard
`navigator.geolocation`. Both use promises / callbacks and are backed by
native Android APIs (no extra packages).

### Geolocation

```js
// Promise style
const pos = await mcro.geolocation.getCurrentPosition({ timeout: 10000 });
console.log(pos.coords.latitude, pos.coords.longitude, pos.coords.accuracy);

// Standard web style (works with typical geolocation code)
navigator.geolocation.getCurrentPosition(
  (position) => console.log(position.coords.latitude),
  (error) => console.log(error.code), // 1 denied, 2 unavailable, 3 timeout
  { timeout: 10000 }
);

// One-shot polling watch is supported too
const id = navigator.geolocation.watchPosition(success, error);
navigator.geolocation.clearWatch(id);
```

Android location permission is requested the first time it is used; the
position falls back to the most recent fix when a fresh one can't be
obtained within the timeout.

### SMS

```js
await mcro.sms.send('+15551234567', 'Hello from my micro-app!');
// or
await mcro.sms.send({ to: '+15551234567', body: 'Hello!' });
```

Sends the message through the default SMS app subsystem
(`TelephonyManager.SmsManager`). The `SEND_SMS` permission is requested
on first use.

### Errors

Rejected promises carry `{ code, message }`:

| code | meaning |
| --- | --- |
| `PERMISSION_DENIED` | user denied the required permission |
| `POSITION_UNAVAILABLE` | no location provider available |
| `TIMEOUT` | no fix within the timeout |
| `INVALID_ARGUMENT` | bad parameters (e.g. missing SMS recipient) |
| `SEND_FAILED` | the platform could not send the SMS |
| `UNKNOWN_METHOD` / `INTERNAL` | internal bridge error |

> ⚠️ `SEND_SMS` and location are sensitive permissions. If you ever
> publish to an app store, declare them in the Play Console and review
> the policy on SMS permissions (some store policies require using the
> system SMS app instead of sending silently).

## Notes

- `webview_flutter` is pinned to `4.10.0` for reproducible CI builds
  (newer releases require a more recent Flutter than the code needs).
- Micro-apps run sandboxed in a WebView with JavaScript enabled; there
  is no network access needed for the default templates.
