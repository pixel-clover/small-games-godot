// Usage: node tools/generate_invaders_fx.mjs [/path/to/pixelfx]
import { mkdirSync, writeFileSync } from "node:fs";
import assert from "node:assert/strict";
import { resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import * as mod from "./fx/invader-burst.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const pixelfx = process.argv[2] ?? resolve(root, "external/pixelfx");
const { renderFrames, contactSheet, spriteSheet } = await import(
  pathToFileURL(resolve(pixelfx, "tools/lib/fxlib.mjs")).href
);
const fx = { id: "custom/invader-burst", meta: mod.meta, mod };
const rendered = renderFrames(fx);
const sheet = spriteSheet(fx, rendered, "invader-burst");
assert.equal(rendered.n, 10);
assert.equal(sheet.json.meta.pixelfx.columns, 4);
assert(rendered.frames[0].clear.some((value, i) => i % 4 === 3 && value > 0));
assert(rendered.frames.at(-1).clear.every((value) => value === 0));
assert(sheet.png.length < 16 * 1024, "Keep the burst sheet below 16 KiB.");
assert.deepEqual(sheet.png, spriteSheet(fx, renderFrames(fx), "invader-burst").png);
const assets = resolve(root, "common/effects");
const previews = resolve(root, "tmp/fx-preview");
mkdirSync(assets, { recursive: true });
mkdirSync(previews, { recursive: true });
writeFileSync(resolve(root, "tmp/.gdignore"), "");
writeFileSync(resolve(assets, "invader-burst.png"), sheet.png);
writeFileSync(resolve(previews, "contact.png"), contactSheet(fx, rendered, { zoom: 4 }));
console.log(`${rendered.n} frames, ${sheet.json.meta.pixelfx.columns} columns, ${sheet.png.length} bytes`);
