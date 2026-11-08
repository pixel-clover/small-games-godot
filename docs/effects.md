# Generated Effects

All four games share one 48-by-48-pixel grayscale burst animation, tinted at runtime.
Its PNG is 2,544 bytes, with no duplicate atlases per game.
The effect source is in [`tools/fx/invader-burst.mjs`](../tools/fx/invader-burst.mjs).
[`common/effects.gd`](../common/effects.gd) handles frame selection and drawing.

| Game           | Use                                                     | Appearance                                         |
|----------------|---------------------------------------------------------|----------------------------------------------------|
| Snake          | Food, bonus, and power-up collection, plus near misses. | Yellow sparkles at the collected cell.             |
| Space Invaders | Alien, UFO, boss, and player explosions.                | Bursts tinted to match the destroyed object.       |
| Forest Walk    | New discoveries.                                        | A smaller gold flash anchored to the world object. |
| Neon Breach    | Successful weapon fire.                                 | A short amber flash at the weapon muzzle.          |

Each game uses its existing simulation timers, so pausing also freezes the animation.
Forest discoveries play over 0.5 seconds, and muzzle flashes play over 0.12 seconds.

## Regeneration

[PixelFX](https://github.com/patch-gg/pixelfx) is an optional generation tool in `external/pixelfx`.
The submodule pins the tested revision, `a84159688af3ca37a4be05a0d422b94451b2e24e`.
Playing the games and running gameplay tests do not require it or Node.js.
To regenerate the atlas, use Node.js 18 or newer and run these commands from the project root:

```bash
git submodule update --init --depth 1 external/pixelfx
node tools/generate_invaders_fx.mjs
```

An existing PixelFX checkout can also be supplied:

```bash
node tools/generate_invaders_fx.mjs /path/to/pixelfx
```

The generator checks the frame layout, transparent ending, deterministic output, and a 16 KiB size limit.
It writes the shared atlas under `common/effects/` and a preview under ignored `tmp/fx-preview/`.
Inspect the preview after changing an effect. Keep nearest-neighbor filtering in Godot.

## Repository Size

Keep the effect source and compact game atlas in version control.
The parent repository stores a reference to PixelFX, rather than a copy of its files or history.
Its checkout is downloaded only when the submodule is initialized.
`external/.gdignore` excludes generation dependencies from Godot imports and exports.
Preview files stay under ignored `tmp/`.

## License

PixelFX is MIT licensed. Its license is retained in [`tools/fx/PIXELFX_LICENSE.txt`](../tools/fx/PIXELFX_LICENSE.txt).
