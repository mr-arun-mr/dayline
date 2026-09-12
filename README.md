# Dayline

One line of today's events, in order, with reminders before each one.
No account, no server, no network permission.

Everything lives on the device in SQLite. The app works fully in airplane
mode, and there is nothing to sign into.

---

## What you need before you can build

Dayline is a Flutter app targeting iOS and Android. The Dart side builds and
tests on any machine with Flutter; shipping to a phone needs the usual platform
toolchains.

| To do this | You need |
| --- | --- |
| Run the tests, analyze, generate code | Flutter SDK only |
| Build and install on Android | Flutter SDK + Android SDK (via Android Studio) |
| Build and install on iOS | Flutter SDK + full Xcode + CocoaPods, on a Mac |

Check what you have:

```bash
flutter doctor
```

Anything marked ✗ under *Android toolchain* or *Xcode* has to be fixed before
that platform will build. The rest of this file assumes `flutter doctor` is
happy for the platform you care about.

### Flutter

```bash
brew install --cask flutter
```

Built and tested against **Flutter 3.47.3 (stable)**.

### First-time project setup

```bash
flutter pub get
dart run build_runner build
```

The second command generates the Drift database code (`*.g.dart`). It is not
checked in as a build artifact you can skip — the project will not compile
without it. Re-run it after changing anything in `lib/src/db/tables.dart`.

---

## Android

### One-time setup

1. Install [Android Studio](https://developer.android.com/studio).
2. Open it once and let it install the SDK, platform tools and a system image.
3. Accept the licences:

   ```bash
   flutter doctor --android-licenses
   ```

If the SDK is somewhere unusual, point Flutter at it:

```bash
flutter config --android-sdk /path/to/Android/sdk
```

### Run on a device or emulator

Enable **Developer options → USB debugging** on the phone and plug it in, or
start an emulator from Android Studio's Device Manager. Then:

```bash
flutter devices
```

```bash
flutter run -d <device-id>
```

Debug builds seed a sample day (gym, dance class, plants, rent, dentist) so
there is something to look at immediately. Release builds start empty.

### Build an installable APK

```bash
flutter build apk --release
```

The output lands at `build/app/outputs/flutter-apk/app-release.apk`. Install it
on a connected phone with:

```bash
flutter install --release
```

Or sideload it directly:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

A release APK built this way is signed with a debug key — fine for your own
phone, not for distribution. For the Play Store build an App Bundle instead and
sign it with your own upload key:

```bash
flutter build appbundle --release
```

### Permissions Android will ask for

- **Notifications** — asked at runtime on Android 13+. Without it nothing is
  delivered.
- **Exact alarms** — Android 12+ treats these separately. Without them a 07:00
  reminder can arrive at 07:20, which for a medication reminder is a different
  product.

The app declares **no internet permission at all**, which you can verify:

```bash
grep -i internet android/app/src/main/AndroidManifest.xml
```

### If reminders stop arriving

Xiaomi, Oppo, Huawei, Vivo and Samsung ship aggressive battery managers that
silently kill background alarms. The app shows a one-time card explaining this.
The fix is **Settings → Apps → Dayline → Battery → Unrestricted**, and the
exact path differs per manufacturer.

---

## iOS

### One-time setup

1. Install **Xcode** from the App Store. The command line tools alone are not
   enough — `flutter doctor` will say so.
2. Point the toolchain at it and finish first launch:

   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

   ```bash
   sudo xcodebuild -runFirstLaunch
   ```

3. Install CocoaPods:

   ```bash
   brew install cocoapods
   ```

4. Fetch the iOS pods:

   ```bash
   cd ios && pod install && cd ..
   ```

### Run on the simulator

```bash
open -a Simulator
```

```bash
flutter run -d iphone
```

Note that **scheduled local notifications do fire in the simulator**, but
background delivery behaviour is not identical to a real device. Test anything
timing-sensitive on hardware.

### Run on a physical iPhone

Local notifications on a real device need a signed build, which needs an Apple
ID (a free one is enough for personal installs).

1. Open the iOS project in Xcode:

   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select the **Runner** target → **Signing & Capabilities**.
3. Tick **Automatically manage signing** and pick your Team. A free personal
   team is fine.
4. Change the **Bundle Identifier** to something unique to you, for example
   `com.yourname.dayline` — the default will already be taken.
5. Plug the phone in, trust the computer, and:

   ```bash
   flutter run --release -d <your-iphone>
   ```

6. On the phone, go to **Settings → General → VPN & Device Management** and
   trust your developer certificate. The app will not launch until you do.

With a free Apple ID the build expires after **7 days** and must be reinstalled.
A paid developer account extends that to a year.

### Build an IPA

```bash
flutter build ipa --release
```

The archive lands in `build/ios/archive/`, ready for Xcode Organizer or
`xcrun altool`. This needs a paid developer account.

---

## Development

Run everything:

```bash
flutter test
```

Static analysis:

```bash
flutter analyze
```

Regenerate database code after a schema change:

```bash
dart run build_runner build
```

### Looking at the UI without a simulator

`test/screenshots_test.dart` renders the real widget tree at phone size and
writes PNGs to `test/screenshots/`, in light and dark. It runs as part of the
normal suite and doubles as a smoke test — any screen that throws while
building fails it. To skip it:

```bash
flutter test --exclude-tags screenshots
```

---

## How it is put together

```
lib/src/
  model/           Pure Dart. Dates, recurrence rules, expansion. No Flutter.
  db/              Drift schema, DAOs, migrations.
  notifications/   Scheduling plan (pure) and the OS adapter around it.
  ui/              Screens and widgets.
```

Two decisions shape everything else:

**Dates are integers, not `DateTime`.** Recurrence arithmetic happens on
`CalendarDate`, a timezone-free year/month/day backed by epoch-day maths, and
dates are stored as epoch-day integers rather than timestamps. A wall-clock
time only becomes an instant at the edge, when a notification is scheduled or a
clock is drawn. This is what keeps a 07:00 alarm at 07:00 across a DST change.

**Occurrences are never stored.** The database holds recurrence *rules*; the
days they produce are expanded on read for whichever date is being shown. A
daily event running for a decade is one row.

