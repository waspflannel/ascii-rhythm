# ASCII Rhythm (working title)

An aesthetic osu!mania-style desktop rhythm game with simple graphics, ASCII art and skinned hit objects. Built with Godot 4 (GDScript). See [docs/DESIGN.md](docs/DESIGN.md).

## Open and run

1. Install [Godot 4.4 or newer](https://godotengine.org/download) (standard build, not .NET).
2. In the Project Manager, choose **Import**, pick this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the Play button) to run. The main scene is `scenes/main.tscn`.

From a terminal: `godot --path .` runs the game, `godot -e --path .` opens the editor.

## Layout

- `scenes/`: scenes (`main.tscn` hosts a full-resolution SubViewport behind the dither shader; `main_menu.tscn`, `song_select.tscn` and `hud.tscn` use Neptune menu and HUD art)
- `scripts/core/`: autoloads (`Settings`, `GameState`, `SongClock`) and the main scene script
- `scripts/beatmap/parsers/`: `.osu` parsing (`Beatmap` base, `ManiaBeatmap`, `StandardBeatmap`)
- `scripts/beatmap/hit_objects/`: parsed note data (`HitObject` base, `ManiaNote`, `HitCircle`, `Slider`, `Spinner`)
- `scripts/modes/`: gameplay views (`HitObjectView` base, `mania/ManiaNoteView`, `standard/HitCircleView`, `SliderView`, `SpinnerView`), scenes in `scenes/hit_objects/`
- `scripts/ui/`: menu scripts
- `shaders/dither.gdshader`: Bayer ordered RGB dithering applied to the whole screen through `shaders/dither_material.tres` (`color_levels`, `matrix_size`, `pixel_scale`; the last two come from Settings)
- `assets/fonts/`: fonts
- `beatmaps/`: drop `.osz` files or map folders here (gitignored)

Settings are saved to `user://settings.cfg` (on Windows, `%APPDATA%\Godot\app_userdata\ASCII Rhythm\`).

## Player input

Run the project and choose **Standard**. Standard currently selects ILY [Fanteer's Final Level]. With an empty `beatmap_path`, the demo scans unpacked `.osu` files in `beatmaps/` and prefers Normal. It plays the selected map's music. A two-second lead-in lets the first objects appear before the music starts. The HUD shows progress and judgements; **Back** stops playback and returns to mode selection.

**Mania** uses the same flow for Mode 3 maps, including taps and holds. The current ILY folder contains only standard maps, so Mania displays a missing-map message. To pick a specific difficulty, set `beatmap_path` on the inherited mode scene in the Inspector. Runtime music loading supports MP3, Ogg Vorbis, and WAV.

Standard uses cursor aim with Z/X or either mouse button. Hit slider heads, then hold any hit button and follow the ball through the tail; releasing all buttons or leaving the follow circle misses. Hold a hit button and rotate around the center for spinners. Mania uses D F J K for 4K and S D F Space J K L for 7K; hold notes judge both press and release. Unhit notes expire as Miss.

Gameplay is driven only by player input. Input judgments use SongClock audio time; keyboard repeats are ignored and losing focus releases held inputs.

The HUD captions, messages, and buttons are authored in `scenes/play.tscn` and the inherited mode scenes. Scripts update live values only. Standard hit objects use Neptune textures plus the combo colors and slider colors read from `assets/skins/neptune/skin.ini`; grayscale circle masks are tinted while overlays stay white.

Hit objects prefer the supplied `@2x` sprites with linear mipmap filtering, including skin digit sprites for combo numbers. Slider tracks are generated from beatmap curves (there is no curved-track PNG in the skin), with round joins and skin-defined colors. Each slider is drawn together so overlapping tracks cannot erase one another's borders.

## Renderer preview

Open `scenes/renderer_preview.tscn` and run that scene (F6) for fixed, silent examples of a circle, a slider before its head is hit, and an active repeating slider. The examples share the gameplay views and Neptune skin assets. Normal gameplay adds fade-in, shrinking approach rings, brief hit fades, shaded tracks, endpoints, ticks, repeat arrows, and follow circles. Spinner progress uses a standard scene-authored ProgressBar.

Track shading is a generated approximation; this is not a complete osu! skin engine. The supplied combo colors are preserved rather than forcing the blue tint from the reference screenshot.

## Screens

**Mode select** (Mania or Standard) opens **song select**, which only shows unpacked `.osu` maps in `beatmaps/` for that mode (osu! `Mode: 3` for Mania, `Mode: 0` for Standard; others are skipped). First a vertical list of map sets, one per folder, showing title, artist and mapper: Up/Down, the mouse wheel or a click moves, Enter or a click opens the set. Then a horizontal carousel of that set's difficulties, easiest first, with the key count for Mania: Left/Right, the wheel or a click moves, Enter or a click plays. Esc or **Back** steps back from the carousel to the list (same set highlighted), then to mode select. Song select reopens on the last map played.

**Gameplay** stays black with a small HUD (`scenes/hud.tscn`): Neptune HP bar, score, accuracy and combo in the skin's score digits, judgement popups and a thin song progress line. `scripts/core/run_score.gd` turns judgements into osu!-like score (ScoreV1 for Standard, 1,000,000-normalised for Mania), accuracy and HP. Misses drain HP and hits recover it, scaled by the map's HP drain. At zero HP the run fades out; once every object is judged or the song ends, the music fades for two seconds. Both go to the results screen.

**Results** (`scenes/results.tscn`) shows the title, artist, difficulty and mode, score, 300/100/50/Miss counts (300/200/100/Miss for Mania), accuracy, max combo and the osu! grade (SS/S/A/B/C/D; F and FAILED for a failed run), using Neptune's ranking letters, score digits, judgement images, PERFECT badge and RETRY art. Neptune's back and accuracy images are blank, so those use text. R or **Retry** replays the map; Esc or **Back** returns to song select on the same difficulty.

The window uses the `canvas_items` stretch mode with `expand` aspect, so every screen is laid out at 1280x720 and scaled to fit the window.
