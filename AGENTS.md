# AGENTS.md

This file provides guidance to coding agents working on Small Games.

## Mission

Small Games is a Godot 4 project featuring retro arcade games and ambient art experiments built with GDScript.
The project emphasizes self-contained games, procedural art and audio generation in code, and persistent player data.

Priorities, in order:

1. Responsive arcade gameplay and steady 60 FPS performance.
2. Procedural asset generation in GDScript without external sprite sheets or sound files.
3. Modular organization separating games into distinct folders under `games/`.
4. Small, clear changes that fit the existing GDScript code.

## Core Rules

- Read the affected script and scene files before editing. Prefer focused changes and existing helpers.
- Use English for code, comments, documentation, and tests.
- Target Godot 4.3 and newer. Follow GDScript static typing conventions and avoid dynamic untyped patterns.
- Follow the directory structure: shared modules in `common/`, launcher in `menu/`, and individual games in `games/<game_name>/`.
- Do not commit `.godot/` cache or build files. Keep the repository history clean.
- Small Games is licensed under the Apache License 2.0.

## Writing Style

- Write in simple, plain English. Use short sentences and everyday words.
- Use Oxford commas in inline lists: "a, b, and c" not "a, b, c".
- Do not use em dashes. Restructure the sentence or use a colon or semicolon instead.
- Avoid colorful adjectives and adverbs. Write "adjacency query" not "blazing adjacency query".
- Prefer noun phrases for checklist items over imperative verbs.
- Headings in Markdown files must be in the title case: "Build from Source" not "Build from source". Minor words stay lowercase unless they are the first
  word: the articles (a, an, the), the coordinating conjunctions (and, but, or, nor, so, yet, for), and the short prepositions (in, on, at, to, by,
  of, up, as, from, with, into, over).
- Do not bold the lead-in of a list item.
- Use sentence case for the lead-in of a list item.
- Start each sentence with a capital letter, capitalize proper nouns (Godot, GDScript, Vulkan, Linux), and leave common nouns lowercase in the middle
  of a sentence.
- Write correct and complete sentences.

## Repository Layout

- `project.godot` holds global engine settings, input mappings, viewport defaults, and the main entry scene (`res://menu/menu.tscn`).
- `common/save.gd` manages persistent data (`user://arcade.cfg`), including high scores and master volume.
- `common/sfx.gd` provides real-time procedural waveform synthesis via `AudioStreamWAV`.
- `menu/menu.gd` and `menu.tscn` provide the launcher menu, game selection, high-score display, and volume slider.
- `games/snake/` contains the Snake game implementation (`snake.gd`, `snake.tscn`).
- `games/space_invaders/` contains the Space Invaders implementation (`invaders.gd`, `invaders.tscn`).
- `games/forest/` contains the Forest Walk exploration game (`forest.gd`, `forest.tscn`, `forest_world.gd`, `forest_art.gd`, `forest_audio.gd`).
- `.github/workflows/tests.yml` defines the automated headless validation workflow on GitHub Actions.
- `flake.nix` provides an optional Nix development environment with Godot 4.
- `README.md` documents games, controls, and launch instructions.

## Behavior to Preserve

- All games must include a return to menu shortcut via `ui_cancel` (Esc).
- Preserve procedural drawing in `_draw()` or Image manipulation. Do not introduce binary image or audio assets.
- Save data must remain backward-compatible inside `user://arcade.cfg`.
- Each game runs in its own coordinate space: arcade titles use 640x480 canvas items; Forest Walk uses a 320x180 SubViewport with integer scaling.
- Keep audio synthesis deterministic and bounded in memory. Reuse `AudioStreamPlayer` nodes through pooling.
- Pause overlays must halt simulation while retaining menu navigation.

## Development Workflow

Validate changes using the Godot command-line interface:

```bash
# Run headless import to refresh class cache and indices
godot --headless --path . --import

# Run headless smoke test on any scene
godot --headless --path . res://menu/menu.tscn --quit-after 60
```

For Nix users, run `nix develop` to enter the environment containing Godot.
Run formatting and validation passes before committing code.

## Testing Expectations

- Run headless verification on all scenes before completing changes.
- Ensure all scripts parse cleanly without static type errors or unresolved class references.
- Verify that a scene transitions to and from `res://menu/menu.tscn` work reliably.
- Keep `.godot/`, user save files, temporary recordings, and screenshots out of version control.
