# BGM Watch

Pick a mood on your watch, then a background-music clip, and it plays out loud
from the watch's own speaker. A personal soundtrack for dramatic moments.

| Folder     | Platform                                    | What is there |
|------------|---------------------------------------------|---------------|
| `garmin/`  | Garmin Forerunner 970 (Connect IQ)          | Mood map, clip lists and player. |
| `wearos/`  | Wear OS (Samsung Galaxy Watch, Pixel Watch) | One-clip test. The debug APK builds; it has not been run on a watch. See `wearos/README.md`. |
| `watchos/` | Apple Watch                                 | One-clip test, source only. Never compiled: it needs a Mac with Xcode. See `watchos/README.md`. |

## The clip library

`clips.json` holds two lists.

`emotions` are the bubbles on the watch's mood map:

```json
{ "id": "sad", "label": "SAD", "x": -31, "y": 53 }
```

- `label`: the text inside the bubble.
- `x` and `y`: where the bubble sits, as a percentage of the screen radius from
  the centre. `x` grows to the right and `y` downwards. The six starter
  emotions sit on a hexagon about 62 percent out, which leaves room for the
  ALL bubble in the middle.

`clips` are the sounds, in the order they appear on the watch:

```json
{
  "id": "dude_emotional",
  "title": "Dude - emotional",
  "subtitle": "Dude",
  "emotion": "sad",
  "source": "https://www.youtube.com/watch?v=wpKtmcmZExE",
  "start": "0:07",
  "end": "0:25"
}
```

- `id`: lowercase letters, digits and underscores, starting with a letter.
- `title` and `subtitle`: the two lines shown in a list. Keep the title under
  about 22 characters and use Latin letters; the watch fonts may not have
  other scripts.
- `emotion`: the `id` of an emotion. A clip without one appears only under ALL.
- `source`: a YouTube link, or the path of an audio file inside this folder.
- `start` and `end`: optional. Leave both out to use the whole source.

To get a starting point for `start` and `end`, ask for the loudest 20 seconds
of a track. It measures loudness only, so listen before trusting it:

```
python tools/find_hook.py "https://www.youtube.com/watch?v=wpKtmcmZExE" --seconds 20
```

After editing `clips.json`, run:

```
python tools/build_clips.py
```

For each clip the tool fetches the audio, makes it mono, removes the bass a
watch speaker cannot play, raises the loudness, and encodes it as OGG/Opus
into `garmin/resources/audio/`. It then rewrites the two generated files,
`garmin/resources/audio/audio.xml` and `garmin/source/ClipLibrary.mc`.
Downloads are cached in `clips/cache/`; pass `--force` to fetch them again.

Both tools need Python 3, `ffmpeg` and `ffprobe` on the PATH, and the `yt-dlp`
Python package for YouTube links.

### Audio is not in this repository

The clips are copyrighted music, so `.gitignore` excludes every audio file.
A fresh clone has to run `tools/build_clips.py` once before the Garmin app
will build.

## Garmin

Uses `Toybox.Audio.Output`, added in Connect IQ API level 6.0.3 (SDK 9.3.0,
October 2026). Only watches with a speaker and API 6.0.3 can run it.

Requirements: Connect IQ SDK 9.3.0 with the Forerunner 970 device files
(installed through Garmin's SDK Manager), a JDK, and a developer key at
`%USERPROFILE%\.garmin-ciq\developer_key.der`.

Build, then copy to a watch connected over USB:

```
powershell -File garmin\build.ps1
powershell -File garmin\install.ps1
```

`install.ps1` copies `garmin\bin\bgm.prg` into the watch's `GARMIN\Apps`
folder. Unplug the watch and the app appears in its app list as "BGM".

Controls:

| Screen   | Action                        | Result |
|----------|-------------------------------|--------|
| Mood map | Tap a bubble                  | Open that emotion's clips |
| Mood map | UP / DOWN, or swipe up / down | Move the highlight to another bubble |
| Mood map | START                         | Open the highlighted bubble |
| List     | Swipe, or UP / DOWN           | Scroll through the clips |
| List     | Tap a clip, or START          | Play it and open the player |
| Player   | Tap, or START                 | Stop, or play again from the top |
| Player   | Swipe up, or UP               | Louder |
| Player   | Swipe down, or DOWN           | Quieter |
| Any      | BACK, or swipe right          | Go back one screen (stops the clip) |

The ALL bubble in the middle lists every clip. A bubble grows with the number
of clips filed under it, and a bubble with no clips is dimmed. The volume is
remembered between runs. Audio only plays while the app is open.

The screens are drawn by the app itself in a tactical head-up-display style:
black background, cyan line work, a ring of ticks around the bezel. The look
lives in `garmin/source/Hud.mc`.

To try the app without a watch, start `simulator.exe` from the SDK's `bin`
folder and run `monkeydo garmin\bin\bgm.prg fr970`. The simulator plays the
clips through the computer's speakers.

Known limit: nothing external can launch a Garmin app, so a hot key on the
watch is the fastest way to open it.
