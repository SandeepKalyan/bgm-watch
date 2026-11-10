#!/usr/bin/env python3
"""Build the clip library for the watch apps from clips.json.

For every clip listed in clips.json this script:
  1. fetches the audio (a section of a YouTube video through yt-dlp, or a
     local file),
  2. makes it mono and loud enough for a tiny watch speaker,
  3. encodes it for the Garmin app,
and then writes the two generated Garmin files that list the clips.

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

ROOT = Path(__file__).resolve().parent.parent
CLIPS_JSON = ROOT / "clips.json"
CACHE_DIR = ROOT / "clips" / "cache"
GARMIN_AUDIO_DIR = ROOT / "garmin" / "resources" / "audio"
GARMIN_AUDIO_XML = GARMIN_AUDIO_DIR / "audio.xml"
GARMIN_LIBRARY_MC = ROOT / "garmin" / "source" / "ClipLibrary.mc"

# A watch speaker cannot reproduce bass, so cut it and spend the headroom on
# loudness instead.
SPEAKER_FILTER = "highpass=f=180,loudnorm=I=-14:TP=-1.0:LRA=7"

# Clip ids become Monkey C identifiers and file names.
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


def run(command: list[str]) -> str:
    result = subprocess.run(
        command, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if result.returncode != 0:
        output = (result.stderr or result.stdout).strip().splitlines()
        raise SystemExit(
            "Command failed: " + " ".join(command) + "\n" + "\n".join(output[-8:])
        )
    return result.stdout


def load_clips() -> list[dict]:
    clips = json.loads(CLIPS_JSON.read_text(encoding="utf-8")).get("clips")
    if not isinstance(clips, list) or not clips:
        raise SystemExit('clips.json must contain a non-empty "clips" list.')
    seen: set[str] = set()
    for clip in clips:
        clip_id = clip.get("id", "")
        if not ID_PATTERN.match(clip_id):
            raise SystemExit(
                f"Bad clip id {clip_id!r}: use lowercase letters, digits and "
                "underscores, starting with a letter."
            )
        if clip_id in seen:
            raise SystemExit(f"Clip id {clip_id!r} is used twice.")
        seen.add(clip_id)
        for key in ("title", "source"):
            if not clip.get(key):
                raise SystemExit(f"Clip {clip_id!r} is missing {key!r}.")
        # Times may be written as numbers (7) or as text ("0:07").
        for key in ("start", "end"):
            if clip.get(key) is not None:
                clip[key] = str(clip[key])
    return clips


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
    else:
        # -ss and -to after -i both refer to the input's own timeline.
        command = ["ffmpeg", "-y", "-v", "error", "-i", str(local)]
        if start:
            command += ["-ss", start]
        if end:
            command += ["-to", end]
        run(command + [str(wav)])

    if not wav.exists():
        raise SystemExit(f"Clip {clip['id']!r}: fetching produced no file at {wav}")
    return wav


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


def write_garmin_files(clips: list[dict], durations: dict[str, int]) -> None:
    xml = ["<!-- GENERATED by tools/build_clips.py from clips.json. Do not edit. -->",
           "<resources>"]
    xml += [f'    <audio id="{c["id"]}" filename="{c["id"]}.opus" />' for c in clips]
    xml.append("</resources>")
    GARMIN_AUDIO_XML.write_text("\n".join(xml) + "\n", encoding="utf-8", newline="\n")

    entries = [
        "            new Clip({}, {}, Rez.Audios.{}, {})".format(
            monkey_string(c["title"]), monkey_string(c.get("subtitle", "")),
            c["id"], durations[c["id"]],
        )
        for c in clips
    ]
    source = [
        "// GENERATED by tools/build_clips.py from clips.json. Do not edit.",
        "import Toybox.Lang;",
        "",
        "module ClipLibrary {",
        "",
        "    // Clips in the order they appear in the watch's list.",
        "    function getClips() as Array<Clip> {",
        "        return [",
        ",\n".join(entries),
        "        ] as Array<Clip>;",
        "    }",
        "}",
    ]
    GARMIN_LIBRARY_MC.write_text("\n".join(source) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="fetch every clip again")
    args = parser.parse_args()

    clips = load_clips()
    GARMIN_AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    durations: dict[str, int] = {}
    total_bytes = 0
    for clip in clips:
        wav = fetch(clip, args.force)
        out, durations[clip["id"]] = encode_for_garmin(clip, wav)
        total_bytes += out.stat().st_size
        print(f"{clip['id']:<24} {durations[clip['id']] / 1000:6.1f} s "
              f"{out.stat().st_size / 1024:7.1f} KB")

    # Clips removed from clips.json must not stay inside the app.
    wanted = {f"{clip['id']}.opus" for clip in clips}
    for old in GARMIN_AUDIO_DIR.glob("*.opus"):
        if old.name not in wanted:
            old.unlink()
            print(f"removed {old.name}")

    write_garmin_files(clips, durations)
    print(f"{len(clips)} clips, {total_bytes / 1024:.0f} KB of audio for Garmin.")


if __name__ == "__main__":
    main()
