#!/usr/bin/env python3
"""Build the clip library for the watch apps from clips.json.

For every clip listed in clips.json this script:
  1. fetches the audio (a section of a YouTube video through yt-dlp, or a
     local file),
  2. makes it mono and loud enough for a tiny watch speaker,
  3. encodes it for the Garmin app,
and then writes the two generated Garmin files that list the emotions and
clips.

Usage:
    python tools/build_clips.py          # reuse cached downloads
    python tools/build_clips.py --force  # fetch every clip again

Needs ffmpeg and ffprobe on PATH, and the yt-dlp Python package for URLs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import find_hook  # same folder; shares its cache of whole-track downloads

ROOT = Path(__file__).resolve().parent.parent
CLIPS_JSON = ROOT / "clips.json"
CACHE_DIR = ROOT / "clips" / "cache"
GARMIN_AUDIO_DIR = ROOT / "garmin" / "resources" / "audio"
GARMIN_AUDIO_XML = GARMIN_AUDIO_DIR / "audio.xml"
GARMIN_LIBRARY_MC = ROOT / "garmin" / "source" / "ClipLibrary.mc"

# A watch speaker cannot reproduce bass, so cut it and spend the headroom on
# loudness instead.
SPEAKER_FILTER = "highpass=f=180,loudnorm=I=-14:TP=-1.0:LRA=7"

# Ids become Monkey C identifiers and file names.
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


class CommandError(Exception):
    """An external program (ffmpeg, ffprobe, yt-dlp) failed."""


def run(command: list[str]) -> str:
    result = subprocess.run(
        command, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if result.returncode != 0:
        # Keep the message short: yt-dlp errors can include very long URLs.
        output = [line[:200] for line in (result.stderr or result.stdout).strip().splitlines()]
        raise CommandError(
            "Command failed: " + " ".join(command) + "\n" + "\n".join(output[-6:])
        )
    return result.stdout


def check_id(kind: str, value: object, seen: set[str]) -> str:
    if not isinstance(value, str) or not ID_PATTERN.match(value):
        raise SystemExit(
            f"Bad {kind} id {value!r}: use lowercase letters, digits and "
            "underscores, starting with a letter."
        )
    if value in seen:
        raise SystemExit(f"{kind.capitalize()} id {value!r} is used twice.")
    seen.add(value)
    return value


def load_library() -> tuple[list[dict], list[dict]]:
    """Read and check clips.json. Returns (emotions, clips)."""
    data = json.loads(CLIPS_JSON.read_text(encoding="utf-8"))

    emotions = data.get("emotions", [])
    emotion_ids: set[str] = set()
    for emotion in emotions:
        emotion_id = check_id("emotion", emotion.get("id"), emotion_ids)
        if not emotion.get("label"):
            raise SystemExit(f"Emotion {emotion_id!r} is missing 'label'.")
        for axis in ("x", "y"):
            value = emotion.get(axis)
            if isinstance(value, bool) or not isinstance(value, (int, float)) \
                    or not -100 <= value <= 100:
                raise SystemExit(
                    f"Emotion {emotion_id!r}: {axis!r} must be a number from -100 to 100."
                )

    clips = data.get("clips")
    if not isinstance(clips, list) or not clips:
        raise SystemExit('clips.json must contain a non-empty "clips" list.')
    clip_ids: set[str] = set()
    for clip in clips:
        clip_id = check_id("clip", clip.get("id"), clip_ids)
        for key in ("title", "source"):
            if not clip.get(key):
                raise SystemExit(f"Clip {clip_id!r} is missing {key!r}.")
        if clip.get("emotion") is not None and clip["emotion"] not in emotion_ids:
            raise SystemExit(
                f"Clip {clip_id!r} has emotion {clip['emotion']!r}, which is not "
                'in the "emotions" list.'
            )
        # Times may be written as numbers (7) or as text ("0:07").
        for key in ("start", "end"):
            if clip.get(key) is not None:
                clip[key] = str(clip[key])
    return emotions, clips


def fetch(clip: dict, force: bool) -> Path:
    """Return a WAV of the requested section, fetching it only once."""
    source, start, end = clip["source"], clip.get("start"), clip.get("end")
    is_url = source.startswith(("http://", "https://"))
    fingerprint = f"{source}|{start}|{end}"
    local = None
    if not is_url:
        local = (ROOT / source).resolve()
        if not local.is_file():
            raise SystemExit(f"Clip {clip['id']!r}: no file at {local}")
        # A replaced local file must not be served from the cache.
        stat = local.stat()
        fingerprint += f"|{stat.st_size}|{stat.st_mtime_ns}"
    key = hashlib.sha1(fingerprint.encode("utf-8")).hexdigest()[:8]
    wav = CACHE_DIR / f"{clip['id']}-{key}.wav"
    if wav.exists() and not force:
        return wav

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if is_url:
        # Prefer a whole-track copy that find_hook.py already downloaded.
        whole = find_hook.cached(source)
        if whole is None:
            try:
                download_section(source, start, end, wav)
            except CommandError:
                # YouTube sometimes refuses a section download (HTTP 403) but
                # still serves the whole track.
                print(f"{clip['id']}: section download failed, fetching the whole track")
                whole = find_hook.fetch(source)
        if whole is not None:
            cut(whole, start, end, wav)
    else:
        cut(local, start, end, wav)

    if not wav.exists():
        raise SystemExit(f"Clip {clip['id']!r}: fetching produced no file at {wav}")
    return wav


def download_section(source: str, start: str | None, end: str | None, wav: Path) -> None:
    command = [
        sys.executable, "-m", "yt_dlp", "-x", "--audio-format", "wav",
        "--no-playlist", "-o", str(wav.with_suffix(".%(ext)s")),
    ]
    if start or end:
        command += [
            "--download-sections", f"*{start or '0'}-{end or 'inf'}",
            "--force-keyframes-at-cuts",
        ]
    run(command + [source])


def cut(audio: Path, start: str | None, end: str | None, wav: Path) -> None:
    """Copy the section between start and end of a local file into a WAV."""
    # -ss and -to after -i both refer to the input's own timeline.
    command = ["ffmpeg", "-y", "-v", "error", "-i", str(audio), "-vn"]
    if start:
        command += ["-ss", start]
    if end:
        command += ["-to", end]
    run(command + [str(wav)])


def encode_for_garmin(clip: dict, wav: Path) -> tuple[Path, int]:
    """Encode one clip as OGG/Opus and return the file and its length in ms."""
    out = GARMIN_AUDIO_DIR / f"{clip['id']}.opus"
    run([
        "ffmpeg", "-y", "-v", "error", "-i", str(wav), "-af", SPEAKER_FILTER,
        "-ac", "1", "-ar", "24000", "-c:a", "libopus", "-b:a", "32k", str(out),
    ])
    seconds = float(run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(out),
    ]).strip())
    return out, round(seconds * 1000)


def monkey_string(text: str) -> str:
    text = " ".join(text.split())  # a line break would end the string literal
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_garmin_files(emotions: list[dict], clips: list[dict],
                       durations: dict[str, int]) -> None:
    xml = ["<!-- GENERATED by tools/build_clips.py from clips.json. Do not edit. -->",
           "<resources>"]
    xml += [f'    <audio id="{c["id"]}" filename="{c["id"]}.opus" />' for c in clips]
    xml.append("</resources>")
    GARMIN_AUDIO_XML.write_text("\n".join(xml) + "\n", encoding="utf-8", newline="\n")

    emotion_index = {emotion["id"]: i for i, emotion in enumerate(emotions)}
    emotion_lines = [
        "            new Emotion({}, {}, {})".format(
            monkey_string(e["label"]), round(e["x"]), round(e["y"]))
        for e in emotions
    ]
    clip_lines = [
        "            new Clip({}, {}, Rez.Audios.{}, {}, {})".format(
            monkey_string(c["title"]), monkey_string(c.get("subtitle", "")),
            c["id"], durations[c["id"]], emotion_index.get(c.get("emotion"), -1),
        )
        for c in clips
    ]
    source = [
        "// GENERATED by tools/build_clips.py from clips.json. Do not edit.",
        "import Toybox.Lang;",
        "",
        "module ClipLibrary {",
        "",
        "    // Bubbles on the mood map. The two numbers place the bubble, as a",
        "    // percentage of the screen radius from the centre: x to the right,",
        "    // y downwards.",
        "    function getEmotions() as Array<Emotion> {",
        "        return [",
        ",\n".join(emotion_lines),
        "        ] as Array<Emotion>;",
        "    }",
        "",
        "    // Clips in the order they appear in the watch's lists. The last",
        "    // number is the clip's emotion, as an index into getEmotions(), or",
        "    // -1 when it has none.",
        "    function getClips() as Array<Clip> {",
        "        return [",
        ",\n".join(clip_lines),
        "        ] as Array<Clip>;",
        "    }",
        "}",
    ]
    GARMIN_LIBRARY_MC.write_text("\n".join(source) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="fetch every clip again")
    args = parser.parse_args()

    emotions, clips = load_library()
    GARMIN_AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    durations: dict[str, int] = {}
    total_bytes = 0
    for clip in clips:
        wav = fetch(clip, args.force)
        out, durations[clip["id"]] = encode_for_garmin(clip, wav)
        total_bytes += out.stat().st_size
        print(f"{clip['id']:<24} {clip.get('emotion') or '-':<8} "
              f"{durations[clip['id']] / 1000:6.1f} s {out.stat().st_size / 1024:7.1f} KB")

    # Clips removed from clips.json must not stay inside the app.
    wanted = {f"{clip['id']}.opus" for clip in clips}
    for old in GARMIN_AUDIO_DIR.glob("*.opus"):
        if old.name not in wanted:
            old.unlink()
            print(f"removed {old.name}")

    write_garmin_files(emotions, clips, durations)
    print(f"{len(clips)} clips in {len(emotions)} emotions, "
          f"{total_bytes / 1024:.0f} KB of audio for Garmin.")


if __name__ == "__main__":
    try:
        main()
    except CommandError as error:
        raise SystemExit(str(error))
