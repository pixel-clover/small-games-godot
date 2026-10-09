class_name ForestArt
extends RefCounted

## Procedural pixel-art generator for the forest walk. Every sprite is painted
## pixel by pixel into an Image (palette-limited, hand-shaded look), so the
## project needs no art assets.

const LEAF := [Color("1c3f2a"), Color("2b6034"), Color("46853b"), Color("78ad4a"), Color("b3d467")]
const BARK := [Color("231811"), Color("3a2819"), Color("57402c"), Color("7b5c42")]


# ---------------------------------------------------------------- helpers

static func _new_img(w: int, h: int) -> Image:
    return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func _rng(seed_: int) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = seed_
    return r


static func _px(img: Image, x: int, y: int, c: Color) -> void:
    if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
        img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            _px(img, xx, yy, c)


static func _line(img: Image, x0: float, y0: float, x1: float, y1: float, c: Color,
    thick: int=1) -> void:
    var steps := int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
    for i in range(steps + 1):
        var u := float(i) / steps
        _rect(img, int(lerpf(x0, x1, u)), int(lerpf(y0, y1, u)), thick, thick, c)


static func _tones(hue_shift: float, bright: float, sat: float=1.0) -> Array:
    var out: Array = []
    for c: Color in LEAF:
        out.append(Color.from_hsv(fposmod(c.h + hue_shift, 1.0), clampf(c.s * sat, 0.0, 1.0),
            clampf(c.v * bright, 0.0, 1.0)))
    return out


## Shaded leafy ellipse: light from the top-left, ragged edge, noisy shading.
static func _blob(img: Image, cx: float, cy: float, rx: float, ry: float, tones: Array,
    rng: RandomNumberGenerator) -> void:
    var n := tones.size()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            var dx := (x - cx) / rx
            var dy := (y - cy) / ry
            var d := dx * dx + dy * dy
            var limit := 1.0
            if d > 0.55:
                limit -= rng.randf() * 0.2
            if d < limit:
                var shade := 0.58 - dx * 0.3 - dy * 0.5 + (rng.randf() - 0.5) * 0.3
                _px(img, x, y, tones[clampi(int(shade * n), 0, n - 1)])


static func _trunk(img: Image, cx: float, y_top: int, y_bot: int, w_top: float, w_bot: float,
    tones: Array, rng: RandomNumberGenerator, moss: bool, moss_tones: Array) -> void:
    var h := float(y_bot - y_top)
    for y in range(y_top, y_bot + 1):
        var t := float(y - y_top) / maxf(h, 1.0)
        var w := lerpf(w_top, w_bot, t * t * t)  # root flare
        var x0 := int(round(cx - w / 2.0 + sin(y * 0.07) * 0.8))
        var wi := maxi(int(round(w)), 2)
        for i in wi:
            var u := float(i) / maxf(wi - 1.0, 1.0)
            var idx := 0
            if u < 0.2:
                idx = 3
            elif u < 0.5:
                idx = 2
            elif u < 0.8:
                idx = 1
            if rng.randf() < 0.07:
                idx = clampi(idx - 1, 0, 3)
            var c: Color = tones[idx]
            if moss and t > 0.45 and u < 0.55 and rng.randf() < 0.3 * t:
                c = moss_tones[clampi(1 + int(rng.randf() * 3.0), 0, 4)]
            _px(img, x0 + i, y, c)


## Turns an image into a grayscale haze mask (tinted later with modulate) for distant trees.
static func _to_haze(img: Image) -> void:
    for y in img.get_height():
        for x in img.get_width():
            var c := img.get_pixel(x, y)
            if c.a > 0.0:
                var g := 0.66 + c.get_luminance() * 0.6
                img.set_pixel(x, y, Color(g, g, g, 1.0))


static func _finish(img: Image, haze: bool) -> ImageTexture:
    if haze:
        _to_haze(img)
    return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ trees

static func oak(w: int, h: int, seed_: int, haze: bool=false) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    var cx := w / 2.0
    var tones := _tones(rng.randf_range(-0.03, 0.04), rng.randf_range(0.9, 1.1))
    var ccy := h * 0.34
    var tw := maxf(3.0, w * 0.075)
    _trunk(img, cx, int(ccy), h - 1, tw * 0.75, tw * 1.7, BARK, rng, true, tones)
    for k in 2:
        var sgn := -1.0 if k == 0 else 1.0
        _line(img, cx, ccy + h * 0.12 + k * 8.0, cx + sgn * w * 0.2, ccy - h * 0.02, BARK[2],
            maxi(1, int(tw * 0.3)))
    var blobs: Array = []
    for i in 11:
        blobs.append(
            Vector3(cx + (rng.randf() - 0.5) * w * 0.5, ccy + (rng.randf() - 0.5) * h * 0.34,
                w * rng.randf_range(0.12, 0.19)))
    blobs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
    for b: Vector3 in blobs:
        _blob(img, b.x, b.y, b.z, b.z * 0.85, tones, rng)
    return _finish(img, haze)


static func pine(w: int, h: int, seed_: int, haze: bool=false) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    var cx := w / 2.0
    var tones := _tones(0.05 + rng.randf_range(-0.02, 0.02), rng.randf_range(0.7, 0.9), 0.95)
    _trunk(img, cx, int(h * 0.55), h - 1, maxf(2.0, w * 0.05), maxf(3.0, w * 0.1), BARK, rng, false,
        tones)
    var tiers := 6
    for i in tiers:
        var top := h * 0.04 + h * 0.72 * float(i) / tiers
        var th := h * 0.72 / tiers * 1.9
        var tw := lerpf(w * 0.35, w * 0.92, float(i + 1) / tiers)
        for y in range(int(top), int(top + th)):
            var t := (y - top) / th
            var half := tw * 0.5 * t + 1.0 + sin(y * 1.9 + i) * 0.9
            var x0 := int(cx - half)
            var x1 := int(cx + half)
            for x in range(x0, x1 + 1):
                if t > 0.88 and rng.randf() < (t - 0.88) * 6.0:
                    continue
                var u := float(x - x0) / maxf(float(x1 - x0), 1.0)
                var shade := 0.85 - u * 0.65 + (1.0 - t) * 0.1 - t * 0.12 + (rng.randf() - 0.5) * 0.3
                _px(img, x, y, tones[clampi(int(shade * 5.0), 0, 4)])
    return _finish(img, haze)


static func birch(w: int, h: int, seed_: int, haze: bool=false) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    var cx := w / 2.0
    var tones := _tones(-0.04, 1.15, 0.9)
    var white := [Color("5d5a52"), Color("8f8b80"), Color("c8c4b8"), Color("e6e2d6")]
    var tw := maxf(2.0, w * 0.05)
    _trunk(img, cx, int(h * 0.3), h - 1, tw, tw * 1.4, white, rng, false, tones)
    var y := int(h * 0.36)
    while y < h - 3:
        _rect(img, int(cx - tw / 2.0 + rng.randf() * tw * 0.5), y,
            rng.randi_range(1, maxi(1, int(tw * 0.6))), 1, Color("2b2824"))
        y += rng.randi_range(3, 7)
    var blobs: Array = []
    for i in 9:
        blobs.append(
            Vector3(cx + (rng.randf() - 0.5) * w * 0.55, h * 0.3 + (rng.randf() - 0.5) * h * 0.3,
                w * rng.randf_range(0.09, 0.15)))
    blobs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
    for b: Vector3 in blobs:
        _blob(img, b.x, b.y, b.z, b.z * 0.9, tones, rng)
    return _finish(img, haze)


## Builds `count` trees mixing oaks, pines and birches.
static func tree_set(count: int, w: int, h: int, seed_: int, haze: bool) -> Array:
    var out: Array = []
    var kinds := ["oak", "pine", "oak", "birch", "pine", "oak"]
    for i in count:
        var ww := w + (i % 3) * 6
        var hh := h + ((i * 7) % 5) * 4
        match kinds[i % kinds.size()]:
            "oak":
                out.append(oak(ww, hh, seed_ + i * 31, haze))
            "pine":
                out.append(pine(ww - 10, hh, seed_ + i * 31, haze))
            _:
                out.append(birch(ww - 20, hh, seed_ + i * 31, haze))
    return out


# ----------------------------------------------------------------- ground

static func ground_tile(w: int=128, rows: int=66) -> ImageTexture:
    var rng := _rng(4242)
    var img := _new_img(w, rows)
    var greens := [Color("5a9a42"), Color("457f3a"), Color("336a35"), Color("27522f"),
        Color("1d3d2a")]
    var blade_rows := 6
    for y in range(blade_rows, rows):
        var t := float(y - blade_rows) / (rows - blade_rows)
        for x in w:
            var tt := clampf(t + (rng.randf() - 0.5) * 0.25, 0.0, 0.999)
            _px(img, x, y, greens[int(tt * greens.size())])
    # lighter moss clumps (drawn three times so the tile wraps seamlessly)
    var clump := [greens[2], greens[1], greens[0], LEAF[3]]
    for i in 14:
        var bx := rng.randf() * w
        var by := rng.randf_range(blade_rows + 6, rows - 6)
        var rx := rng.randf_range(6.0, 12.0)
        var ry := rng.randf_range(2.5, 5.0)
        for ox in [-w, 0, w]:
            _blob(img, bx + ox, by, rx, ry, clump, rng)
    # leaf litter and soil specks
    for i in 110:
        var c: Color = BARK[1 + rng.randi() % 2] if rng.randf() < 0.6 else LEAF[1 + rng.randi() % 3]
        _rect(img, rng.randi() % w, rng.randi_range(blade_rows + 2, rows - 1),
            rng.randi_range(1, 2), 1, c)
    # grass blades along the top edge
    for x in w:
        if rng.randf() < 0.85:
            var bh := rng.randi_range(2, blade_rows)
            for k in bh:
                var c: Color = greens[0] if k < bh - 1 else LEAF[3]
                if rng.randf() < 0.15:
                    c = LEAF[4]
                _px(img, x, blade_rows - k, c)
    return ImageTexture.create_from_image(img)


# ------------------------------------------------------------- undergrowth

static func bush(w: int, h: int, seed_: int, flowering: bool=false) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    var tones := _tones(rng.randf_range(-0.03, 0.04), rng.randf_range(0.85, 1.05))
    var blobs: Array = []
    for i in 6:
        var rx := w * rng.randf_range(0.2, 0.32)
        var ry := minf(rx * 0.9, (h - 3.0) * 0.5)
        blobs.append(Vector3(rng.randf_range(rx + 1.0, w - rx - 2.0),
            rng.randf_range(ry + 1.0, h - ry - 2.0), rx))
    blobs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
    for b: Vector3 in blobs:
        _blob(img, b.x, b.y, b.z, minf(b.z * 0.9, (h - 3.0) * 0.5), tones, rng)
    if flowering:
        var col: Color = [Color("f4c2d7"), Color("fff4f0"), Color("f7e27a")][rng.randi() % 3]
        for i in 14:
            var x := rng.randi() % w
            var y := rng.randi_range(0, int(h * 0.7))
            if img.get_pixel(x, y).a > 0.0:
                _px(img, x, y, col)
                _px(img, x + 1, y, col.darkened(0.15))
    return ImageTexture.create_from_image(img)


static func fern(w: int, h: int, seed_: int, fronds: int=9) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    var tones := _tones(rng.randf_range(-0.02, 0.03), 1.0)
    var width_scale := minf(1.0, (w / 2.0 - 3.0) / (h * 1.04))
    for i in fronds:
        var ang := lerpf(-1.2, 1.2, (i + 0.5) / fronds) + rng.randf_range(-0.12, 0.12)
        var length := h * rng.randf_range(0.7, 1.0) * (1.0 - absf(ang) * 0.2)
        var steps := int(length * 1.6)
        var pos := Vector2(w / 2.0, h - 1.0)
        for s in steps:
            var t := float(s) / steps
            var a := ang + signf(ang) * t * 0.95
            pos += Vector2(sin(a) * width_scale, -cos(a)) * 0.65
            var idx := clampi(int(1.0 + t * 3.2 + (rng.randf() - 0.5)), 0, 4)
            _px(img, int(pos.x), int(pos.y), tones[idx])
            if s % 2 == 0 and t > 0.1:
                var perp := Vector2(cos(a) * width_scale, sin(a))
                var lc: Color = tones[clampi(idx - 1, 0, 4)]
                _px(img, int(pos.x + perp.x * 1.5), int(pos.y + perp.y * 1.5 + 1.0), lc)
                _px(img, int(pos.x - perp.x * 1.5), int(pos.y - perp.y * 1.5 + 1.0), lc)
    return ImageTexture.create_from_image(img)


static func flower(color: Color, seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(9, 15)
    var hgt := rng.randi_range(8, 12)
    for y in range(15 - hgt, 15):
        _px(img, 4, y, LEAF[2])
    _px(img, 3, 11, LEAF[3])
    _px(img, 2, 10, LEAF[3])
    _px(img, 5, 12, LEAF[3])
    _px(img, 6, 11, LEAF[3])
    var hy := 15 - hgt
    for p in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, -1),
        Vector2i(1, -1)]:
        _px(img, 4 + p.x, hy + p.y, color if p.y <= 0 else color.darkened(0.2))
    _px(img, 4, hy, Color("ffd84a"))
    return ImageTexture.create_from_image(img)


static func mushroom(cap: Color, seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(10, 10)
    for y in range(5, 10):
        _rect(img, 4, y, 2, 1, Color("e8dcc0") if y < 8 else Color("c8b898"))
    for y in range(1, 6):
        var half: int = [1, 3, 4, 4, 4][y - 1]
        for x in range(5 - half, 5 + half):
            var c := cap
            if x >= 5 + half - 2:
                c = cap.darkened(0.25)
            elif y == 1 or x < 5 - half + 1:
                c = cap.lightened(0.15)
            _px(img, x, y, c)
    for i in 3:
        _px(img, rng.randi_range(3, 6), rng.randi_range(2, 4), Color("fff6e8"))
    return ImageTexture.create_from_image(img)


static func rock(w: int, h: int, seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    var stone := [Color("3f4247"), Color("62666c"), Color("848990"), Color("a9aeb4")]
    _blob(img, w * 0.5, h * 0.62, w * 0.46, h * 0.42, stone, rng)
    _blob(img, w * 0.32, h * 0.7, w * 0.28, h * 0.3, stone, rng)
    var moss := _tones(0.0, 1.0)
    for y in int(h * 0.55):
        for x in w:
            if img.get_pixel(x, y).a > 0.0 and rng.randf() < 0.65 * (1.0 - y / (h * 0.55)):
                _px(img, x, y, moss[clampi(1 + rng.randi() % 3, 0, 4)])
    return ImageTexture.create_from_image(img)


static func tuft(w: int, h: int, seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    var tones := _tones(rng.randf_range(-0.02, 0.05), 1.05)
    var blades := rng.randi_range(5, 9)
    for i in blades:
        var bx := w / 2.0 + (i - blades / 2.0) * (w / float(blades + 1))
        var lean := rng.randf_range(-0.5, 0.5)
        var bh := h * rng.randf_range(0.5, 1.0)
        for k in int(bh):
            var t := k / bh
            _px(img, int(bx + lean * t * t * bh * 0.5), h - 1 - k,
                tones[clampi(int(1.0 + t * 3.5), 0, 4)])
    return ImageTexture.create_from_image(img)


static func log_tex(seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var w := 46
    var h := 15
    var img := _new_img(w, h)
    for y in range(2, h - 1):
        var t := float(y - 2) / (h - 3)
        var idx := 3 if t < 0.25 else (2 if t < 0.55 else (1 if t < 0.85 else 0))
        for x in range(5, w - 2):
            var c: Color = BARK[idx]
            if rng.randf() < 0.08:
                c = BARK[clampi(idx - 1, 0, 3)]
            _px(img, x, y, c)
    # cut end with rings
    _blob(img, 6.0, h / 2.0 + 0.5, 5.0, h / 2.0 - 1.0,
        [Color("a07850"), Color("c49a6a"), Color("dcb884")], rng)
    for p in [Vector2i(6, 7), Vector2i(5, 6), Vector2i(7, 8)]:
        _px(img, p.x, p.y, Color("8a6440"))
    var moss := _tones(0.0, 1.0)
    for x in range(12, w - 2):
        if rng.randf() < 0.45:
            _px(img, x, 2, moss[2 + rng.randi() % 3])
            if rng.randf() < 0.4:
                _px(img, x, 3, moss[1 + rng.randi() % 2])
    return ImageTexture.create_from_image(img)


# ------------------------------------------------------------ foreground

## Dark hanging canopy used as a close-up occluder at the top of the screen.
static func hanging_leaves(w: int, h: int, seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    var tones := _tones(0.0, 0.7)
    var blobs: Array = []
    for i in 14:
        var y := rng.randf_range(0.0, h * 0.55) * (1.0 - absf(i / 14.0 - 0.5) * 0.9)
        var radius := rng.randf_range(w * 0.08, w * 0.16)
        blobs.append(Vector3(rng.randf_range(radius + 1.0, w - radius - 2.0), y, radius))
    blobs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
    for b: Vector3 in blobs:
        _blob(img, b.x, b.y, b.z, b.z * 0.8, tones, rng)
    return ImageTexture.create_from_image(img)


static func vignette(w: int, h: int) -> ImageTexture:
    var img := _new_img(w, h)
    var bayer := [0.0, 0.5, 0.75, 0.25]
    for y in h:
        for x in w:
            var nx := (x - w / 2.0) / (w / 2.0)
            var ny := (y - h / 2.0) / (h / 2.0)
            var d := sqrt(nx * nx * 0.75 + ny * ny)
            var a := pow(clampf((d - 0.55) / 0.75, 0.0, 1.0), 1.7) * 0.62
            a = floorf(a / 0.08 + bayer[(x & 1) + (y & 1) * 2]) * 0.08  # ordered dithering
            img.set_pixel(x, y, Color(0.02, 0.04, 0.06, clampf(a, 0.0, 0.7)))
    return ImageTexture.create_from_image(img)


# ----------------------------------------------------------------- player

static func _rect_i(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
    _rect(img, x, y, w, h, c)


## Returns [right_frames, left_frames]; frame 0 is idle, 1-4 the walk cycle.
static func player_frames() -> Array:
    var cloak := [Color("17301f"), Color("24492e"), Color("356b3f"), Color("4f8d52")]
    var skin := Color("e9b98f")
    var skin_d := Color("c98f6a")
    var trousers := Color("4a3626")
    var boots := Color("20150f")
    var right: Array = []
    var left: Array = []
    for f in 5:
        var img := _new_img(16, 24)
        var bob := 0
        var la := 0
        var lift_a := 0
        var lift_b := 0
        if f > 0:
            var ph := f - 1
            la = [2, 0, -2, 0][ph]
            bob = [0, -1, 0, -1][ph]
            lift_a = [0, 1, 0, 0][ph]
            lift_b = [0, 0, 0, 1][ph]
        var lb := -la
        # back leg
        _rect(img, 6 + lb, 17 + bob + lift_b, 2, 7 - lift_b - bob, trousers.darkened(0.25))
        _rect(img, 6 + lb, 22 - lift_b, 3, 2, boots.lightened(0.0))
        # cloak (trapezoid) with hem swaying against the stride
        for y in range(8, 19):
            var t := (y - 8) / 10.0
            var wd := int(round(lerpf(6.0, 10.0, t)))
            var sway := int(round(-la * 0.4 * t))
            var x0 := 8 - wd / 2 + sway
            for i in wd:
                var u := float(i) / (wd - 1)
                var c: Color = cloak[0] if u < 0.25 else (cloak[1] if u < 0.6 else cloak[2])
                if y == 18:
                    c = cloak[0]
                _px(img, x0 + i, y + bob, c)
        _rect(img, 5, 13 + bob, 7, 1, Color("5a4030"))  # belt
        _px(img, 8, 13 + bob, Color("d9b25a"))
        # front leg
        _rect(img, 8 + la, 17 + bob + lift_a, 2, 7 - lift_a - bob, trousers)
        _rect(img, 8 + la, 22 - lift_a, 3, 2, boots)
        # arm holding the lantern
        _rect(img, 9, 10 + bob, 2, 4, cloak[2])
        _px(img, 10, 14 + bob, skin)
        _px(img, 9, 14 + bob, skin_d)
        # hood and face
        _rect(img, 5, 2 + bob, 8, 7, cloak[1])
        _rect(img, 6, 2 + bob, 6, 1, cloak[3])
        _rect(img, 5, 3 + bob, 2, 6, cloak[0])
        _px(img, 4, 6 + bob, cloak[0])
        _px(img, 4, 7 + bob, cloak[0])
        _rect(img, 9, 4 + bob, 3, 4, skin)
        _rect(img, 9, 7 + bob, 3, 1, skin_d)
        _px(img, 10, 5 + bob, Color("2a1a14"))
        _px(img, 9, 3 + bob, Color("6b4423"))
        _px(img, 10, 3 + bob, Color("6b4423"))
        right.append(ImageTexture.create_from_image(img))
        var flipped := img.duplicate() as Image
        flipped.flip_x()
        left.append(ImageTexture.create_from_image(flipped))
    return [right, left]


# ------------------------------------------------- discoverables & biome props

const STONE := [Color("3a3d44"), Color("5c6068"), Color("7f848c"), Color("a2a8b0")]


static func _shade_stone(shade: float, rng: RandomNumberGenerator) -> Color:
    return STONE[clampi(int((shade + (rng.randf() - 0.5) * 0.3) * 4.0), 0, 3)]


static func _moss_over(img: Image, rng: RandomNumberGenerator, amount: float) -> void:
    var m: Array = _tones(0.0, 1.0)
    var h := img.get_height()
    for y in h:
        for x in img.get_width():
            if img.get_pixel(x, y).a > 0.0 and rng.randf() < amount * (1.0 - float(y) / h):
                img.set_pixel(x, y, m[1 + rng.randi() % 3])


static func pillar(w: int, h: int, broken: bool, seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(w, h)
    for x in w:
        var cut := 0
        if broken:
            cut = rng.randi_range(0, 3) + (3 if x > w / 2 else 0)
        for y in range(cut, h):
            var shade := 0.95 - float(x) / (w - 1) * 0.75 + (0.15 if y == cut else 0.0)
            _px(img, x, y, _shade_stone(shade, rng))
    if not broken:
        for x in w:
            _px(img, x, 3, STONE[0])
    for i in 3:
        var cx := rng.randi_range(1, w - 2)
        var cy := rng.randi_range(5, maxi(6, h - 5))
        _line(img, cx, cy, cx + rng.randi_range(-1, 1), cy + rng.randi_range(3, 6), STONE[0])
    _moss_over(img, rng, 0.35)
    return ImageTexture.create_from_image(img)


static func arch(seed_: int=3) -> ImageTexture:
    var rng := _rng(seed_)
    var w := 52
    var h := 46
    var img := _new_img(w, h)
    var cx := w / 2.0
    var cy := 22.0
    var ro := w / 2.0 - 2.0
    var ri := ro - 9.0
    for y in h:
        for x in w:
            var dx := x + 0.5 - cx
            var d := sqrt(dx * dx + (y - cy) * (y - cy))
            var inside := false
            if y <= cy:
                inside = d >= ri and d <= ro
            else:
                inside = absf(dx) >= ri and absf(dx) <= ro
            if inside and not (x > w - 14 and y < 12 and rng.randf() < 0.6):
                var shade := 0.8 - float(x) / w * 0.5 - (d - ri) / (ro - ri) * 0.1
                _px(img, x, y, _shade_stone(shade, rng))
    for i in 5:
        var px := rng.randi_range(2, w - 3)
        var py := rng.randi_range(4, h - 6)
        if img.get_pixel(px, py).a > 0.0:
            _line(img, px, py, px + rng.randi_range(-1, 1), py + rng.randi_range(2, 5), STONE[0])
    _moss_over(img, rng, 0.45)
    return ImageTexture.create_from_image(img)


## Tall carved monolith with a faintly glowing rune.
static func standing_stone(seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var w := 16
    var h := 34
    var img := _new_img(w, h)
    for y in h:
        var t := float(y) / h
        var half := lerpf(3.6, 6.8, t)
        if y < 5:
            half = lerpf(1.5, 3.6, float(y) / 5.0)
        var x0 := int(round(w / 2.0 - half))
        var x1 := int(round(w / 2.0 + half))
        for x in range(x0, x1):
            var u := float(x - x0) / maxf(x1 - x0 - 1, 1)
            _px(img, x, y, _shade_stone(0.95 - u * 0.75 - t * 0.1, rng))
    _moss_over(img, rng, 0.25)
    var rune := Color("7fe8d0")
    for y in range(9, 24):
        _px(img, 8, y, rune)
    for p in [Vector2i(7, 12), Vector2i(9, 12), Vector2i(6, 15), Vector2i(10, 15), Vector2i(7, 10),
        Vector2i(9, 10), Vector2i(7, 20), Vector2i(9, 20)]:
        _px(img, p.x, p.y, rune.darkened(0.15))
    return ImageTexture.create_from_image(img)


static func glow_mushroom(seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(14, 11)
    var caps := [Color("1f8f95"), Color("2fb6b0"), Color("5fe0cc"), Color("b8fff0")]
    for m in [[4, 6, 4], [10, 8, 3]]:
        var cx: int = m[0]
        var cy: int = m[1]
        var r: int = m[2]
        for y in range(cy, 11):
            _px(img, cx, y, Color("c4e8e0"))
        for y in range(cy - r + 1, cy + 1):
            var q := float(cy - y) / r
            var half := int(r * sqrt(1.0 - q * q) + 0.5)
            for x in range(cx - half, cx + half + 1):
                var c: Color = caps[1]
                if x <= cx - half + 1 or y == cy - r + 1:
                    c = caps[2]
                elif x >= cx + half - 1:
                    c = caps[0]
                _px(img, x, y, c)
        for i in 2:
            _px(img, cx + rng.randi_range(-1, 1), cy - rng.randi_range(0, r - 1), caps[3])
    return ImageTexture.create_from_image(img)


static func moonbloom(open: bool) -> ImageTexture:
    var img := _new_img(15 if open else 9, 17 if open else 14)
    var mx := 7 if open else 4
    var top := 8 if open else 6
    for y in range(top, img.get_height()):
        _px(img, mx, y, LEAF[2])
    _px(img, mx - 1, img.get_height() - 4, LEAF[3])
    _px(img, mx - 2, img.get_height() - 5, LEAF[3])
    _px(img, mx + 1, img.get_height() - 3, LEAF[3])
    _px(img, mx + 2, img.get_height() - 4, LEAF[3])
    var pet := Color("d6ccff")
    var pet_d := Color("a090e0")
    if open:
        for a in [-2.2, -1.5, -0.8, 0.0, 0.8, 1.5, 2.2]:
            var dir := Vector2(sin(a), -cos(a))
            _line(img, mx, 6, mx + int(round(dir.x * 5.0)), 6 + int(round(dir.y * 5.0)),
                pet if absf(a) < 1.6 else pet_d)
        _rect(img, mx - 1, 5, 3, 2, Color("fff4b8"))
    else:
        _rect(img, mx - 1, 3, 3, 4, pet_d)
        _px(img, mx, 2, pet)
        _px(img, mx, 3, pet)
        _px(img, mx, 4, pet)
    return ImageTexture.create_from_image(img)


static func lamp_moss(seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(12, 10)
    var n := 7
    for i in n:
        var bx := 1 + i * 10 / n + rng.randi_range(0, 1)
        var bh := rng.randi_range(4, 9)
        var lean := rng.randf_range(-0.4, 0.4)
        for k in bh:
            var t := float(k) / bh
            var c := Color("1d6b6a").lerp(Color("5fe8d0"), t)
            if k == bh - 1:
                c = Color("d8fff4")
            _px(img, int(bx + lean * k), 9 - k, c)
    return ImageTexture.create_from_image(img)


static func reed(h: int, seed_: int) -> ImageTexture:
    var rng := _rng(seed_)
    var img := _new_img(14, h)
    var g := [Color("2a4a2a"), Color("46703a"), Color("6f9a4a")]
    for i in 4:
        var bx := 2 + i * 3 + rng.randi_range(-1, 1)
        var bh := h - rng.randi_range(0, 8)
        var lean := rng.randf_range(-0.12, 0.12)
        for k in bh:
            _px(img, int(bx + lean * k), h - 1 - k, g[(k / 5 + i) % 3])
        if i % 2 == 0:
            var hx := int(bx + lean * bh)
            _rect(img, hx, h - bh - 1, 2, 5, Color("5a3a22"))
            _px(img, hx, h - bh - 2, Color("3a2616"))
    return ImageTexture.create_from_image(img)


## Returns [right_frames, left_frames]; 0 = standing/watching, 1-2 = trot.
static func fox_frames() -> Array:
    var o := Color("e0782f")
    var d := Color("a84a1c")
    var w := Color("f6ecd8")
    var k := Color("2a1a14")
    var right: Array = []
    var left: Array = []
    for f in 3:
        var img := _new_img(20, 13)
        var hy := 2 if f == 0 else 3
        # tail
        _rect(img, 1, 5 if f != 0 else 6, 5, 3, o)
        _rect(img, 0, 6 if f != 0 else 7, 2, 3, w)
        # body
        _rect(img, 5, 5, 9, 4, o)
        _rect(img, 5, 8, 9, 1, d)
        _rect(img, 6, 5, 7, 1, Color("ee9050"))
        _rect(img, 12, 7, 2, 2, w)
        # head
        _rect(img, 13, hy + 1, 5, 4, o)
        _rect(img, 17, hy + 3, 3, 2, w)
        _px(img, 19, hy + 3, k)
        _rect(img, 14, hy + 4, 3, 1, w)
        _px(img, 16, hy + 2, k)
        _rect(img, 13, hy - 1, 1, 2, o)
        _rect(img, 16, hy - 1, 1, 2, o)
        _px(img, 13, hy - 1, k)
        _px(img, 16, hy - 1, k)
        # legs
        var legs := [[6, 3], [7, 3], [12, 3], [13, 3]]
        if f == 1:
            legs = [[5, 3], [8, 2], [13, 3], [11, 2]]
        elif f == 2:
            legs = [[7, 3], [5, 2], [11, 3], [13, 2]]
        for l in legs:
            _rect(img, int(l[0]), 9, 1, int(l[1]), k)
        right.append(ImageTexture.create_from_image(img))
        var fl := img.duplicate() as Image
        fl.flip_x()
        left.append(ImageTexture.create_from_image(fl))
    return [right, left]


## Small songbird facing right: [perched, wings up, wings down].
static func bird_frames(col: Color) -> Array:
    var out: Array = []
    var dk := col.darkened(0.35)
    for f in 3:
        var img := _new_img(9, 7)
        _rect(img, 2, 3, 4, 2, col)
        _rect(img, 5, 2, 2, 2, col.lightened(0.1))
        _px(img, 7, 3, Color("e8b040"))
        _px(img, 6, 2, Color("1a1a1a"))
        _rect(img, 0, 3, 2, 1, dk)
        _rect(img, 3, 5, 3, 1, col.lightened(0.5))
        if f == 0:
            _px(img, 3, 6, dk)
            _px(img, 4, 6, dk)
        elif f == 1:
            _rect(img, 3, 0, 2, 3, dk)
            _px(img, 2, 1, dk)
        else:
            _rect(img, 3, 5, 3, 2, dk)
            _px(img, 2, 6, dk)
        out.append(ImageTexture.create_from_image(img))
    return out
