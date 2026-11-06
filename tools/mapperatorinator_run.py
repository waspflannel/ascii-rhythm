"""Runs Mapperatorinator's inference.py for the Editor, from a JSON job the game writes.

    python mapperatorinator_run.py job.json

job: {
  "mapper_dir": Mapperatorinator checkout,
  "config_name": "v32-mini" | "v32",
  "audio": the song (already copied into the set folder),
  "out": the .osu path to write,
  "log": where this run's output goes, which the Editor tails for progress,
  "overrides": {hydra key: number | string | [strings]}
}

Hydra chokes on paths with spaces, so the song is copied to a space-free temp folder and
the map is generated there, then moved to "out". Runs inference in this process, so
killing it (the Editor's Cancel) stops the GPU work too. Exits non-zero on failure; the
Editor shows the log's last line.
"""
import json
import os
import runpy
import shutil
import sys
import tempfile
from pathlib import Path


def hydra_value(value):
    """A value as a Hydra override: strings quoted, lists of strings bracketed."""
    if isinstance(value, list):
        return "[" + ",".join(hydra_value(v) for v in value) + "]"
    if isinstance(value, str):
        # Hydra reads backslashes as escapes, so paths go forward-slashed.
        return "'" + value.replace("\\", "/").replace("'", "\\'").replace("${", "\\${") + "'"
    return str(value)


def main(job):
    mapper = Path(job["mapper_dir"])
    audio = Path(job["audio"])
    out = Path(job["out"])
    # Cancelled runs, and Windows holding Hydra's open log, leave temp folders behind.
    # The Editor runs one at a time, so sweep them first.
    for old in Path(tempfile.gettempdir()).glob("rhythm_mapper_*"):
        shutil.rmtree(old, ignore_errors=True)
    work = Path(tempfile.mkdtemp(prefix="rhythm_mapper_"))
    try:
        # The .osu's AudioFilename is this file's name, so keep the set copy's name.
        shutil.copyfile(audio, work / audio.name)
        overrides = dict(job["overrides"])
        overrides.update(audio_path=(work / audio.name).as_posix(), output_path=work.as_posix())
        sys.argv = [str(mapper / "inference.py"), "--config-name", job["config_name"]]
        sys.argv += [f"{k}={hydra_value(v)}" for k, v in overrides.items()]
        # Hydra's own logs go to the temp folder, not the checkout.
        sys.argv.append(f"hydra.run.dir={hydra_value((work / 'hydra').as_posix())}")
        print("Running:", " ".join(sys.argv[1:]), flush=True)
        # The Editor shows the latest line; this one beats the command above.
        print("Loading model…", flush=True)
        os.chdir(mapper)
        sys.path.insert(0, str(mapper))
        try:
            runpy.run_path(str(mapper / "inference.py"), run_name="__main__")
        except SystemExit as exit_:
            if exit_.code:
                raise
        maps = list(work.glob("*.osu"))
        if not maps:
            raise RuntimeError("Mapperatorinator finished without writing a map")
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(maps[0]), out)
        print(f"WROTE {out}", flush=True)
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    job = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    # Python, tqdm and native output all into the log, as UTF-8 whatever the console is.
    log = open(job["log"], "w", encoding="utf-8", buffering=1)
    os.dup2(log.fileno(), 1)
    os.dup2(log.fileno(), 2)
    sys.stdout = sys.stderr = log
    # Hydra re-raises the real error instead of a bare exit, so the last line names it.
    os.environ["HYDRA_FULL_ERROR"] = "1"
    try:
        main(job)
    except BaseException as error:
        print(f"ERROR: {type(error).__name__}: {error}", flush=True)
        sys.exit(1)
