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
| Build and install on iOS | Flutter SDK + full Xcode + its iOS platform components, on a Mac |

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
- **Location, including background** — only if you use Places. The system must
  be allowed to report crossings while the app is closed, which is "Allow all
  the time" rather than "While using". Nothing derived from it leaves the
  device.
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

> **You need full Xcode.** The Command Line Tools alone are not enough —
> `flutter build ios` will say *"Application not configured for iOS"* and stop.
> Xcode is a ~10 GB download from the App Store.

### One-time setup

1. Install **Xcode** from the App Store.
2. Install the **iOS platform components**. Xcode ships without them, and the
   build fails at the storyboard step with *"iOS 26.5 Platform Not Installed"*.
   Run it as root so the runtime is both installed **and** mounted — installed
   unprivileged it leaves an image that never mounts, and `xcrun simctl list
   runtimes` stays empty:

   ```bash
   sudo xcodebuild -downloadPlatform iOS
   ```

   It is about 8.5 GB. Do **not** also start the same download from Xcode →
   Settings → Components. Two downloads racing leave duplicate images that
   mount as *Unusable*, and deleting those duplicates can take the shared
   asset with them, forcing a full re-download.

3. Point the toolchain at Xcode and finish first launch. Both need your password:

   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

   ```bash
   sudo xcodebuild -runFirstLaunch
   ```

4. Confirm the runtime registered, and that `flutter doctor` is green:

   ```bash
   xcrun simctl list runtimes
   ```

   ```bash
   flutter doctor
   ```

**CocoaPods is not used.** Every iOS plugin here ships as a Swift Package, so
the project is SPM-only: no `Podfile`, no `pod install`. Flutter refuses to mix
the two and warns on every build that the project "uses a non-standard Podfile"
if a `Podfile` is present. If you find one in `ios/`, it was added by mistake.

### Build

```bash
flutter pub get
```

```bash
flutter build ios --release
```

Xcode resolves the Swift Package dependencies on the first build. That takes a
few minutes and is the one step that needs a network; everything after it is
offline.

### Install on your iPhone

Local notifications and geofences both need a signed build on real hardware. A
free Apple ID is enough for your own phone.

1. Open the **workspace**, not the project:

   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select the **Runner** target → **Signing & Capabilities**.
3. Tick **Automatically manage signing** and choose your Team. A free personal
   team works.
4. **Change the Bundle Identifier.** It currently reads `dev.dayline.dayline`,
   which is not yours and will be rejected. Use something like
   `com.yourname.dayline`.
5. Plug the phone in and trust the computer, then:

   ```bash
   flutter devices
   ```

   ```bash
   flutter run --release -d <your-iphone-id>
   ```

6. On the phone: **Settings → General → VPN & Device Management**, and trust
   your developer certificate. The app will not launch until you do.

With a free Apple ID the build **expires after 7 days** and must be
reinstalled. A paid developer account extends that to a year.

### What iOS will ask you for

- **Notifications** — on first launch. Without it no reminder arrives.
- **Location, "Allow While Using"** then **"Change to Always Allow"** — only if
  you use Places. iOS deliberately asks for the upgrade separately, and often a
  day or so later. Until it is granted, arrivals are not recorded and the app
  says so rather than pretending.

Note that Dayline declares **no `UIBackgroundModes`**. Geofences use region
monitoring, which iOS relaunches the app for on its own; the `location`
background mode is for continuous tracking, which this app never does.

### Running in the Simulator

```bash
flutter run -d "iPhone 17"
```

**If the app launches to a blank white screen in the Simulator and nothing ever
happens, check where this repo lives.** A debug simulator build bakes an
absolute rpath into `Runner.debug.dylib` pointing at
`<project>/build/ios/Debug-iphonesimulator/PackageFrameworks`. If the project
sits inside a folder macOS protects with TCC — `~/Documents`, `~/Desktop` or
`~/Downloads` — the simulated app has to read from there while it is still
dynamically linking. That fires a consent request nothing ever answers, and
`dyld` blocks in `open()` forever: no Dart, no logs, no crash, just white.

Two ways out: keep the checkout somewhere unprotected (`~/dev/dayline`), or
grant **Simulator** access to that folder under System Settings → Privacy &
Security → Files and Folders.

This affects debug simulator builds only. Release builds for a real device
resolve frameworks through `@executable_path/Frameworks` and carry no
reference to the build directory at all — confirm with:

```bash
otool -l build/ios/iphoneos/Runner.app/Runner | grep -A2 LC_RPATH
```

### Build an IPA for distribution

```bash
flutter build ipa --release
```

The archive lands in `build/ios/archive/`, ready for Xcode Organizer or
TestFlight. This needs a paid developer account.

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

## What is in it

- **Today** — one line of the day: Overdue, the now line, Next up with a live
  countdown, Later today, and Done folded away. Tap a row to mark it done,
  long-press for skip / move / edit.
- **Add & Edit** — all five recurrence shapes (once, daily, weekly, every N
  days, monthly), lead reminders, colour, notes, end date, and a plain-English
  preview of the rule you have actually built.
- **All events** — every rule with its schedule and streak; swipe to delete,
  toggle to pause.
- **Settings** — notification and exact-alarm status, the battery-optimisation
  help card, background-location status, light/dark/system, and JSON export and
  import.
- **Places & Dashboard** — places you add yourself, and what the time actually
  went on. See below.

## Places and the dashboard

Dayline can notice when you arrive at and leave places **you have added
yourself**, and use that to answer whether you actually kept the routines tied
to them.

**It does this entirely offline.** You add a place by standing in it and
tapping *Use current location*. There is no map, no address search and no
places database, because all three need a network — and the app still declares
no internet permission. That also means Dayline cannot know a set of
coordinates is a Tesco or a Cineworld; it only knows it is the spot you called
"Tesco".

The OS watches a handful of circles and wakes the app when the device crosses
one. There is no continuous location stream, so the battery cost is small.

The dashboard answers four questions:

- **Time per place** — totals over 7, 30 or 90 days, with visits clipped to the
  window rather than counted whole.
- **Did you go?** — for any routine linked to a place, how many of its past
  occurrences you were actually there for, within a two-hour grace window.
- **Today** — a timeline of arrivals and departures, with an open visit shown
  as still running.
- **Week by week** — six weeks per place, Monday to Monday, so a drift in
  either direction is visible.

### What this costs you

Background location is the most heavily scrutinised permission on both stores,
and Android will not grant it without the user choosing "Allow all the time"
explicitly. Dayline says plainly when it does not have it rather than looking
like it is working. Visit history can be wiped from Settings at any time
without losing the places themselves, and it is included in backups.

## Backups

Export writes a single JSON file and hands it to the share sheet. Nothing is
uploaded — the app has no internet permission, so where the file goes next is
entirely your choice.

The format is deliberately plain: dates as `yyyy-MM-dd`, times as minutes since
midnight, no timestamps anywhere in the schedule. A backup taken in Sydney
restores unchanged in Los Angeles, and the file is readable in any text editor.

Importing offers two choices. **Replace everything** is a restore — what is in
the file becomes everything you have. **Add to mine** merges, for pulling
routines off an old phone onto one already in use. Event ids are reassigned on
the way in and history is remapped to follow its own event, so a merge cannot
silently attach one event's history to another.

## How it is put together

```
lib/src/
  model/           Pure Dart. Dates, recurrence, sectioning, streaks. No Flutter.
  db/              Drift schema, DAOs, migrations.
  data/            The JSON backup format and the import/export service.
  notifications/   Scheduling plan (pure) and the OS adapter around it.
  location/        Geofence registration and the background crossing handler.
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

A third, smaller one worth knowing if you touch the code: **live queries go
through `liveQuery()`, not drift's `.watch()`.** A subscription to drift's own
query stream does not finish cancelling under `flutter_test`'s fake clock, so
any widget test that touches one hangs until its ten-minute timeout. The same
applies to writing a stream as an `async*` generator with an `await for` inside
it. Both traps have cost an afternoon already.

