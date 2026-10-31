# ASCII Rhythm (working title)

An aesthetic osu!mania-style desktop rhythm game with simple graphics, ASCII art and a real-time dither post-process shader. Built with Godot 4 (GDScript). See [docs/DESIGN.md](docs/DESIGN.md).

## Open and run

1. Install [Godot 4.4 or newer](https://godotengine.org/download) (standard build, not .NET).
2. In the Project Manager, choose **Import**, pick this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the Play button) to run. The main scene is `scenes/main.tscn`.

From a terminal: `godot --path .` runs the game, `godot -e --path .` opens the editor.

## Layout

- `scenes/`: scenes (`main.tscn` hosts the dithered SubViewport, `main_menu.tscn` the placeholder menu)
- `scripts/core/`: autoloads (`Settings`, `GameState`, `SongClock`) and the main scene script
- `scripts/beatmap/`, `scripts/modes/mania/`, `scripts/modes/standard/`, `scripts/ui/`: per-feature scripts
- `shaders/dither.gdshader`: Bayer ordered dither to the black / crimson / off-white palette
- `assets/fonts/`: fonts
- `beatmaps/`: drop `.osz` files or map folders here (gitignored)

Settings are saved to `user://settings.cfg` (on Windows, `%APPDATA%\Godot\app_userdata\ASCII Rhythm\`).
