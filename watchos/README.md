# BGM Watch (watchOS)

This is the watchOS port of the one-clip test. Press the button and a short clip plays out loud from the Apple Watch's built-in speaker. Press it again to stop.

> **Status: not compiled.** This code was written on Windows without Xcode. It has never been built or run, so expect to fix small compile issues on the first build.

## What it does

The app has one screen. It shows the clip title "Dude - emotional", the playback state (STOPPED, PLAYING or ERROR) and the elapsed seconds. A large play/stop button always restarts the clip from the start. Any playback error is shown as red text.

- **Speaker:** the audio session uses category `.playback` with the **default** route-sharing policy. It deliberately does not use `.longFormAudio`. With `.longFormAudio`, watchOS needs a Bluetooth route and shows the headphone route picker. ([Playing Background Audio](https://developer.apple.com/documentation/watchkit/playing-background-audio); [Apple engineer reply](https://developer.apple.com/forums/thread/764292).)
- **Volume:** apps cannot set the system volume on watchOS. The screen includes the system volume control (`WKInterfaceVolumeControl`, origin `.local`). Turn the Digital Crown while the clip plays to change the volume. The player's own gain is fixed at 1.0.
- **No background audio:** the clip may stop if you lower your wrist or leave the app. Background audio on watchOS needs `.longFormAudio`, and that forces a Bluetooth route.

## Requirements

- A Mac with Xcode 14 or later. Single-target watch apps need Xcode 14 or later.
- An Apple Watch with a working speaker, paired to an iPhone. For a clean speaker test, disconnect any Bluetooth headphones.
- The deployment target is **watchOS 7.0**. That is the minimum for a single-target app (`WKApplication`). Recent Xcode versions may warn that 7.0 is below the range they support. If they do, raise the deployment target in `project.yml` (both places) or in the target settings.
- The watch must not be charging. Apple's user guide says media playback through the speaker is not supported while the watch charges, or on Apple Watch Series 9. That note covers the system's media-to-speaker feature. Whether it also blocks short clips from apps is untested.

## Put your own clip here

The clip is copyrighted, so it is git-ignored and not included in the repository.

1. Put your own audio file at `BGMWatch/Resources/dude_emotional.m4a`.
2. To use a different name or format, edit `resourceName` and `resourceExtension` in `BGMWatch/ClipPlayer.swift`. To change the on-screen title, edit `clipTitle` in the same file.

Use AAC in an `.m4a` file. The file used during development was made from an 18 s WAV like this:

```sh
ffmpeg -i input.wav -ac 1 \
  -af "aresample=192000,volume=-0.5dB,alimiter=limit=0.6:level=disabled:attack=1:release=50,aresample=44100" \
  -c:a aac -b:a 160k -movflags +faststart BGMWatch/Resources/dude_emotional.m4a
```

Measured result: mono, 44.1 kHz, about -13.6 LUFS integrated, -1.6 dBTP true peak. Tune `volume` for other clips. A generic alternative is `-af loudnorm=I=-14:TP=-1.5`.

## Option A: XcodeGen (recommended)

1. Install XcodeGen and generate the project:

   ```sh
   cd watchos
   brew install xcodegen && xcodegen generate
   ```

2. Open the generated project:

   ```sh
   open BGMWatch.xcodeproj
   ```

3. Select the `BGMWatch` target. Under **Signing & Capabilities**, choose your Team. You can also set `DEVELOPMENT_TEAM` in `project.yml` and generate again.
4. If the bundle ID `com.bgmwatch.watch` is already taken on your team, change it in `project.yml`.

## Option B: manual Xcode project (fallback)

1. In Xcode, choose **File > New > Project > watchOS > App**.
2. Set Product Name to `BGMWatch`, Interface to SwiftUI and Language to Swift.
3. Choose **Watch-only App**, not "Watch App with New Companion iOS App".
4. Set the organization identifier and product name so the bundle ID becomes `com.bgmwatch.watch`. You can also edit the bundle ID in the target settings later.
5. Delete the template's `ContentView.swift` and `<Name>App.swift`.
6. Drag in `BGMWatchApp.swift`, `ClipPlayer.swift`, `ContentView.swift` and `VolumeControlView.swift` from `BGMWatch/`. Tick **Copy items if needed** and the watch app target.
7. Drag in `BGMWatch/Resources/dude_emotional.m4a` and tick the target. Under **Build Phases**, check that it appears in **Copy Bundle Resources**.
8. You don't need to add any Info.plist keys. The template already sets the watch-only and single-target keys.

## Run on a real Apple Watch

1. On the iPhone, enable Developer Mode under **Settings > Privacy & Security > Developer Mode**, then restart when asked.
2. On the watch, enable Developer Mode the same way. The watch must be paired with that iPhone.
3. Connect the iPhone to the Mac with a cable, or use the same Wi-Fi network. Keep the watch unlocked and on your wrist or nearby. Xcode lists the watch as a run destination. The first connection can take several minutes while Xcode prepares the device.
4. In Xcode, add your Apple ID under **Settings > Accounts**, then pick the team in Signing & Capabilities.
   - **Free account (Personal Team):** apps expire after 7 days and need reinstalling from Xcode. There is a small limit on how many apps you can sign.
   - **Paid account ($99/yr):** profiles last a year, and TestFlight is available.
5. Select the watch as the destination and press **Run** (⌘R).
6. The first time, the watch may refuse to open the app. If so, approve the developer on the watch or the iPhone. Look under **Settings > General > VPN & Device Management** on the iPhone.
7. Tap play. The clip should come out of the watch speaker. Turn the Digital Crown to change the volume.

## Files

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen spec: one `application` target, `platform: watchOS` |
| `BGMWatch/BGMWatchApp.swift` | SwiftUI `@main` app entry |
| `BGMWatch/ClipPlayer.swift` | Audio session setup, `AVAudioPlayer`, state, elapsed timer, errors |
| `BGMWatch/ContentView.swift` | The single screen |
| `BGMWatch/VolumeControlView.swift` | `WKInterfaceVolumeControl` wrapped for SwiftUI |
| `BGMWatch/Resources/` | Your clip goes here (git-ignored) |
