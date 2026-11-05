# ASCII Rhythm (working title)

An aesthetic osu!mania-style desktop rhythm game with simple graphics, ASCII art and skinned hit objects. Built with Godot 4 (GDScript). See [docs/DESIGN.md](docs/DESIGN.md).

## Open and run

1. Install [Godot 4.4 or newer](https://godotengine.org/download) (standard build, not .NET).
2. In the Project Manager, choose **Import**, pick this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the Play button) to run. The main scene is `scenes/main.tscn`.

From a terminal: `godot --path .` runs the game, `godot -e --path .` opens the editor.

## Layout

- `scenes/`: scenes (`main.tscn` hosts the SubViewport behind the dither shader and fades between screens; `main_menu.tscn`, `song_select.tscn`, `hud.tscn` and `results.tscn` use Neptune menu and HUD art; `ui/map_card.tscn` is a song select card)
- `scripts/core/`: autoloads (`Settings`, `GameState`, `SongClock`, `MapTheme`), the main scene script, `Palette` (UI colours and the palette-mode dither palette) and `SkinAssets` (the active skin folder)
- `scripts/beatmap/parsers/`: `.osu` parsing (`Beatmap` base, `ManiaBeatmap`, `StandardBeatmap`)
- `scripts/beatmap/hit_objects/`: parsed note data (`HitObject` base, `ManiaNote`, `HitCircle`, `Slider`, `Spinner`)
- `scripts/modes/`: gameplay views (`HitObjectView` base, `mania/ManiaNoteView` and `mania/ManiaStage`, `standard/HitCircleView`, `SliderView`, `SpinnerView`), scenes in `scenes/hit_objects/`
- `scripts/ui/`: menu and HUD scripts, including `SpaceBackdrop` (the drifting star field behind the menus) and `AccentPicker` (the Settings colour picker)
- `shaders/dither.gdshader`: Bayer (2x2 to 16x16), noise, moving grain or flat dithering of the whole screen through `shaders/dither_material.tres`, to a palette (each pixel mixes its two nearest palette colours) or per RGB channel, after a tint towards the dither colour, with the strength, scanlines and film grain from Settings; `brightness` drives screen fades and `pulse` the beat pulse
- `assets/fonts/`: Michroma (wide titles and grade letters) and Bodoni Moda (captions and headings), both SIL OFL (licences alongside), the system monospace font for numbers and hints, and a system Japanese font for katakana accents
- `assets/theme/space_theme.tres`: the project theme (`gui/theme/custom`); screens pick styles by type variation (`TitleLabel`, `HeadingLabel`, `CaptionLabel`, `AccentLabel`, `SubLabel`, `HintLabel`, `WideLabel`, `HeroButton`, `BackButton`, `CardButton`, `GlassPanel`, `CaptionBar`)
- `beatmaps/`: drop `.osz` files or map folders here (gitignored)

Settings are saved to `user://settings.cfg` (on Windows, `%APPDATA%\Godot\app_userdata\ASCII Rhythm\`). The `[dither]` section holds the dither look (defaults in parentheses; hand-edited values of the wrong type, and unknown modes, patterns or matrix sizes, fall back to the default, and numbers are clamped):

| Key | Meaning |
| --- | --- |
| `accent` | The dither colour as `#rrggbb` (`#4776ff`, Neptune's royal blue) |
| `follow_map` | The map art's accent drives the dither instead, outside play (`false`) |
| `tint` | How far colours move onto a black, accent, white ramp, 0 to 1 (`0.2`) |
| `mode` | `rgb` dithers each channel, `palette` dithers to the accent's palette, `off` keeps the screen's own colours (`rgb`) |
| `pattern` | `bayer`, `noise` (static), `grain` (noise that moves) or `flat` (nearest colour, no dots) (`bayer`) |
| `strength` | How far the dots spread, 0 to 1 (`0.6`) |
| `matrix_size` | Bayer matrix: 2, 4, 8 or 16; 16 only adds finer tone steps, which show on smooth gradients at high colour levels (`8`) |
| `pixel_scale` | Dither cell size at 1280x720, 1 to 8 px; it grows with the window (`2`) |
| `color_levels` | Levels per channel in `rgb` mode, 2 to 16 (`4`) |
| `shades` | Steps of the accent ramp in `palette` mode, 2 to 7 (`5`) |
| `skin_colours` | `palette` mode keeps the skin's crimson and combo colours (`true`) |
| `scanlines` | How much alternate rows darken, 0 to 1 (`0.0`) |
| `grain` | Film grain over the result, 0 to 0.2 (`0.0`) |
| `beat_pulse` | The dither brightens slightly on each beat during play (`true`) |

In Settings, the DITHER section has **Colour**, **Dither**, **Reset to default** and **Beat pulse**. Colour (a swatch and hex of the dither colour) opens a popover beside the panel with a saturation/value square, a hue strip, a hex field, Follow map and Tint; Dither (a summary such as `RGB · BAYER 8×8`, with the strength beside it) opens one with every knob above, dimming the rows the current mode or pattern ignores. The whole screen redraws live as they change, including while dragging. In a popover, Up/Down move (and wrap), Left/Right adjust, Esc or a click outside closes it; on the colour square, Left/Right change saturation and Enter grabs the dot so all four arrows move it (Enter or Esc lets go). Reset to default asks for a second press within 3 s, then restores every default above but `beat_pulse`. Configs from older versions with `filter` or `palette` keys load as the default look: those keys and the other dither keys are removed, `beat_pulse` is kept. `[history] last_map` is the last map selected in song select, whose art fills mode select on the next launch.

## Player input

Run the project and choose **Standard**. Standard currently selects ILY [Fanteer's Final Level]. With an empty `beatmap_path`, the demo scans unpacked `.osu` files in `beatmaps/` and prefers Normal. It plays the selected map's music. A two-second lead-in lets the first objects appear before the music starts. The HUD shows progress and judgements; **Back** stops playback and returns to mode selection.

**Mania** uses the same flow for Mode 3 maps (any osu! mania `.osu`, for example a ranked 4K or 7K set unpacked into `beatmaps/`), including taps and holds. To pick a specific difficulty, set `beatmap_path` on the inherited mode scene in the Inspector. Runtime music loading supports MP3, Ogg Vorbis, and WAV.

Standard uses cursor aim with Z/X or either mouse button. Hit slider heads, then hold any hit button and follow the ball through the tail; releasing all buttons or leaving the follow circle misses. Hold a hit button and rotate around the center for spinners. Mania uses D F J K for 4K and S D F Space J K L for 7K; other key counts get a symmetric layout around Space (for example F Space J for 3K, A S D F J K L ; for 8K). Judgements follow osu!mania OD windows: MAX (16 ms), 300, 200, 100 and 50, with early presses inside the miss window counting as Miss. Hold notes judge the head on press and the tail on release (1.5x wider windows, as in osu!lazer); still holding when the hold ends gives MAX, and a missed head misses the tail too. Unhit notes expire as Miss. F3 and F4 lower and raise the mania scroll speed (1 to 40, osu!lazer scale) during play; it is saved to settings.

The mania stage follows Neptune's 4K layout (56 px columns, judgement line at 420 of 480) scaled to the screen height, with its key images (pressed versions while a lane key is down) and blue/white notes, hold bodies and tails alternating from the outer lanes in. Neptune's stage, hint and lighting images are blank, so the stage edges are hairlines and the lane lights and hit flashes are gradients in the skin's `[Mania] ColourLight` colours (blue outer lanes, white inner ones).

Gameplay is driven only by player input. Input judgments use SongClock audio time; keyboard repeats are ignored and losing focus releases held inputs.

The HUD captions, messages, and buttons are authored in `scenes/play.tscn` and the inherited mode scenes. Scripts update live values only. Standard hit objects use Neptune textures plus the combo colors and slider colors read from `assets/skins/neptune/skin.ini`; grayscale circle masks are tinted while overlays stay white.

Hit objects prefer the supplied `@2x` sprites with linear mipmap filtering, including skin digit sprites for combo numbers. Slider tracks are generated from beatmap curves (there is no curved-track PNG in the skin), with round joins and skin-defined colors. Each slider is drawn together so overlapping tracks cannot erase one another's borders.

## Renderer preview

Open `scenes/renderer_preview.tscn` and run that scene (F6) for fixed, silent examples of a circle, a slider before its head is hit, and an active repeating slider. The examples share the gameplay views and Neptune skin assets. Normal gameplay adds fade-in, shrinking approach rings, brief hit fades, shaded tracks, endpoints, ticks, repeat arrows, and follow circles. Spinner progress uses a standard scene-authored ProgressBar.

Track shading is a generated approximation; this is not a complete osu! skin engine. The supplied combo colors are preserved rather than forcing the blue tint from the reference screenshot.

## Screens

**Mode select** shows ASCII RHYTHM over a drifting star field, or over the dimmed background of the last map selected in song select (remembered across launches); Standard, Mania and Quit sit on Neptune's menu panels and slide out when hovered or focused. Standard or Mania opens **song select**, which only shows unpacked `.osu` maps in `beatmaps/` for that mode (osu! `Mode: 3` for Mania, `Mode: 0` for Standard; others are skipped). First a vertical list of map sets, one per folder, showing title, artist and mapper: Up/Down, the mouse wheel or a click moves, Enter or a click opens the set. Then a horizontal carousel of that set's difficulties, easiest first, with the key count for Mania: Left/Right, the wheel or a click moves, Enter or a click plays. Esc or **Back** steps back from the carousel to the list (same set highlighted), then to mode select. Song select reopens on the last map played, and the focused map's song loops from its osu! preview point. The focused map's background art fills the screen behind the lists, dimmed and dithered, and the screen takes on its colours (see Map themes); a panel shows the set (title, artist, mapper, difficulty count) or the difficulty (version, key count or CS/AR, HP, OD, object count and length).

**Gameplay** stays black with a small HUD (`scenes/hud.tscn`): Neptune HP bar, map title, score, accuracy and combo in the skin's score digits with serif captions, judgement popups, a thin song progress line and elapsed / total time. With `beat_pulse` on, the dither brightens slightly on each beat (from the map's uninherited timing points). `scripts/core/run_score.gd` turns judgements into osu!-like score (ScoreV1 for Standard, 1,000,000-normalised for Mania with MAX worth 320 and counted as 300 for accuracy), accuracy and HP. Misses drain HP and hits recover it, scaled by the map's HP drain. At zero HP the run fades out; once every object is judged or the song ends, the music fades for two seconds. Both go to the results screen.

**Results** (`scenes/results.tscn`) shows the title, artist, difficulty and mode, score, 300/100/50/Miss counts (MAX/300/200/100/50/Miss for Mania), accuracy, max combo and the osu! grade (SS/S/A/B/C/D; F and FAILED for a failed run), using Neptune's ranking letters, score digits, judgement images, PERFECT badge and RETRY art over the map's dimmed background, themed from it. Neptune's back, accuracy, max combo and F images are blank or missing, so those are drawn in the same style: accent caption bars with serif text, a serif BACK with Neptune's sparkle, and an F in the wide face of Neptune's letters. R or **Retry** replays the map; Esc or **Back** returns to song select on the same difficulty.

**Map themes**: `MapTheme` (`scripts/core/map_theme.gd`) samples the dominant colour of a map's background art (the most colourful hue bucket of a 32x18 thumbnail) and moves Neptune's blue ramp (`Palette.BLUES`) to that hue in the project theme (panels, borders, caption bars, accent and secondary text), so the UI takes on the map's colours. It blends over 0.35 s as song select focus moves; mode select uses the last selected map, and grey art or none keeps Neptune's blue. The dither colour picked in Settings drives the dither (palette ramp and tint) on every screen, play included, over the map's accent. With **Follow map** on, the map's accent drives the dither outside play and Neptune's blue during play, so notes and hit objects keep their skin colours. The HUD's captions and progress line pick up the map's tint either way.

Every screen change fades out and back in through the dither. The window uses the `canvas_items` stretch mode with `expand` aspect, so every screen is laid out at 1280x720 and scaled to fit the window.

## Skin

Neptune (`assets/skins/neptune/`) is a dev-only placeholder skin and is not licensed for release. Scripts build every skin path from `SkinAssets.DIR` (`scripts/core/skin_assets.gd`); scenes and `assets/theme/space_theme.tres` reference files in the same folder, and osu! skins share file names, so swapping skins means replacing that folder (or changing `DIR` and the same path in those resources). Screenshots of every screen are in `docs/screenshots/`.
