# Exporting Water Sort to iPhone and iPad

Godot 4.7.2 can export from Windows, but only as far as an **Xcode project**. Building, signing and
installing on a device needs a **Mac with Xcode** and an **Apple Developer account**.

Already set up in this repo:

- `export_presets.cfg` - an "iOS" preset: iPhone + iPad (universal), iOS 13+, portrait-only on iPad
  (`UIRequiresFullScreen`), dark launch screen, `tools/ tests/ docs/` left out of the build.
- `assets/icons/app_icon_1024.png` - 1024x1024 app icon, no transparency (re-render it with
  `godot --path . -s tools/make_icon.gd`).
- Dark boot-splash colour so there is no white flash at launch.

## One-time setup

1. **Export templates (Windows).** In the Godot editor: *Editor > Manage Export Templates >
   Download and Install* (about 1 GB, version 4.7.2.stable). The exporter expects
   `%APPDATA%\Godot\export_templates\4.7.2.stable\ios.zip`.
2. **Apple Developer Program** - US$99/year. Needed for TestFlight and the App Store. (A free Apple ID
   can install on your own device, but the app expires after 7 days.)
3. **Pick your bundle ID**, e.g. `com.yourname.watersort` - it must be unique and can never change
   once the app is on the store.

## Export from Windows

1. Open the project in Godot, then *Project > Export > iOS*.
2. Set **Bundle Identifier** (the preset ships with the placeholder `com.CHANGEME.watersort`) and
   **App Store Team ID** (10 characters, from developer.apple.com > Membership). Godot refuses to export
   with an empty Team ID, so the preset ships with the dummy value `ABCDE12345` - replace it with yours
   (or pick your real team in Xcode, which overrides it).
3. Bump **Version** (`1.0.0`) and **Build** (`1`) for each upload; the build number must increase.
4. Click **Export Project** and save to `build/ios/WaterSort.ipa`. On Windows no `.ipa` is produced
   (that needs macOS); instead `build/ios/` receives `WaterSort.xcodeproj` plus its support files. Copy the
   whole `build/ios/` folder to the Mac.

Or from a terminal: `godot --headless --path . --export-release "iOS" build/ios/WaterSort.ipa`
(a warning "ipa can only be built on macOS" is expected).

Note: the project setting *Rendering > Textures > VRAM Compression > Import ETC2 ASTC* must stay on.
Godot's iOS exporter silently refuses to export without it (the error message is blank).

## Build on the Mac

1. Copy the exported folder to the Mac and open `WaterSort.xcodeproj` in Xcode.
2. Select the project > *Signing & Capabilities* > tick *Automatically manage signing* > choose your Team.
3. Plug in an iPhone/iPad (or pick a simulator), press **Run**.
4. For TestFlight / the App Store: *Product > Archive > Distribute App > App Store Connect*.

## Before submitting to the App Store

- Create the app record in **App Store Connect** with the *same bundle ID*.
- Screenshots are required for the largest iPhone size and for iPad (the app is universal): take them
  on a device or simulator.
- A **privacy policy URL** is required. The game collects no data and has no network access, so the
  App Privacy answers are "Data Not Collected".
- Fill in the age-rating questionnaire (no objectionable content).
- Godot writes a privacy manifest (`PrivacyInfo.xcprivacy`) with default reasons for file timestamps,
  system boot time and disk space, and `NSPrivacyTracking = false`. That is usually enough; if App Store
  Connect rejects the upload with an email naming missing entries, add them in the export dialog's
  **Privacy** section.

## Test on real hardware before shipping

None of this has been run on an iPhone or iPad yet. Check on at least one of each:

- Nothing hides under the notch / Dynamic Island / home indicator (safe-area handling is
  unit-tested but unverified on a real device).
- Buttons are comfortable to tap (the smallest are about 47 pt on an iPhone).
- Animation stays smooth on an older device. The animated background and liquid surfaces redraw
  every frame; if an older phone runs hot, reduce that.
- Bold text renders (the font is looked up by name and falls back to Godot's default if missing;
  bundling a font file would make it identical everywhere).
- Music and effects play, the Settings switches work, and progress survives closing the app.
- On iPad: portrait is locked; if you want landscape support, remove `UIRequiresFullScreen` from the
  preset's *Additional Plist Content* (the layout already adapts to landscape).
