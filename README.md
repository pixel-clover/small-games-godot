## Small Games

[![Tests](https://img.shields.io/github/actions/workflow/status/pixel-clover/small-games-godot/tests.yml?label=tests&style=flat&labelColor=282c34&logo=github)](https://github.com/pixel-clover/small-games-godot/actions/workflows/tests.yml)
[![License](https://img.shields.io/badge/license-Apache_2.0-007ec6?style=flat&labelColor=282c34&logo=open-source-initiative)](LICENSE)
[![Godot Engine](https://img.shields.io/badge/godot-4.x-478cbf?style=flat&labelColor=282c34&logo=godotengine&logoColor=white)](https://godotengine.org)

A collection of retro arcade games and ambient art experiments built in Godot game engine.

---

### Quickstart

#### A. Clone the project

```bash
git clone --depth=1 https://github.com/pixel-clover/small-games-godot.git
cd small-games-godot
```

#### B. Run the project in Godot

Run the project with Godot 4.3 or newer from your terminal:

```bash
godot --path .
```

If you use Nix, run:

```bash
nix develop --command godot --path .
```

> [!NOTE]
> You can also open the project folder in the Godot editor and press `F5`.
> Use the arrow keys to select a game from the launcher menu, and press `Enter` to start.
> Press `Esc` during any game to return to the launcher menu.

---

### General Controls

Controllers use Godot's standard gamepad mappings.
The labels below use the Xbox layout.
PlayStation controllers use Cross for A, Circle for B, Square for X, Triangle for Y, and R1 for RB.

| Control             | Action                                                                           |
|---------------------|----------------------------------------------------------------------------------|
| D-pad or left stick | Menu navigation and player movement.                                             |
| A                   | Game launch, shooting, and restart.                                              |
| B                   | Back, journal close, or return to the menu. Invaders returns to its title first. |
| Start               | Pause or resume.                                                                 |
| X                   | Forest journal or Snake wrap mode before a run and after game over.              |
| Y                   | Forest time advance.                                                             |
| RB                  | Forest and Neon Breach running while held.                                       |

Use left or right to adjust the focused volume slider.
Keyboard and mouse controls remain available.

### Games

#### Neon Breach

A retro first-person shooter set in an industrial station.
Clear six guards, collect the keycard, and reach the green exit pad.
Health and ammo pickups help you finish the run.
Scores are saved locally.
Everything, including the station, enemy sprites, weapons, and sound effects are generated in code.

| Keyboard and Mouse  | Controller          | Action                  |
|---------------------|---------------------|-------------------------|
| WASD or arrows      | Left stick or D-pad | Movement and strafing.  |
| Mouse or Q/E        | Right stick         | Look and turn.          |
| Left click or Space | RT or A             | Fire.                   |
| Shift               | RB                  | Run.                    |
| P                   | Start               | Pause or resume.        |
| Enter               | A                   | Start or retry.         |
| Esc                 | B                   | Return to the launcher. |

#### Forest Walk

<br>
<div align="center">
  <img alt="UI" src="docs/assets/screenshots/forest_walk_v1_1.png" width="99%">
</div>

---

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) to learn how to contribute.

### License

This project is licensed under the Apache License 2.0 (see [LICENSE](LICENSE)).
