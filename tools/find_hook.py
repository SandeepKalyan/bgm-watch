#!/usr/bin/env python3
"""Suggest which stretch of a track to use as a clip.

Finds the loudest stretch of the given length, which in film music is usually
the part people recognise, and prints it as start and end times ready to paste
into clips.json. It measures loudness only: listen before trusting it.

Usage:
    python tools/find_hook.py <youtube-url-or-file> [--seconds 20]

Needs ffmpeg on PATH, and the yt-dlp Python package for URLs.
"""

from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE_DIR = ROOT / "clips" / "cache"

RATE = 8000   # Hz. Low, but plenty for measuring loudness.
STEP = 0.5    # Seconds covered by one loudness measurement.
LEAD_IN = 2   # Seconds the start may move earlier to land on a quiet moment.


def cached(source: str) -> Path | None:
    """The whole-track download of a URL made earlier, if there is one."""
    key = hashlib.sha1(source.encode("utf-8")).hexdigest()[:10]
    found = [
        path for path in sorted(CACHE_DIR.glob(f"full-{key}.*"))
        # Skip leftovers of a broken download, such as x.webm.part-Frag3.
        if ".part" not in path.name and path.suffix != ".ytdl"
    ]
    return found[0] if found else None


def fetch(source: str) -> Path:
    """Return a local audio file for the source, downloading a URL only once."""
    if not source.startswith(("http://", "https://")):
        path = Path(source) if Path(source).is_absolute() else (ROOT / source).resolve()
        if not path.is_file():
            raise SystemExit(f"No file at {path}")
        return path

    found = cached(source)
    if found:
        return found
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha1(source.encode("utf-8")).hexdigest()[:10]
    result = subprocess.run(
        [sys.executable, "-m", "yt_dlp", "-f", "bestaudio/best", "--no-playlist",
         "-o", str(CACHE_DIR / f"full-{key}.%(ext)s"), source],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    found = cached(source)
    if result.returncode != 0 or not found:
        tail = "\n".join((result.stderr or result.stdout).strip().splitlines()[-5:])
        raise SystemExit(f"Download failed for {source}\n{tail}")
    return found


def loudness(path: Path) -> list[float]:
    """Mean signal power of each STEP-long slice of the file."""
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
         "-f", "s16le", "-"],
        capture_output=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"ffmpeg could not read {path}")
    samples = array.array("h")
    samples.frombytes(result.stdout[: len(result.stdout) // 2 * 2])
    size = int(RATE * STEP)
    return [
        sum(s * s for s in samples[i:i + size]) / size
        for i in range(0, len(samples) - size + 1, size)
    ]


def pick(power: list[float], seconds: float) -> tuple[int, int]:
    """Start and end, in whole seconds, of the loudest stretch."""
    total = len(power) * STEP
    width = int(seconds / STEP)
    if len(power) <= width:
        return 0, math.ceil(total)

    running = sum(power[:width])
    best, best_sum = 0, running
    for i in range(1, len(power) - width + 1):
        running += power[i + width - 1] - power[i - 1]
        if running > best_sum:
            best, best_sum = i, running

    # Start on the quietest moment just before the loud part, so the clip is
    # less likely to begin halfway through a note.
    earliest = max(0, best - int(LEAD_IN / STEP))
    best = min(range(earliest, best + 1), key=lambda i: power[i])

    start = int(best * STEP)
    start = max(0, min(start, int(total - seconds)))
    return start, start + int(seconds)


def clock(seconds: int) -> str:
    return f"{seconds // 60}:{seconds % 60:02d}"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", help="YouTube URL or path of an audio file")
    parser.add_argument("--seconds", type=float, default=20, help="clip length (default 20)")
    args = parser.parse_args()

    power = loudness(fetch(args.source))
    if not power:
        raise SystemExit("The track has no audio.")
    start, end = pick(power, args.seconds)

    track = sum(power) / len(power)
    section = power[int(start / STEP):int(end / STEP)] or power
    gain = 10 * math.log10((sum(section) / len(section) + 1) / (track + 1))
    print(json.dumps({
        "source": args.source,
        "track_seconds": round(len(power) * STEP),
        "start": clock(start),
        "end": clock(end),
        "louder_than_track_db": round(gain, 1),
    }))


if __name__ == "__main__":
    main()
