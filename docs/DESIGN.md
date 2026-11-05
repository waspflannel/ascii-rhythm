# Rhythm: Design Doc

## Vision
A chill, meditative, aesthetic desktop rhythm game. Solo only: no multiplayer, no leaderboards. It plays real osu! beatmaps in two modes, with a dithered space look: black, royal blue and white, after the Neptune skin.

## Platform and engine
- Godot 4 (GDScript), desktop export (Windows first, Linux/macOS later), Steam-ready.
- 2D only.

## Game modes
1. **Mania:** vertical lanes (key count from the map: 4K, 7K and so on), tap notes and hold notes, configurable keybinds per key count.
2. **osu! standard:** hit circles with approach circles, sliders (linear, perfect-circle, Bézier and Catmull curves, repeats, ticks), and spinners. Cursor aim plus two hit keys (Z/X) or mouse buttons.

Each mode plays its own map type. Mania maps (Mode: 3) play in Mania, and standard maps (Mode: 0) play in osu! standard. Taiko and catch maps are ignored.

## Beatmaps
- The game reads a project-local `beatmaps/` folder next to the executable (user data dir as fallback).
- It accepts `.osz` archives (unpacked on first scan) and already-unpacked folders.
- It parses `.osu` files: [General] (audio, lead-in, mode), [Metadata], [Difficulty], [TimingPoints], [HitObjects], [Events] (background image path, which song select uses).
- A cached library index is rescanned on launch or on demand.

## Scoring and fail
- Judgements: Perfect / Great / Good / Miss, using osu!-style hit windows derived from OD.
- Score, combo and accuracy are shown in a minimal HUD.
- An HP bar drains on misses and recovers on hits, using HP drain from the map. At zero HP the run fails: a quiet fade-out and a fail screen with retry or quit.
- A results screen shows score, accuracy, max combo, judgement counts and a grade.
- Local best scores are saved per difficulty (offline only).

## Visual style
- **Gameplay screen:** pure black, no background art. Notes, circles, sliders and lanes use the skin's textures, rendered through the dither shader.
- **Dither post-process:** the game renders to a SubViewport, then dithers it, by default a soft 8x8 ordered Bayer dither per colour channel with a light tint towards Neptune's royal blue. Settings picks the dither colour (any colour, or the map's) and every knob: mode (per channel, a palette built from the colour's ramp plus the skin's combo colours, or off), pattern (Bayer, noise, moving grain, flat), strength, matrix and cell size, levels, shades, scanlines and film grain. Each screen change fades through the dither, and an optional subtle beat pulse nudges the brightness on each beat.
- **Gameplay feel:** crisp and tactile without clutter: raw (unaccumulated) mouse input, a flash-and-pop on hits, a tiny local shake on too-early clicks, a cursor that grows while a hit key is held, quick mania key flashes with slow release fades, and judgements that punch in (misses drop quietly). No particles, trails or screen shake.
- **Menus and song select:** the space anime flavour lives here: a drifting star field, katakana accents and dithered map backgrounds; each screen takes its accent colour from the focused or last selected map's art.
- Typography: a wide sans for titles and grade letters, a Didone serif for captions and headings (as in Neptune's art), monospace for numbers and hints.

## Audio and timing
- Song time comes from the audio playback position (with output latency compensation), never frame deltas.
- User-adjustable global audio offset plus an offset calibration screen.
- Optional hitsounds (simple click). The map's own hitsound samples are a later feature.

## Screens
1. Title / main menu
2. Song select (library list, difficulty pick, mode label, preview audio)
3. Gameplay (mania or standard)
4. Pause (resume, retry, quit)
5. Fail screen
6. Results
7. Settings: keybinds, scroll speed (mania), audio offset, volume, dither options (colour picker, every dither knob, reset to default, beat pulse on/off), fullscreen or windowed

## Milestones
1. **Foundation:** Godot project, beatmaps folder scan, .osz/.osu parsing, song select, audio playback with a precise clock, dither post-process.
2. **Mania mode:** lanes, notes and holds, judgements, HP and fail, HUD, results, settings.
3. **osu! standard mode:** circles, sliders, spinners, cursor, judgements, HP and fail.
4. **Polish:** menu and song select art direction, beat pulse tuning, best scores, Steam packaging.

## Out of scope
Multiplayer, online leaderboards, a beatmap editor, mods, storyboards and video backgrounds.

## Testing
Manual playtesting by Jaden. No automated tests unless requested.
