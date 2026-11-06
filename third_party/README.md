# third_party

## Mapperatorinator

[Mapperatorinator](https://github.com/OliBomby/Mapperatorinator) (MIT) is the local AI
mapper the Editor uses for its **Mania** and **Standard** maps. It's a git submodule here;
the Editor runs it through `tools/mapperatorinator_run.py` with the Python in its own `.venv`.

### Setup (Windows, NVIDIA GPU)

```powershell
git submodule update --init third_party/Mapperatorinator
cd third_party/Mapperatorinator
py -3.10 -m venv .venv
.venv\Scripts\python -m pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu128
.venv\Scripts\python -m pip install -r requirements.txt
```

Use the CUDA wheel that matches your GPU (cu128 for RTX 50-series); see Mapperatorinator's README. On Linux or macOS the
Editor looks for `.venv/bin/python` instead. The model weights download from Hugging Face
on the first Generate (into the Hugging Face cache in your user folder, not this repo), so
that run is slower.

If the Editor says Mapperatorinator isn't set up, the submodule, `.venv` or the runner is
missing; it never falls back to the heuristic generator.

### What stays out of git

The submodule ignores its `.venv/`, `logs/` and other untracked files (`ignore = untracked`
in `.gitmodules`, plus Mapperatorinator's own `.gitignore`). Weights live in the Hugging
Face cache. `.gdignore` keeps Godot from importing any of it.

### Settings

The Editor picks one mode (`gamemode` 3 for Mania, 0 for Standard) and its settings panel
maps onto Mapperatorinator's inference options. Both modes: model (`v32-mini` is faster,
`v32` fuller), star rating (`difficulty`), style `year`, `descriptors` (comma separated,
e.g. `style/clean`), `device`, `hp_drain_rate`, `overall_difficulty`, `temperature`,
`top_p`, `cfg_scale` and `seed`. Mania adds keys (`keycount`), `hold_note_ratio` and
`scroll_speed_ratio`; Standard adds `circle_size`, `approach_rate`, `slider_multiplier`
and `slider_tick_rate`. Empty fields keep the model's default. A run's log is
`mapperatorinator.log` in Godot's user data folder.
