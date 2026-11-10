# BGM Watch

Pick a background-music clip on your watch and it plays out loud from the
watch's own speaker. A personal soundtrack for dramatic moments.

| Folder     | Platform                                    | What is there |
|------------|---------------------------------------------|---------------|
| `garmin/`  | Garmin Forerunner 970 (Connect IQ)          | Clip list and player screen. |
| `wearos/`  | Wear OS (Samsung Galaxy Watch, Pixel Watch) | One-clip test. The debug APK builds; it has not been run on a watch. See `wearos/README.md`. |
| `watchos/` | Apple Watch                                 | One-clip test, source only. Never compiled: it needs a Mac with Xcode. See `watchos/README.md`. |

## The clip library

`clips.json` lists the clips, in the order they appear on the watch:

```json
{
  "id": "dude_emotional",
  "title": "Dude - emotional",
  "subtitle": "Dude",
  "source": "https://www.youtube.com/watch?v=wpKtmcmZExE",
  "start": "0:07",
  "end": "0:25"
}
```

- `id`: lowercase letters, digits and underscores, starting with a letter.
- `title` and `subtitle`: the two lines shown in the list. Use Latin letters;
  the watch fonts may not have other scripts.
- `source`: a YouTube link, or the path of an audio file inside this folder.
- `start` and `end`: optional. Leave both out to use the whole source.

After editing `clips.json`, run:

```
python tools/build_clips.py
```

For each clip the tool fetches the audio, makes it mono, removes the bass a
watch speaker cannot play, raises the loudness, and encodes it as OGG/Opus
into `garmin/resources/audio/`. It then rewrites the two generated files,
`garmin/resources/audio/audio.xml` and `garmin/source/ClipLibrary.mc`.
Downloads are cached in `clips/cache/`; pass `--force` to fetch them again.

The tool needs Python 3, `ffmpeg` and `ffprobe` on the PATH, and the `yt-dlp`
Python package for YouTube links.

### Audio is not in this repository

The clips are copyrighted music, so `.gitignore` excludes every audio file
except the generated test tone in `samples/`. A fresh clone has to run
`tools/build_clips.py` once before the Garmin app will build.

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

| Screen | Action                      | Result |
|--------|-----------------------------|--------|
| List   | Swipe, or UP / DOWN         | Scroll through the clips |
| List   | Tap a clip, or START        | Play it and open the player |
| Player | Tap, or START               | Stop, or play again from the top |
| Player | Swipe up, or UP             | Louder |
| Player | Swipe down, or DOWN         | Quieter |
| Player | BACK, or swipe right        | Stop and return to the list |

The volume is remembered between runs. Audio only plays while the app is open.

To try the app without a watch, start `simulator.exe` from the SDK's `bin`
folder and run `monkeydo garmin\bin\bgm.prg fr970`. The simulator plays the
clips through the computer's speakers.

Known limit: nothing external can launch a Garmin app, so a hot key on the
watch is the fastest way to open it.
