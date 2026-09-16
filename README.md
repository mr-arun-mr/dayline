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

1. Open the project in Xcode. With no CocoaPods in play the workspace and the
   project are equivalent; either opens fine.

   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select the **Runner** target → **Signing & Capabilities**.
3. Tick **Automatically manage signing** and choose your Team. A free personal
   team works.
4. **Check the Bundle Identifier.** The project is committed signed for one
   personal team (`7S42Z6KVAG`) as `com.arunmr.dayline`. If that is not your
   team, choose yours and change the identifier to something like
   `com.yourname.dayline` — a free team cannot sign an identifier another team
   has already registered. (Android keeps `dev.dayline.dayline`; the two
   platforms do not need to match.)
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

- **Today** — the day as one line, threaded top to bottom: everything keeps
  its place in time, with the now line between what has happened and what has
  not and Next up carrying a live countdown. A finished event stays where it
  was done rather than being swept into a pile at the bottom, and the places
  the phone recorded you at sit between the events either side of them. Tap a
  row to mark it done, long-press for skip / move / edit.
- **Add & Edit** — all five recurrence shapes (once, daily, weekly, every N
  days, monthly), lead reminders, colour, notes, end date, an optional place
  with *mark done on arrival*, and a plain-English preview of the rule you have
  actually built.
- **All events** — every rule with its schedule and streak; swipe to delete,
  toggle to pause.
- **Holidays** — days when work or school steps aside, and only what you have
  put on those timetables goes with them. See below.
- **Settings** — notification and exact-alarm status, the battery-optimisation
  help card, background-location status, holidays, light/dark/system, and JSON
  export and import.
- **Places & Dashboard** — places you add yourself, and what the time actually
  went on. Events tied to a place show planned against actual, mark themselves
  done on arrival, and can file the visits you never planned. See below.

## Holidays

Record a bank holiday, a week off or half-term under **Settings → Holidays**,
and the days it covers stop happening — for the things you said belong to that
timetable, and nothing else.

A holiday closes a **timetable**, not a day. Each one says what is shut — Work,
School, or both — and each event says which timetable it is on, under *Pauses
on* in the editor. The default is **Nothing**, and it will stay that way for
almost everything:

> Medication is still medication on Christmas Day. An app that quietly
> cancelled it because the office was shut would be dangerous rather than
> clever.

So the school run is tagged *School holidays*, the standup *Work holidays*, and
the gym, the plants and the pills are tagged nothing at all. Half-term then
clears the school run and leaves your working day alone, which a single
is-it-a-holiday flag could not do.

Holidays are ranges, because a week off is the common case and ticking seven
days one at a time is not a feature. Two can overlap — a bank holiday inside a
fortnight of leave — and a day covered twice is closed exactly once.

**It reaches the alarm clock, not just the screen.** This is the half that is
invisible until it goes wrong: a daily rule is normally one native repeating
trigger that fires forever, and the OS knows nothing about any of this. A
holiday inside the scheduling window drops that repeat and schedules the
window day by day instead, leaving the closed days out. Hiding the school run
from the day while the phone still sounded at 07:00 on Christmas morning would
be worse than not having the feature at all.

The day itself says so rather than just going quiet — a missing school run with
nothing on screen to explain it is indistinguishable from a bug:

```
┌──────────────────────────────────────┐
│ 🏖  Half-term                         │
│    School events are paused          │
└──────────────────────────────────────┘
```

Nothing is deleted. The rules are untouched, history already recorded against a
day that later became a holiday stays exactly as it was, and removing the
holiday brings the day straight back.

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

### Marking things done by turning up

Tie a routine to a place and the editor offers **Mark done on arrival**. With
it on, walking into that place around the time the thing is due ticks it off
by itself — no notification to catch, no app to open. The row then says *Done
on arrival* rather than sitting there looking as though you pressed something
you do not remember pressing.

The rules it follows, in full:

- **Only around the right time.** Two hours either side of the scheduled time,
  which is the same grace *Did you go?* judges by. Walking into the gym at
  lunchtime does not complete the 07:00 class.
- **Only what you asked for.** It is off by default, per event, and there is
  nothing to enable globally.
- **Never over your own decision.** A day you marked done, or consciously
  skipped, is left exactly as it is. The app may tick off a day you have not
  touched; it may never touch a day you have.
- **Never the last word.** An automatic tick is undone by tapping it, like any
  other.

A moved occurrence is matched against the time it was moved to, and a skipped
day is not a candidate at all. Arrivals are noticed while the app is closed,
so this needs background location — without it the switch says so rather than
quietly doing nothing.

### Planned, and what actually happened

Any event tied to a place shows both. The left-hand column keeps the time it
was **planned** for, because that column is what makes the day scannable, and
the line underneath says when you were **actually** there:

```
07:00  Gym
       07:04 → 08:12
```

An open stay reads `07:04 → still there`. Long-press for the two side by side,
with how long each was meant to take and how long it really did.

When no stay matches, the row says nothing at all rather than "missed". No
arrival recorded means one of two things — you did not go, or the phone was
never watching — and the row cannot tell them apart. Guessing would be the app
inventing a fact about your day.

### One place at a time

Both platforms drop exits, and the one they drop is usually the exit for the
place you just left — the crossing they are busy reporting is the arrival
somewhere else. So an arrival is also treated as news about everywhere else:
turning up at the office ends whatever stay was still open at home, at the
time you turned up.

Without that, the morning at home never ends. The day at the office is
recorded *inside* it, coming home again finds that stay still open and is
folded into it, the totals count the same hours twice, and a day that went
home → office → home is left as a single entry saying "home". When the real
exit does arrive late, it is more accurate than the arrival that had to stand
in for it, and it replaces it.

Crossings the OS reports together are exempt from each other, so two
overlapping circles — a gym inside the office campus — do not close one
another.

### Visits you never planned

A place can also put its own stays onto the day, under **Add visits to my day**
in the place editor. Walk into the office on a Saturday and the day gets an
*Office* entry at the time you arrived, already ticked, with its length filled
in when you leave.

Off by default and per place — it is the one setting that writes rows you did
not ask for, which is worth having for the gym and quietly wrong for home. It
also writes nothing when the day already accounts for being there: a routine
tied to that place within the usual two hours *is* that record, and a second
row saying the same thing is the noise this is meant to remove.

These entries are the day's record, not rules, so they stay out of All events,
out of the dashboard's adherence, and out of the progress ring — "2 of 3 done"
stays a count of what you meant to do. They go when the visit history does.

On the day itself they are drawn as part of its line, pinned to the thread
twice — once where you arrived and once where you left — so the day reads as a
journey rather than as a stack of unrelated rows:

```
07:00  ●  Gym                                          done
07:04  ●  Gym                                        1h 8m
08:12  ○  Visited
  ──  08:42  ────────────────────────────────────────────
09:00  ○  Standup
```

**Hide done** folds away events that have been ticked or skipped, and only
those. A stay is never hidden: it is not a task that was tidied up, it already
happened, and it is the one part of the day the app knows for certain.
Edit one and it becomes yours: an ordinary event that stops being tidied away
with the history.

### What the dashboard answers

The dashboard answers four questions:

- **Time per place** — totals over 7, 30 or 90 days, with visits clipped to the
  window rather than counted whole.
- **Did you go?** — for any routine linked to a place, how many of its past
  occurrences you were actually there for, within a two-hour grace window.
- **Today** — one line per stay, in the order they happened, each spelling out
  when you arrived and when you left:

  ```
  ● Brindley Point                 1h 30m
  │ Arrived 07:00 · left 08:30
  ○
  ● Office                         8h 30m
  │ Arrived 09:00 · left 17:30
  ○
  ● Brindley Point             now · 2h
    Arrived 18:00 · still there
  ```

  A stay, not a place: going out and coming back is two entries at that place,
  not one merged into the other. A stay that ran over from the night before
  says which day it began, and one you are still on says so instead of
  inventing an end.
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

A completion the app made on arrival is exported as such, so a restore does not
quietly turn it into something you ticked by hand, and an event written from a
visit is restored still pointing at that same stay rather than at whatever now
holds its old id. Older backups still import; they simply have none of this in
them.

Holidays travel with everything else, and an event's timetable with it. A
timetable this build does not recognise is dropped rather than guessed at: the
event restores and simply never pauses, which is the safe direction to fail in.

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

