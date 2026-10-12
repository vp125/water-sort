# Water Sort

A relaxing water-sort puzzle game made with **Godot 4.7** (GDScript): 100 levels, glass-tube visuals,
animated pours, hints, undo, colour-blind symbols, a first-time tutorial, sound effects and ambient music.

**Play in your browser:** https://vp125.github.io/water-sort/ (best on a phone; add to Home Screen)

## Rules
Pour the top colour of one tube onto another tube that is empty or has the same top colour. A pour moves
the whole run of that colour that fits. Fill every tube with a single colour to win.

## Levels
| Levels | Idea |
|---|---|
| 1-50 | Classic: 3 to 12 colours, 4-unit tubes |
| 51-75 | Squeeze: 10 to 12 colours with only one spare tube |
| 76-100 | Tall tubes: 5-unit tubes, 8 to 12 colours |

Levels are generated deterministically and verified solvable (see `tests/run_tests.gd`).

## Run / test
```
godot --path .                                   # play
godot --headless --path . --import               # first time only
godot --headless --path . -s tests/run_tests.gd  # run the tests
python tools/generate_audio.py                   # regenerate all sounds and music
godot --headless --path . -s tools/bake_levels.gd  # re-bake levels after changing level generation
```

## Exporting
See [docs/IOS_EXPORT.md](docs/IOS_EXPORT.md) for iPhone/iPad. The web build is exported with the "Web" preset.

## Project layout
- `scripts/core/` game rules, solver, level generation (no UI code)
- `scripts/ui/` screens, tube drawing and UI widgets (all drawn in code)
- `scripts/autoload/` progress, audio and settings singletons
- `tools/` icon renderer and procedural audio generator

## License

[MIT](LICENSE) - covers the code and also the generated sounds, music and icon.
