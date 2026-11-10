# BGM Wear OS

Wear OS port of the one-clip Garmin joke test. One screen: clip title, state
(STOPPED / PLAYING / ERROR), elapsed seconds, a big PLAY/STOP button and the
current media volume. Tap plays the clip from the start, or stops it. The
rotary input (Samsung bezel / Pixel crown) raises and lowers media volume.

Audio is routed to the built-in speaker (`TYPE_BUILTIN_SPEAKER`) via
`MediaPlayer.setPreferredDevice`, even with Bluetooth headphones connected.
No speaker on the watch shows "No speaker on this watch". Playback errors are
shown as text. Standalone app (no phone companion), minSdk 30, plain Views,
no third-party dependencies. One APK covers Galaxy Watch 4+ and Pixel Watch.

## Put your own clip here

The clip is copyrighted and git-ignored. Put your own audio file at:

    app/src/main/res/raw/dude_emotional.<ext>

`.ogg`, `.mp3`, `.wav` or `.m4a` all work (keep exactly one file with that
base name; the code refers to `R.raw.dude_emotional`). Suggested prep for a
tiny speaker (mono, about -14 LUFS, true peak under -1 dB, Opus in Ogg):

    ffmpeg -i in.wav -ac 1 -af "loudnorm=I=-14:TP=-1:LRA=11,aresample=48000,volume=1.2dB,alimiter=limit=0.8:level=disabled:release=50" -ar 48000 -c:a libopus -b:a 64k app/src/main/res/raw/dude_emotional.ogg

To use a different file name, change `R.raw.dude_emotional` in
`MainActivity.kt` and the on-screen title.

## Build

Needs JDK 17+ (built with JDK 21) and the Android SDK (platform android-34).
Put `sdk.dir=...` in `local.properties`.

    .\gradlew.bat assembleDebug

APK: `app\build\outputs\apk\debug\app-debug.apk`

## Install on a real watch (Wi-Fi debugging)

`adb` is in `<sdk>\platform-tools`. Watch and PC must be on the same Wi-Fi.

### Samsung Galaxy Watch 4+

1. Settings > About watch > Software > tap Software version 5 times (developer mode).
2. Settings > Developer options: turn on ADB debugging and Debug over Wi-Fi.
3. Under Debug over Wi-Fi, choose Pair new device; note the pairing IP:port and code.
4. `adb pair <ip>:<pairing-port>` and enter the code.
5. Back on the Debug over Wi-Fi screen note the connect IP:port, then `adb connect <ip>:<port>`.
6. `adb install -r app\build\outputs\apk\debug\app-debug.apk`

### Google Pixel Watch

1. Settings > System > About > Versions > tap Build number 7 times.
2. Settings > Developer options: turn on ADB debugging and Wireless debugging.
3. Wireless debugging > Pair new device; note the pairing IP:port and code.
4. `adb pair <ip>:<pairing-port>` and enter the code.
5. `adb connect <ip>:<port>` using the IP and port shown on the Wireless debugging screen.
6. `adb install -r app\build\outputs\apk\debug\app-debug.apk`

The connect port differs from the pairing port and can change after each
toggle. If several devices are attached, add `-s <ip>:<port>` to adb.
Launch the app from the watch app list ("BGM").
