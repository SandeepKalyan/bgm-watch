# BGM Watch

Press a button on your watch and a short background-music clip plays out loud
from the watch's own speaker. A personal soundtrack for dramatic moments.

This repository holds a one-clip test app per platform. Each one does the same
thing: show the clip name and playback state, play or stop on a button press,
and change volume.

| Folder     | Platform                               | Status |
|------------|----------------------------------------|--------|
| `garmin/`  | Garmin Forerunner 970 (Connect IQ)     | Builds. Not yet run on a watch. |
| `wearos/`  | Wear OS (Samsung Galaxy Watch, Pixel Watch) | See `wearos/README.md`. |
| `watchos/` | Apple Watch                            | See `watchos/README.md`. |

## Audio clips are not in this repository

The clips are copyrighted music, so `.gitignore` excludes every audio file.
Each app expects you to put your own clip in place before building:

- Garmin: `garmin/resources/audio/dude_emotional.opus` (OGG container, Opus
  codec) or a WAV file with LPCM audio. The file name is set in
  `garmin/resources/audio/audio.xml`.
- Wear OS and Apple Watch: see the README in each folder.

To make a clip suited to a tiny speaker (mono, louder, bass removed):

```
ffmpeg -i input.wav -af "loudnorm=I=-14:TP=-1.0:LRA=7,highpass=f=180" -ac 1 -ar 24000 -c:a libopus -b:a 32k dude_emotional.opus
```

## Garmin

Uses `Toybox.Audio.Output`, added in Connect IQ API level 6.0.3 (SDK 9.3.0,
October 2026). Only watches with a speaker and API 6.0.3 can run it.

Requirements: Connect IQ SDK 9.3.0 with the Forerunner 970 device files
(installed through Garmin's SDK Manager), a JDK, and a developer key at
`%USERPROFILE%\.garmin-ciq\developer_key.der`.

Build:

```
powershell -File garmin\build.ps1
```

Install: connect the watch over USB and copy `garmin\bin\bgm.prg` into the
watch's `GARMIN\APPS` folder. The app appears in the watch's app list as "BGM".

Controls: START (or a screen tap) plays or stops the clip. UP and DOWN change
the volume. BACK exits. Audio only plays while the app is open.

Known limits: Garmin's simulator is reported to crash with audio apps on this
device, so testing happens on the real watch. Nothing external can launch a
Garmin app, so a hot key is the fastest way to open it.
