#!/usr/bin/env python3
"""Build the licensed racing audio pack from real-world source recordings.

Requires FFmpeg and FFprobe on PATH. All automotive sounds come from the
downloaded CC0 recordings in sources/. Only the electronic start beep is
synthesized, as explicitly allowed by the asset specification.
"""

from __future__ import annotations

import array
import math
import re
import shutil
import subprocess
import tempfile
import wave
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "sources"
OUTPUT = ROOT / "racing_audio"
ARCHIVE = ROOT / "racing_game_audio_pack.zip"
SAMPLE_RATE = 48_000

SOURCE = {
    "engine": SOURCES / "669618_mini_cooper_engine.mp3",
    "drift": SOURCES / "271337_car_peels_off.mp3",
    "distant_drift": SOURCES / "752837_distant_tire_screech.mp3",
    "crash": SOURCES / "237375_car_crash.mp3",
    "crash_glass": SOURCES / "592388_car_crash_glass.mp3",
    "rc_impact": SOURCES / "726486_rc_car_metal_impact.mp3",
    "metal_crash": SOURCES / "40158_metal_crash.mp3",
    "metal_hit": SOURCES / "321482_metal_hit.mp3",
    "scrap": SOURCES / "587443_scrap_metal_variants.mp3",
    "car_gravel": SOURCES / "529225_car_tires_gravel.mp3",
    "gravel": SOURCES / "251662_tires_gravel_road.mp3",
    "grass": SOURCES / "364712_rustling_grass.mp3",
}

SOURCE_LABELS = {
    SOURCE["engine"]: "Freesound 669618",
    SOURCE["drift"]: "Freesound 271337",
    SOURCE["distant_drift"]: "Freesound 752837",
    SOURCE["crash"]: "Freesound 237375",
    SOURCE["crash_glass"]: "Freesound 592388",
    SOURCE["rc_impact"]: "Freesound 726486",
    SOURCE["metal_crash"]: "Freesound 40158",
    SOURCE["metal_hit"]: "Freesound 321482",
    SOURCE["scrap"]: "Freesound 587443",
    SOURCE["car_gravel"]: "Freesound 529225",
    SOURCE["gravel"]: "Freesound 251662",
    SOURCE["grass"]: "Freesound 364712",
}


def run(*args: str, capture: bool = False) -> str:
    result = subprocess.run(
        args,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.PIPE if capture else subprocess.DEVNULL,
    )
    return result.stdout + result.stderr if capture else ""


def require_tools_and_sources() -> None:
    for tool in ("ffmpeg", "ffprobe"):
        if shutil.which(tool) is None:
            raise SystemExit(f"{tool} is required. Install it with: brew install ffmpeg")
    missing = [str(path.relative_to(ROOT)) for path in SOURCE.values() if not path.is_file()]
    if missing:
        raise SystemExit("Missing source recordings:\n" + "\n".join(missing))


def ffmpeg_render(inputs: list[Path], filter_graph: str, output: Path) -> None:
    command = ["ffmpeg", "-y", "-loglevel", "error"]
    for source in inputs:
        command.extend(("-i", str(source)))
    command.extend(
        (
            "-filter_complex",
            filter_graph,
            "-map",
            "[out]",
            "-ar",
            str(SAMPLE_RATE),
            "-ac",
            "2",
            "-c:a",
            "pcm_s16le",
            str(output),
        ),
    )
    run(*command)


def peak_db(path: Path) -> float:
    output = run(
        "ffmpeg",
        "-hide_banner",
        "-i",
        str(path),
        "-af",
        "volumedetect",
        "-f",
        "null",
        "-",
        capture=True,
    )
    match = re.search(r"max_volume:\s*(-?[\d.]+) dB", output)
    if not match:
        raise RuntimeError(f"Could not measure peak for {path}")
    return float(match.group(1))


def normalize_peak(source: Path, output: Path, target_db: float) -> None:
    gain = target_db - peak_db(source)
    run(
        "ffmpeg",
        "-y",
        "-loglevel",
        "error",
        "-i",
        str(source),
        "-af",
        f"volume={gain:.3f}dB",
        "-ar",
        str(SAMPLE_RATE),
        "-ac",
        "2",
        "-c:a",
        "pcm_s16le",
        str(output),
    )


def base_chain(start: float, end: float) -> str:
    return (
        f"atrim=start={start}:end={end},asetpts=PTS-STARTPTS,"
        f"aresample={SAMPLE_RATE},aformat=sample_fmts=fltp:channel_layouts=stereo,"
        "highpass=f=28:p=2,lowpass=f=18000:p=1"
    )


def build_loop(
    source: Path,
    start: float,
    end: float,
    crossfade: float,
    output: Path,
    target_db: float,
    work: Path,
    extra_filter: str = "",
) -> None:
    raw = work / f"{output.stem}-raw.wav"
    chain = base_chain(start, end)
    if extra_filter:
        chain += "," + extra_filter
    segment_duration = end - start
    middle_end = segment_duration - crossfade
    graph = (
        f"[0:a]{chain},asplit=3[whole1][whole2][whole3];"
        f"[whole1]atrim=start={crossfade}:end={middle_end},"
        "asetpts=PTS-STARTPTS[middle];"
        f"[whole2]atrim=start={middle_end}:end={segment_duration},"
        "asetpts=PTS-STARTPTS[tail];"
        f"[whole3]atrim=start=0:end={crossfade},asetpts=PTS-STARTPTS[head];"
        f"[tail][head]acrossfade=d={crossfade}:c1=qsin:c2=qsin[seam];"
        "[middle][seam]concat=n=2:v=0:a=1[out]"
    )
    ffmpeg_render([source], graph, raw)
    normalize_peak(raw, output, target_db)


def build_one_shot(
    source: Path,
    start: float,
    end: float,
    output: Path,
    target_db: float,
    work: Path,
    extra_filter: str = "",
) -> None:
    raw = work / f"{output.stem}-raw.wav"
    shot_duration = end - start
    fade_out_start = max(0.02, shot_duration - min(0.16, shot_duration / 3))
    chain = base_chain(start, end)
    if extra_filter:
        chain += "," + extra_filter
    graph = (
        f"[0:a]{chain},afade=t=in:st=0:d=0.006,"
        f"afade=t=out:st={fade_out_start:.4f}:d={shot_duration - fade_out_start:.4f}"
        "[out]"
    )
    ffmpeg_render([source], graph, raw)
    normalize_peak(raw, output, target_db)


def build_mix(
    layers: list[tuple[Path, float, float, float]],
    output: Path,
    target_db: float,
    work: Path,
) -> None:
    raw = work / f"{output.stem}-raw.wav"
    filters = []
    labels = []
    longest = max(end - start for _, start, end, _ in layers)
    for index, (_, start, end, volume) in enumerate(layers):
        label = f"layer{index}"
        filters.append(
            f"[{index}:a]{base_chain(start, end)},volume={volume},"
            f"apad=whole_dur={longest},atrim=end={longest}[{label}]",
        )
        labels.append(f"[{label}]")
    fade_start = max(0.02, longest - min(0.2, longest / 3))
    filters.append(
        "".join(labels)
        + f"amix=inputs={len(labels)}:normalize=0:duration=longest,"
        + "afade=t=in:st=0:d=0.006,"
        + f"afade=t=out:st={fade_start:.4f}:d={longest - fade_start:.4f}[out]",
    )
    ffmpeg_render([layer[0] for layer in layers], ";".join(filters), raw)
    normalize_peak(raw, output, target_db)


def build_beep(output: Path) -> None:
    beep_duration = 0.18
    frames = int(SAMPLE_RATE * beep_duration)
    samples = array.array("h")
    for frame in range(frames):
        time = frame / SAMPLE_RATE
        attack = min(1.0, time / 0.012)
        release = min(1.0, (beep_duration - time) / 0.045)
        envelope = max(0.0, min(attack, release))
        chirp = 920.0 + 55.0 * (time / beep_duration)
        value = (
            math.sin(2.0 * math.pi * chirp * time)
            + 0.28 * math.sin(2.0 * math.pi * chirp * 2.0 * time)
            + 0.08 * math.sin(2.0 * math.pi * chirp * 3.0 * time)
        )
        sample = int(13_200 * envelope * value)
        samples.extend((sample, sample))
    write_samples(output, samples)


def write_samples(output: Path, samples: array.array) -> None:
    with wave.open(str(output), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(samples.tobytes())


def build_countdown(beep: Path, output: Path) -> None:
    with wave.open(str(beep), "rb") as wav:
        beep_samples = array.array("h", wav.readframes(wav.getnframes()))
    interval_frames = int(0.82 * SAMPLE_RATE)
    interval_samples = interval_frames * 2
    countdown = array.array("h")
    for index in range(3):
        countdown.extend(beep_samples)
        if index < 2:
            countdown.extend([0] * (interval_samples - len(beep_samples)))
    write_samples(output, countdown)


class AudioBuild:
    """Builds output files and records their real source recordings."""

    def __init__(self, work: Path) -> None:
        self.work = work
        self.sources_by_output: dict[Path, str] = {}

    def loop(
        self,
        source: Path,
        start: float,
        end: float,
        crossfade: float,
        output: Path,
        target_db: float,
        extra_filter: str = "",
    ) -> None:
        build_loop(
            source,
            start,
            end,
            crossfade,
            output,
            target_db,
            self.work,
            extra_filter,
        )
        self.record(output, source)

    def one_shot(
        self,
        source: Path,
        start: float,
        end: float,
        output: Path,
        target_db: float,
        extra_filter: str = "",
    ) -> None:
        build_one_shot(
            source,
            start,
            end,
            output,
            target_db,
            self.work,
            extra_filter,
        )
        self.record(output, source)

    def mix(
        self,
        layers: list[tuple[Path, float, float, float]],
        output: Path,
        target_db: float,
    ) -> None:
        build_mix(layers, output, target_db, self.work)
        self.record(output, *(source for source, _, _, _ in layers))

    def generated(self, output: Path) -> None:
        self.sources_by_output[output] = "Original electronic synthesis"

    def record(self, output: Path, *sources: Path) -> None:
        labels = dict.fromkeys(SOURCE_LABELS[source] for source in sources)
        self.sources_by_output[output] = " + ".join(labels)


def wav_metrics(path: Path) -> dict[str, float | int]:
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        sample_width = wav.getsampwidth()
        rate = wav.getframerate()
        frames = wav.getnframes()
        samples = array.array("h", wav.readframes(frames))
    peak = max(abs(value) for value in samples) if samples else 0
    clipping = sum(abs(value) >= 32767 for value in samples)
    peak_level = 20.0 * math.log10(peak / 32768.0) if peak else -math.inf
    seam = 0.0
    if "_loop" in path.name and frames > 0:
        differences = [
            abs(samples[channel] - samples[-channels + channel]) / 32768.0
            for channel in range(channels)
        ]
        seam = max(differences)
    return {
        "duration": frames / rate,
        "rate": rate,
        "bits": sample_width * 8,
        "peak_db": peak_level,
        "clipping": clipping,
        "seam": seam,
    }


def write_report(files: list[Path], sources_by_output: dict[Path, str]) -> None:
    rows = []
    loop_rows = []
    failures = []
    for path in files:
        metrics = wav_metrics(path)
        if metrics["rate"] != SAMPLE_RATE:
            failures.append(f"{path}: expected 48000 Hz")
        if metrics["bits"] != 16:
            failures.append(f"{path}: expected 16-bit PCM")
        if metrics["clipping"]:
            failures.append(f"{path}: {metrics['clipping']} clipped samples")
        if "_loop" in path.name and metrics["seam"] > 0.12:
            failures.append(f"{path}: large loop seam delta {metrics['seam']:.4f}")
        rows.append(
            "| {name} | {duration:.3f} s | {rate} Hz | {peak:.2f} | {source} | CC0 |".format(
                name=path.relative_to(OUTPUT),
                duration=metrics["duration"],
                rate=metrics["rate"],
                peak=metrics["peak_db"],
                source=sources_by_output[path],
            ),
        )
        if "_loop" in path.name:
            loop_rows.append(
                f"| {path.relative_to(OUTPUT)} | {metrics['seam']:.6f} | Pass |",
            )
    report = (
        "# Audio build report\n\n"
        "All files are stereo 16-bit PCM WAV. `Peak dBFS` is measured after export.\n\n"
        "| Filename | Duration | Sample rate | Peak dBFS | Source | License |\n"
        "|---|---:|---:|---:|---|---|\n"
        + "\n".join(rows)
        + "\n\n"
        + "## Validation\n\n"
        + "- Sample rate: 48 kHz for every file.\n"
        + "- Encoding: 16-bit PCM for every file.\n"
        + "- Clipped samples: 0 in every file.\n"
        + "- Loop seam check: absolute end-to-start sample delta must be at most 0.12 full scale.\n\n"
        + "| Loop | End/start delta | Result |\n"
        + "|---|---:|---|\n"
        + "\n".join(loop_rows)
        + "\n"
    )
    (ROOT / "AUDIO_REPORT.md").write_text(report, encoding="utf-8")
    if failures:
        raise RuntimeError("Audio validation failed:\n" + "\n".join(failures))


def create_archive(files: list[Path]) -> None:
    with zipfile.ZipFile(ARCHIVE, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, path.relative_to(ROOT))
        for path in sorted(SOURCES.glob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(ROOT))
        for documentation in ("SOURCES.md", "ATTRIBUTION.txt", "AUDIO_REPORT.md"):
            archive.write(ROOT / documentation, documentation)
        archive.write(Path(__file__), Path(__file__).name)


def main() -> None:
    require_tools_and_sources()
    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    for category in ("engine", "tires", "collision", "surface", "ui"):
        (OUTPUT / category).mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="toy-racers-audio-") as temporary:
        work = Path(temporary)
        build = AudioBuild(work)
        engine = OUTPUT / "engine"
        build.loop(SOURCE["engine"], 4.2, 10.2, 0.45, engine / "engine_idle_loop.wav", -8.0)
        build.loop(SOURCE["engine"], 14.0, 20.0, 0.45, engine / "engine_low_loop.wav", -7.0)
        build.loop(SOURCE["engine"], 27.0, 33.0, 0.45, engine / "engine_mid_loop.wav", -6.0)
        build.loop(SOURCE["engine"], 46.0, 52.0, 0.45, engine / "engine_high_loop.wav", -5.0)
        build.one_shot(
            SOURCE["engine"],
            64.0,
            70.2,
            engine / "engine_acceleration.wav",
            -3.5,
        )

        tires = OUTPUT / "tires"
        build.loop(
            SOURCE["drift"],
            0.18,
            3.02,
            0.3,
            tires / "tire_drift_loop.wav",
            -5.0,
            "highpass=f=180:p=1",
        )
        build.one_shot(
            SOURCE["distant_drift"],
            3.0,
            4.35,
            tires / "brake_light.wav",
            -8.0,
            "highpass=f=150:p=1",
        )
        build.one_shot(
            SOURCE["drift"],
            0.05,
            1.75,
            tires / "brake_hard.wav",
            -5.0,
            "highpass=f=140:p=1",
        )
        build.mix(
            [
                (SOURCE["drift"], 0.65, 2.75, 0.9),
                (SOURCE["distant_drift"], 6.2, 8.3, 0.45),
            ],
            tires / "brake_lockup.wav",
            -3.5,
        )

        collision = OUTPUT / "collision"
        build.one_shot(SOURCE["rc_impact"], 0.0, 1.25, collision / "collision_light_01.wav", -8.0)
        build.one_shot(SOURCE["metal_hit"], 0.0, 1.25, collision / "collision_light_02.wav", -7.0)
        build.one_shot(SOURCE["scrap"], 0.15, 2.35, collision / "collision_medium_01.wav", -5.5)
        build.one_shot(SOURCE["scrap"], 3.05, 5.35, collision / "collision_medium_02.wav", -5.0)
        build.one_shot(SOURCE["metal_crash"], 0.0, 2.8, collision / "collision_medium_03.wav", -4.5)
        build.mix(
            [
                (SOURCE["crash"], 0.0, 3.3, 0.9),
                (SOURCE["crash_glass"], 0.0, 2.56, 0.7),
            ],
            collision / "collision_heavy_01.wav",
            -2.5,
        )
        build.mix(
            [
                (SOURCE["crash_glass"], 0.0, 2.56, 0.95),
                (SOURCE["scrap"], 10.2, 13.1, 0.65),
            ],
            collision / "collision_heavy_02.wav",
            -2.0,
        )

        surface = OUTPUT / "surface"
        gravel_loop = work / "gravel-loop.wav"
        grass_vehicle_loop = work / "grass-vehicle-loop.wav"
        grass_rustle_loop = work / "grass-rustle-loop.wav"
        build_loop(SOURCE["car_gravel"], 3.0, 9.2, 0.5, gravel_loop, -8.0, work)
        gravel_output = surface / "offtrack_gravel_loop.wav"
        shutil.copy2(gravel_loop, gravel_output)
        build.record(gravel_output, SOURCE["car_gravel"])
        build_loop(SOURCE["car_gravel"], 17.0, 23.2, 0.5, grass_vehicle_loop, -12.0, work)
        build_loop(SOURCE["grass"], 0.3, 6.3, 0.45, grass_rustle_loop, -9.0, work)
        grass_raw = work / "offtrack-grass-raw.wav"
        ffmpeg_render(
            [grass_vehicle_loop, grass_rustle_loop],
            "[0:a]volume=0.65[a];[1:a]volume=0.8[b];"
            "[a][b]amix=inputs=2:normalize=0:duration=shortest[out]",
            grass_raw,
        )
        grass_output = surface / "offtrack_grass_loop.wav"
        normalize_peak(grass_raw, grass_output, -8.5)
        build.record(grass_output, SOURCE["car_gravel"], SOURCE["grass"])
        build.one_shot(SOURCE["car_gravel"], 18.2, 19.15, surface / "gravel_hit_01.wav", -7.0)
        build.one_shot(SOURCE["car_gravel"], 20.0, 21.05, surface / "gravel_hit_02.wav", -6.5)
        build.one_shot(SOURCE["gravel"], 4.2, 5.35, surface / "gravel_hit_03.wav", -6.0)

        ui = OUTPUT / "ui"
        build_beep(ui / "start_beep.wav")
        build_countdown(ui / "start_beep.wav", ui / "start_countdown_3.wav")
        build.generated(ui / "start_beep.wav")
        build.generated(ui / "start_countdown_3.wav")

    files = sorted(OUTPUT.rglob("*.wav"))
    write_report(files, build.sources_by_output)
    create_archive(files)
    print((ROOT / "AUDIO_REPORT.md").read_text(encoding="utf-8"))
    print(f"Created {ARCHIVE.name} with {len(files)} WAV files.")


if __name__ == "__main__":
    main()
