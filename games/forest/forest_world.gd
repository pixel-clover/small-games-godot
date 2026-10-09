extends Node2D

## The forest world: parallax layers, endless chunked undergrowth, day/night cycle,
## fireflies, light shafts and ambient audio. Rendered at 320x180 and scaled up by the root.
## On top of that: biomes, discoverable things + journal, lantern fuel and a reactive world.

const VW := 320
const VH := 180
const GROUND_TOP := 120
const Y_MIN := 136.0
const Y_MAX := 172.0
const CHUNK := 96
const DAY_LENGTH := 300.0
const BIOME_W := 750.0

# Things the player can discover (shown in the journal in this order).
const TYPES := [
    {"id": "glowmush", "name": "Glowcap", "text": "Tiny lamps that sip the moonlight.",
        "hint": "Look in damp, dark places."},
    {"id": "moonbloom", "name": "Moonbloom", "text": "Opens its petals for lantern light at night.",
        "hint": "Blooms at night, near your lantern."},
    {"id": "fox", "name": "Red Fox", "text": "Watches quietly, then trots away.",
        "hint": "Shy, and keeps among the trees."},
    {"id": "shrine", "name": "Standing Stone", "text": "Someone carved a rune here long ago.",
        "hint": "Often found among old ruins."},
    {"id": "pond", "name": "Still Pond", "text": "Holds the sky, and every ripple.",
        "hint": "Follow the mist to find water."},
    {"id": "glade", "name": "Hidden Glade", "text": "An open gap where the light pools gently.",
        "hint": "Look for a gap in the trees."},
]

# Biomes along the x axis.
const BIOMES := [
    {"name": "Birch Grove", "tint": Color(1.08, 1.06, 0.92), "fog": 0.02},
    {"name": "Pine Forest", "tint": Color(0.78, 0.9, 0.92), "fog": 0.08},
    {"name": "Misty Bog", "tint": Color(0.8, 0.96, 0.92), "fog": 0.4},
    {"name": "Old Ruins", "tint": Color(0.93, 0.93, 1.0), "fog": 0.06},
    {"name": "Flower Meadow", "tint": Color(1.12, 1.08, 0.95), "fog": 0.0},
]

# Per-biome generation: tree chances, [birch, pine] share (rest oak), counts and spawn chances per chunk.
const BIO_GEN := [
    {"tree1": 0.95, "tree2": 0.5, "tw": [0.8, 0.0], "bush": 2, "fern": [0, 1], "tuft": [4, 7],
        "flower": 0.45, "fgroups": 1,
        "mush": 0.15, "rock": 0.12, "log": 0.08, "glow": 0.06, "bloom": 0.1, "fox": 0.05,
        "shrine": 0.02, "pond": 0.06,
        "moss": 0.1, "reeds": 0, "puddle": 0.0, "arch": 0.0, "pillar": 0.0},
    {"tree1": 1.0, "tree2": 0.55, "tw": [0.0, 0.88], "bush": 1, "fern": [2, 4], "tuft": [3, 5],
        "flower": 0.1, "fgroups": 1,
        "mush": 0.25, "rock": 0.3, "log": 0.2, "glow": 0.12, "bloom": 0.05, "fox": 0.09,
        "shrine": 0.02, "pond": 0.06,
        "moss": 0.12, "reeds": 0, "puddle": 0.0, "arch": 0.0, "pillar": 0.0},
    {"tree1": 0.0, "tree2": 0.0, "tw": [0.0, 0.0], "bush": 0, "fern": [0, 1], "tuft": [2, 4],
        "flower": 0.0, "fgroups": 1,
        "mush": 0.8, "rock": 0.08, "log": 0.1, "glow": 0.35, "bloom": 0.05, "fox": 0.0,
        "shrine": 0.01, "pond": 0.22,
        "moss": 0.2, "reeds": 3, "puddle": 0.6, "arch": 0.0, "pillar": 0.0},
    {"tree1": 0.4, "tree2": 0.08, "tw": [0.0, 0.4], "bush": 1, "fern": [1, 2], "tuft": [3, 5],
        "flower": 0.15, "fgroups": 1,
        "mush": 0.2, "rock": 0.35, "log": 0.1, "glow": 0.06, "bloom": 0.06, "fox": 0.04,
        "shrine": 0.35, "pond": 0.03,
        "moss": 0.22, "reeds": 0, "puddle": 0.0, "arch": 0.35, "pillar": 0.7},
    {"tree1": 0.15, "tree2": 0.0, "tw": [0.3, 0.0], "bush": 1, "fern": [0, 0], "tuft": [6, 10],
        "flower": 0.95, "fgroups": 3,
        "mush": 0.05, "rock": 0.05, "log": 0.0, "glow": 0.04, "bloom": 0.3, "fox": 0.05,
        "shrine": 0.02, "pond": 0.1,
        "moss": 0.1, "reeds": 0, "puddle": 0.0, "arch": 0.0, "pillar": 0.0},
]

# Time-of-day keyframes (0 = dawn, ~0.3 = midday, ~0.58 = sunset, ~0.78 = night)
var keys := [
    {"t": 0.00, "top": Color("5a6fa8"), "bot": Color("f2b79a"), "amb": Color("ffd9c4"),
        "fog": Color("e8bba8"), "shaft": 0.5, "night": 0.2},
    {"t": 0.15, "top": Color("5fa8d8"), "bot": Color("cfe8d0"), "amb": Color("ffffff"),
        "fog": Color("b7d9cf"), "shaft": 1.0, "night": 0.0},
    {"t": 0.45, "top": Color("4f9fd6"), "bot": Color("d6ecd0"), "amb": Color("fffbea"),
        "fog": Color("bcdccb"), "shaft": 0.9, "night": 0.0},
    {"t": 0.58, "top": Color("6a5aa0"), "bot": Color("ff9b6a"), "amb": Color("ffb890"),
        "fog": Color("d89a8a"), "shaft": 0.7, "night": 0.2},
    {"t": 0.68, "top": Color("26305f"), "bot": Color("7a5a8a"), "amb": Color("8a90c0"),
        "fog": Color("4a4f80"), "shaft": 0.1, "night": 0.7},
    {"t": 0.78, "top": Color("0a1030"), "bot": Color("1a2a50"), "amb": Color("6478b0"),
        "fog": Color("1c2a50"), "shaft": 0.0, "night": 1.0},
    {"t": 0.92, "top": Color("0a1030"), "bot": Color("1a2a50"), "amb": Color("6478b0"),
        "fog": Color("1c2a50"), "shaft": 0.0, "night": 1.0},
    {"t": 1.00, "top": Color("5a6fa8"), "bot": Color("f2b79a"), "amb": Color("ffd9c4"),
        "fog": Color("e8bba8"), "shaft": 0.5, "night": 0.2},
]

var time_of_day := 0.2
var pal_top := Color.WHITE
var pal_bot := Color.WHITE
var amb := Color.WHITE
var fog := Color.WHITE
var shaft := 1.0
var night := 0.0

var t := 0.0
var ui_t := 0.0
var player_pos := Vector2(0, 152)
var vel := Vector2.ZERO
var facing := 1
var moving := false
var running := false
var anim_t := 0.0
var last_phase := -1
var cam_x := 0.0

# Biome blending
var bw := PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
var bio_tint := Color.WHITE
var fog_amt := 0.0
var cur_biome := -1
var title_t := 99.0
var title_text := ""

# Lantern
var fuel := 1.0
var glow_k := 1.0
var flick := 1.0
var lantern_offset := Vector2.ZERO
var lantern_velocity := Vector2.ZERO
var discovery_left := 0.0
var hud_alpha := 1.0
var journal_amount := 0.0

# State
var paused := false
var journal_open := false
var found_counts := {}
var found_ids := {}
var no_save := false
var toasts: Array = []
var sparks: Array = []
var puffs: Array = []
var fly_birds: Array = []
var vis_items: Array = []
var vis_flat: Array = []
var vis_special: Array = []
var player_item := {"player": true, "y": 0.0, "x": 0.0}

# Art
var far_trees: Array
var far_trees2: Array
var mid_trees: Array
var near_oak: Array
var near_pine: Array
var near_birch: Array
var hedges: Array
var bushes: Array
var ferns: Array
var flowers: Array
var flower_cols: Array
var mushrooms: Array
var rocks: Array
var tufts: Array
var logs: Array
var reeds: Array
var arches: Array
var pillars: Array
var stones: Array
var glow_mush: Array
var lamp_mosses: Array
var moon_bud: ImageTexture
var moon_open: ImageTexture
var fox_r: Array
var fox_l: Array
var bird_tex: Array
var ground_tile: ImageTexture
var fg_leaves: Array
var fg_ferns: Array
var player_r: Array
var player_l: Array

# Layers drawn on top of the world
var overlay: Node2D
var front: Node2D
var ui: Node2D
var chunks := {}

# Particles
var fireflies: Array = []
var dust: Array = []
var leaves: Array = []
var butterflies: Array = []

# Audio
var thread: Thread
var snd := {}
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_next := 0
var pad_players: Array[AudioStreamPlayer] = []
var wind_players: Array[AudioStreamPlayer] = []
var audio_weights := PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
var audio_from := PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
var audio_fade := 3.0
var landmark_player: AudioStreamPlayer2D
var breadcrumb_timer := 0.0
var cricket_player: AudioStreamPlayer
var bird_timer := 4.0
var pluck_timer := 6.0
var key_t_down := false
var key_j_down := false
var key_p_down := false

# Optional screenshot hook: godot ... -- --shot=/tmp/a.png --time=0.3 --x=500
# extras: --journal --paused --biome=N --spot=kind [--on] --fuel=0.1 --found=1 --shotframe=N
var shot_path := ""
var shot_frame := 40
var frames := 0
var arg_spot := ""
var arg_on := false
var arg_biome := -1


func _ready() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--shot="):
            shot_path = arg.substr(7)
            no_save = true
        elif arg.begins_with("--time="):
            time_of_day = float(arg.substr(7))
        elif arg.begins_with("--x="):
            player_pos.x = float(arg.substr(4))
        elif arg.begins_with("--shotframe="):
            shot_frame = int(arg.substr(12))
        elif arg == "--journal":
            journal_open = true
        elif arg == "--paused":
            paused = true
        elif arg.begins_with("--biome="):
            arg_biome = int(arg.substr(8))
        elif arg.begins_with("--spot="):
            arg_spot = arg.substr(7)
        elif arg == "--on":
            arg_on = true
        elif arg.begins_with("--fuel="):
            fuel = float(arg.substr(7))
        elif arg == "--found=1":
            no_save = true
            found_counts = {"glowmush": 3, "moonbloom": 1, "fox": 2, "pond": 1}
    if found_counts.is_empty():
        _load_found()
    _build_art()
    _build_particles()
    overlay = Node2D.new()
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    overlay.material = mat
    add_child(overlay)
    overlay.draw.connect(_draw_overlay)
    front = Node2D.new()
    add_child(front)
    front.draw.connect(_draw_front)
    var vig := Sprite2D.new()
    vig.texture = ForestArt.vignette(VW, VH)
    vig.centered = false
    add_child(vig)
    ui = Node2D.new()
    add_child(ui)
    ui.draw.connect(_draw_ui)
    if arg_biome >= 0:
        _goto_biome(arg_biome)
    if arg_spot != "":
        var p := _find_special(arg_spot)
        if p.x < 1.0e8:
            player_pos = Vector2(p.x if arg_on else p.x - 45.0, p.y if arg_on else p.y + 2.0)
    player_pos.y = clampf(player_pos.y, Y_MIN, Y_MAX)
    cam_x = player_pos.x
    _update_biome()
    _update_palette()
    _setup_audio()


func _exit_tree() -> void:
    if thread != null and thread.is_started():
        thread.wait_to_finish()
    for player in pad_players + wind_players + sfx_pool:
        player.stop()
        player.stream = null
    cricket_player.stop()
    cricket_player.stream = null
    landmark_player.stop()
    landmark_player.stream = null


func _build_art() -> void:
    far_trees = ForestArt.tree_set(5, 56, 100, 100, true)
    far_trees2 = ForestArt.tree_set(5, 64, 112, 200, true)
    mid_trees = ForestArt.tree_set(6, 84, 132, 300, false)
    for i in 3:
        near_oak.append(ForestArt.oak(124 + i * 8, 172 + i * 8, 400 + i))
        near_pine.append(ForestArt.pine(100 + i * 6, 180 + i * 6, 420 + i))
        near_birch.append(ForestArt.birch(104 + i * 6, 176 + i * 6, 440 + i))
    for i in 4:
        hedges.append(ForestArt.bush(40 + i * 4, 24, 500 + i))
        bushes.append(ForestArt.bush(26 + i * 3, 18, 600 + i, i % 2 == 0))
    for i in 3:
        ferns.append(ForestArt.fern(30 + i * 4, 20 + i * 2, 700 + i))
        rocks.append(ForestArt.rock(18 + i * 5, 12 + i * 2, 800 + i))
        logs.append(ForestArt.log_tex(900 + i))
    for i in 4:
        tufts.append(ForestArt.tuft(12, 9 + i * 2, 1000 + i))
    flower_cols = [Color("fff6f0"), Color("f4a6c8"), Color("f7d948"), Color("a58bf0"),
        Color("7fb4f5")]
    for i in flower_cols.size():
        flowers.append(ForestArt.flower(flower_cols[i], 1100 + i))
    mushrooms.append(ForestArt.mushroom(Color("d83a3a"), 1200))
    mushrooms.append(ForestArt.mushroom(Color("b8793e"), 1201))
    mushrooms.append(ForestArt.mushroom(Color("e8a53a"), 1202))
    ground_tile = ForestArt.ground_tile()
    for i in 3:
        fg_leaves.append(ForestArt.hanging_leaves(130, 46, 1300 + i))
        fg_ferns.append(ForestArt.fern(70, 46, 1400 + i, 11))
    var frames_pair := ForestArt.player_frames()
    player_r = frames_pair[0]
    player_l = frames_pair[1]
    # discoverables and biome props
    reeds = [ForestArt.reed(26, 1500), ForestArt.reed(32, 1501), ForestArt.reed(22, 1502)]
    arches = [ForestArt.arch(3)]
    pillars = [ForestArt.pillar(12, 36, false, 1600), ForestArt.pillar(12, 22, true, 1601),
        ForestArt.pillar(14, 14, true, 1602)]
    stones = [ForestArt.standing_stone(1700), ForestArt.standing_stone(1701)]
    glow_mush = [ForestArt.glow_mushroom(1800), ForestArt.glow_mushroom(1801)]
    lamp_mosses = [ForestArt.lamp_moss(1900), ForestArt.lamp_moss(1901), ForestArt.lamp_moss(1902)]
    moon_bud = ForestArt.moonbloom(false)
    moon_open = ForestArt.moonbloom(true)
    var fx := ForestArt.fox_frames()
    fox_r = fx[0]
    fox_l = fx[1]
    for c in [Color("8a6a4a"), Color("5a7fb0"), Color("b86a4a")]:
        bird_tex.append(ForestArt.bird_frames(c))


func _build_particles() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 77
    for i in 32:
        fireflies.append(
            {"x": rng.randf() * VW, "y": rng.randf_range(70, 172), "ph": rng.randf() * TAU,
                "sp": rng.randf_range(0.3, 0.9), "bs": rng.randf_range(0.8, 2.0)})
    for i in 36:
        dust.append({"x": rng.randf() * VW, "y": rng.randf() * 130.0, "ph": rng.randf() * TAU})
    var leaf_cols := [Color("78ad4a"), Color("b3d467"), Color("d8b23a"), Color("c4752f"),
        Color("46853b")]
    for i in 16:
        leaves.append(
            {"x": rng.randf() * VW, "y": rng.randf() * VH, "vx": rng.randf_range(2.0, 8.0),
                "vy": rng.randf_range(6.0, 14.0), "par": rng.randf_range(0.8, 1.3),
                "ph": rng.randf() * TAU,
                "c": leaf_cols[rng.randi() % leaf_cols.size()]})
    var bf_cols := [Color("fff2a0"), Color("ff9a3c"), Color("9ac8ff"), Color("ffffff")]
    for i in 6:
        butterflies.append(
            {"x": rng.randf() * VW, "y": rng.randf_range(100, 160), "ph": rng.randf() * TAU,
                "sp": rng.randf_range(0.4, 1.0), "c": bf_cols[rng.randi() % bf_cols.size()]})


# ------------------------------------------------------------- persistence

func _load_found() -> void:
    var fc: Variant = Save.get_value("forest", "counts", {})
    if fc is Dictionary:
        found_counts = (fc as Dictionary).duplicate()
    var ids: Variant = Save.get_value("forest", "ids", [])
    if ids is Array:
        for s in ids:
            found_ids[str(s)] = true


func _total_found() -> int:
    var n := 0
    for k in found_counts:
        n += int(found_counts[k])
    return n


func _types_found() -> int:
    var n := 0
    for ty: Dictionary in TYPES:
        if int(found_counts.get(ty["id"], 0)) > 0:
            n += 1
    return n


func _save_found() -> void:
    if no_save:
        return
    Save.set_value("forest", "counts", found_counts)
    Save.set_value("forest", "ids", found_ids.keys())
    Save.set_value("forest", "total", _total_found())
    Save.submit_score("forest", _total_found())


# ------------------------------------------------------------------- audio

func _setup_audio() -> void:
    for i in 6:
        var p := AudioStreamPlayer.new()
        add_child(p)
        sfx_pool.append(p)
    for i in BIOMES.size():
        var pad := AudioStreamPlayer.new()
        pad.volume_db = -80.0
        add_child(pad)
        pad_players.append(pad)
        var wind := AudioStreamPlayer.new()
        wind.volume_db = -80.0
        add_child(wind)
        wind_players.append(wind)
    landmark_player = AudioStreamPlayer2D.new()
    landmark_player.max_distance = 150.0
    landmark_player.attenuation = 1.5
    add_child(landmark_player)
    cricket_player = AudioStreamPlayer.new()
    cricket_player.volume_db = -60.0
    add_child(cricket_player)
    thread = Thread.new()
    thread.start(_build_audio)


func _build_audio() -> void:
    var winds: Array[AudioStreamWAV] = []
    var pads: Array[AudioStreamWAV] = []
    for i in BIOMES.size():
        winds.append(ForestAudio.wind(i))
        pads.append(ForestAudio.pad(i))
    var d := {
        "winds": winds,
        "crickets": ForestAudio.crickets(),
        "birds": ForestAudio.birds(),
        "owl": ForestAudio.owl(),
        "steps": ForestAudio.footsteps(),
        "plucks": ForestAudio.plucks(),
        "pads": pads,
        "chime": ForestAudio.chime(),
        "collect": ForestAudio.collect(),
        "flutter": ForestAudio.flutter(),
        "shrine_cue": Sfx.build([[1047, 1047, 0.2, "sine", 0.2], [1568, 1568, 0.3, "sine", 0.1]]),
        "pond_cue": Sfx.build([[280, 120, 0.25, "sine", 0.2], [190, 90, 0.2, "sine", 0.1]]),
    }
    _audio_ready.call_deferred(d)


func _audio_ready(d: Dictionary) -> void:
    snd = d
    if not is_inside_tree():
        return
    for i in BIOMES.size():
        wind_players[i].stream = snd["winds"][i]
        wind_players[i].play()
        pad_players[i].stream = snd["pads"][i]
        pad_players[i].play()
    cricket_player.stream = snd["crickets"]
    cricket_player.play()


func _play(stream: AudioStream, db: float, pitch: float=1.0) -> void:
    var p := sfx_pool[sfx_next]
    sfx_next = (sfx_next + 1) % sfx_pool.size()
    p.stream = stream
    p.volume_db = db
    p.pitch_scale = pitch
    p.play()


func _play_named(key: String, db: float, pitch: float=1.0) -> void:
    if snd.has(key):
        _play(snd[key], db, pitch)


func _update_audio(delta: float) -> void:
    _blend_audio(delta)
    if snd.is_empty():
        return
    cricket_player.volume_db = lerpf(-60.0, -27.0, clampf(night * 1.2 - 0.1, 0.0, 1.0))
    for i in BIOMES.size():
        var db := linear_to_db(maxf(audio_weights[i], 0.0001))
        pad_players[i].volume_db = -15.0 + db
        wind_players[i].volume_db = -24.0 + sin(t * 0.2) * 3.0 + db
    _update_breadcrumbs(delta)
    bird_timer -= delta
    if bird_timer <= 0.0:
        if night < 0.4:
            var birds: Array = snd["birds"]
            _play(birds[randi() % birds.size()], -20.0, randf_range(0.9, 1.15))
            bird_timer = randf_range(3.0, 9.0)
        else:
            if night > 0.8:
                _play(snd["owl"], -18.0, randf_range(0.9, 1.1))
            bird_timer = randf_range(10.0, 20.0)
    pluck_timer -= delta
    if pluck_timer <= 0.0:
        var plucks: Array = snd["plucks"]
        _play(plucks[randi() % plucks.size()], -23.0)
        pluck_timer = randf_range(3.0, 8.0)


func _blend_audio(delta: float) -> void:
    audio_fade = minf(3.0, audio_fade + delta)
    for i in BIOMES.size():
        audio_weights[i] = lerpf(audio_from[i], 1.0 if i == cur_biome else 0.0,
            audio_fade / 3.0)


func _update_breadcrumbs(delta: float) -> void:
    breadcrumb_timer -= delta
    if breadcrumb_timer > 0.0 or landmark_player.playing:
        return
    var nearest: Dictionary = {}
    var distance := 120.0
    for object: Dictionary in vis_special:
        if object.get("kind", "") not in ["shrine", "pond"] or found_ids.has(object.get("id", "")):
            continue
        var pos := Vector2(float(object["x"]), float(object["y"]))
        var d := player_pos.distance_to(pos)
        if d < distance:
            nearest = object
            distance = d
    if nearest.is_empty():
        return
    # Center the virtual listener on the wanderer while preserving left/right cues.
    landmark_player.position = Vector2(VW / 2.0, VH / 2.0) + \
        Vector2(float(nearest["x"]), float(nearest["y"])) - player_pos
    landmark_player.stream = snd[str(nearest["kind"]) + "_cue"]
    landmark_player.volume_db = -24.0
    landmark_player.play()
    breadcrumb_timer = 3.0


# ----------------------------------------------------------------- helpers

static func _h(a: int, b: int) -> float:
    var h := (a * 374761393 + b * 668265263) & 0x7fffffff
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
    return float(h & 0xffff) / 65535.0


func _path_y(x: float) -> float:
    return 154.0 + 8.0 * sin(x * 0.012) + 4.0 * sin(x * 0.031 + 1.0)


func _wind_at(x: float) -> float:
    var gust := 0.7 + 0.3 * sin(t * 0.23)
    return (sin(t * 1.3 + x * 0.02) * 0.5 + sin(t * 0.7 + x * 0.011) * 0.5) * gust


func _update_palette() -> void:
    var i := 0
    for k in range(keys.size() - 1):
        var a: Dictionary = keys[k]
        var b: Dictionary = keys[k + 1]
        if time_of_day >= float(a["t"]) and time_of_day <= float(b["t"]):
            i = k
            break
    var a: Dictionary = keys[i]
    var b: Dictionary = keys[i + 1]
    var u := smoothstep(0.0, 1.0, inverse_lerp(float(a["t"]), float(b["t"]), time_of_day))
    pal_top = (a["top"] as Color).lerp(b["top"], u)
    pal_bot = (a["bot"] as Color).lerp(b["bot"], u)
    amb = (a["amb"] as Color).lerp(b["amb"], u) * bio_tint
    fog = (a["fog"] as Color).lerp(b["fog"], u)
    shaft = lerpf(float(a["shaft"]), float(b["shaft"]), u)
    night = lerpf(float(a["night"]), float(b["night"]), u)


# ------------------------------------------------------------------ biomes

static func _raw_biome(k: int) -> int:
    if k == 0:
        return 0
    return int(_h(k, 4001) * 5.0) % 5


static func _biome_of_region(k: int) -> int:
    var b := _raw_biome(k)
    if k != 0 and b == _raw_biome(k - 1):
        b = (b + 1 + int(_h(k, 4002) * 3.0)) % 5
    return b


static func _bound(k: int) -> float:
    if k == 0:
        return -300.0
    return k * BIOME_W + (_h(k, 4003) - 0.5) * 220.0


static func _region(x: float) -> int:
    var k := floori(x / BIOME_W)
    while x < _bound(k):
        k -= 1
    while x >= _bound(k + 1):
        k += 1
    return k


static func _biome_at(x: float) -> int:
    return _biome_of_region(_region(x))


## Smoothly blended biome weights around x.
static func _weights(x: float) -> PackedFloat32Array:
    var w := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
    var k := _region(x)
    var bl := 110.0
    var self_w := 1.0
    var dl := x - _bound(k)
    var dr := _bound(k + 1) - x
    if dl < bl:
        var nb := 0.5 * (1.0 - smoothstep(0.0, 1.0, dl / bl))
        w[_biome_of_region(k - 1)] += nb
        self_w -= nb
    if dr < bl:
        var nb := 0.5 * (1.0 - smoothstep(0.0, 1.0, dr / bl))
        w[_biome_of_region(k + 1)] += nb
        self_w -= nb
    w[_biome_of_region(k)] += self_w
    return w


func _update_biome() -> void:
    bw = _weights(player_pos.x)
    var c := Color(0, 0, 0, 1)
    var f := 0.0
    for i in 5:
        var tn: Color = BIOMES[i]["tint"]
        c.r += tn.r * bw[i]
        c.g += tn.g * bw[i]
        c.b += tn.b * bw[i]
        f += float(BIOMES[i]["fog"]) * bw[i]
    bio_tint = c
    fog_amt = f
    var id := _biome_of_region(_region(player_pos.x))
    if id != cur_biome:
        audio_from = audio_weights.duplicate()
        audio_fade = 0.0
        if cur_biome == -1:
            audio_weights.fill(0.0)
            audio_weights[id] = 1.0
            audio_from = audio_weights.duplicate()
            audio_fade = 3.0
        cur_biome = id
        title_text = BIOMES[id]["name"]
        title_t = 0.0


func _goto_biome(id: int) -> void:
    if id == 0:
        player_pos.x = 100.0
        return
    for k in range(1, 40):
        if _biome_of_region(k) == id:
            player_pos.x = (_bound(k) + _bound(k + 1)) * 0.5
            return


## Finds the nearest generated special of this kind (debug/screenshot helper).
func _find_special(kind: String) -> Vector2:
    var c0 := floori(player_pos.x / CHUNK)
    for d in range(0, 400):
        for sgn in [1, -1]:
            var ci: int = c0 + d * sgn
            for o: Dictionary in _chunk(ci):
                if o.get("kind", "") == kind:
                    return Vector2(float(o["x"]), float(o["y"]))
    return Vector2(1.0e9, 0.0)


# ----------------------------------------------------------------- update

func _process(delta: float) -> void:
    ui_t += delta
    frames += 1
    var j_down := Input.is_key_pressed(KEY_J)
    if j_down and not key_j_down and not paused:
        journal_open = not journal_open
    key_j_down = j_down
    var p_down := Input.is_key_pressed(KEY_P)
    if p_down and not key_p_down and not journal_open:
        paused = not paused
    key_p_down = p_down
    if Input.is_action_just_pressed("ui_cancel"):
        if journal_open:
            journal_open = false
        else:
            get_tree().change_scene_to_file("res://menu/menu.tscn")
            return
    _update_ui(delta)
    var frozen := paused or journal_open or journal_amount > 0.0
    if not frozen:
        t += delta
        time_of_day = fposmod(time_of_day + delta / DAY_LENGTH, 1.0)
        var t_down := Input.is_key_pressed(KEY_T)
        if t_down and not key_t_down:
            time_of_day = fposmod(time_of_day + 0.1, 1.0)
        key_t_down = t_down
        _update_biome()
        _update_palette()
        if discovery_left > 0.0:
            discovery_left = maxf(0.0, discovery_left - delta)
            vel = Vector2.ZERO
            moving = false
        else:
            _move(delta)
        _update_lantern(delta)
        cam_x = lerpf(cam_x, player_pos.x + facing * 18.0, 1.0 - exp(-delta * 2.5))
        _gather()
        _update_fuel(delta)
        _update_specials(delta)
        _update_particles(delta)
        _update_audio(delta)
    else:
        if vis_items.is_empty():
            _gather()
    queue_redraw()
    overlay.queue_redraw()
    front.queue_redraw()
    ui.queue_redraw()
    if shot_path != "" and frames == shot_frame:
        get_viewport().get_texture().get_image().save_png(shot_path)
        get_tree().quit()


func _move(delta: float) -> void:
    var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    running = Input.is_key_pressed(KEY_SHIFT)
    var speed := 74.0 if running else 38.0
    var target := Vector2(dir.x * speed, dir.y * speed * 0.55)
    vel = vel.lerp(target, 1.0 - exp(-delta * 10.0))
    player_pos += vel * delta
    player_pos.y = clampf(player_pos.y, Y_MIN, Y_MAX)
    moving = vel.length() > 3.0
    if absf(vel.x) > 3.0:
        facing = 1 if vel.x > 0.0 else -1
    if moving:
        anim_t += delta * (10.0 if running else 6.5)
        var phase := int(anim_t) % 4
        if phase != last_phase:
            last_phase = phase
            if phase % 2 == 0:
                _kick_foot()
                if not snd.is_empty():
                    var steps: Array = snd["steps"]
                    var terrain := _terrain()
                    _play(steps[terrain], [-23.0, -21.0, -19.0][terrain] + randf_range(-1.0, 1.0),
                        randf_range(0.9, 1.1))
    else:
        anim_t = 0.0
        last_phase = -1


func _terrain() -> int:
    for object: Dictionary in vis_flat:
        if object.get("kind", "") in ["pond", "puddle"]:
            var pos := Vector2(float(object["x"]), float(object["y"]))
            if absf(pos.x - player_pos.x) < float(object.get("rx", 15.0)) and \
                absf(pos.y - player_pos.y) < float(object.get("ry", 6.0)) + 3.0:
                return 2
    if cur_biome == 2:
        return 2
    return 0 if absf(player_pos.y - _path_y(player_pos.x)) < 8.0 else 1


func _update_lantern(delta: float) -> void:
    var target := Vector2(-vel.x * 0.045, -4.0 if discovery_left > 0.0 else 0.0)
    if moving:
        target += Vector2(sin(anim_t * PI) * 1.3, cos(anim_t * PI) * 0.5)
    # Small substeps keep the spring stable after a slow frame.
    var remaining := minf(delta, 0.1)
    while remaining > 0.0:
        var dt := minf(remaining, 1.0 / 120.0)
        lantern_velocity += ((target - lantern_offset) * 90.0 - lantern_velocity * 15.0) * dt
        lantern_offset += lantern_velocity * dt
        remaining -= dt


func _update_fuel(delta: float) -> void:
    var rate := 0.0035 * (1.0 + night * 0.8) * (2.2 if (running and moving) else 1.0)
    fuel = maxf(0.0, fuel - rate * delta)
    glow_k = lerpf(0.18, 1.0, sqrt(fuel))
    flick = 1.0
    if fuel < 0.15:
        flick = clampf(0.72 + 0.28 * sin(t * 31.0) * sin(t * 17.0 + 1.3) + 0.15 * sin(t * 53.0),
            0.35, 1.05)


## Collects the visible objects (cheap culling) and the subset that reacts to the player.
func _gather() -> void:
    vis_items.clear()
    vis_flat.clear()
    vis_special.clear()
    var left := cam_x - VW / 2.0 - 100.0
    var right := cam_x + VW / 2.0 + 100.0
    for ci in range(floori(left / CHUNK), floori(right / CHUNK) + 1):
        for o: Dictionary in _chunk(ci):
            if o.has("gone"):
                continue
            var ox: float = o["x"]
            if ox < left or ox > right:
                continue
            if o.has("flat"):
                vis_flat.append(o)
            else:
                vis_items.append(o)
            if o.has("kind"):
                vis_special.append(o)
    player_item["y"] = player_pos.y
    player_item["x"] = player_pos.x
    vis_items.append(player_item)


func _update_specials(dt: float) -> void:
    var light_r := lerpf(34.0, 62.0, fuel)
    var scared := false
    for o: Dictionary in vis_special:
        if o.has("gone"):
            continue
        var kind: String = o["kind"]
        var ox: float = o["x"]
        var oy: float = o["y"]
        var dx := absf(ox - player_pos.x)
        var dy := absf(oy - player_pos.y)
        match kind:
            "moonbloom":
                var tgt := 1.0 if (night > 0.5 and dx < light_r and dy < light_r * 0.6) else 0.0
                var op := move_toward(float(o["open"]), tgt, dt * 1.2)
                o["open"] = op
                if op > 0.8 and dx < 20.0 and dy < 12.0:
                    _discover(o)
            "glowmush":
                if dx < 20.0 and dy < 12.0:
                    _discover(o)
            "shrine":
                if dx < 22.0 and dy < 14.0:
                    _discover(o)
            "pond":
                if dx < float(o["rx"]) * 0.9 and dy < float(o["ry"]) + 8.0:
                    _discover(o)
            "glade":
                if dx < 26.0 and dy < 32.0:
                    _discover(o)
            "fox":
                _update_fox(o, dx, dy, dt)
            "lampmoss":
                if dx < 10.0 and dy < 8.0:
                    o["gone"] = true
                    fuel = minf(1.0, fuel + 0.3)
                    _burst(ox, oy - 4.0, Color(0.5, 1.0, 0.9), 14)
                    _play_named("collect", -11.0, randf_range(0.95, 1.1))
            "bird":
                var thr := 46.0 if (running and moving) else 28.0
                if night <= 0.55 and dx < thr and dy < 26.0:
                    _scare_bird(o)
                    scared = true
    if scared:
        _play_named("flutter", -13.0, randf_range(0.9, 1.15))
        if randf() < 0.5 and snd.has("birds"):
            var birds: Array = snd["birds"]
            _play(birds[randi() % birds.size()], -22.0, randf_range(1.0, 1.25))


func _update_fox(o: Dictionary, dx: float, dy: float, dt: float) -> void:
    var st: int = o["state"]
    var ox: float = o["x"]
    if st == 0:
        o["face"] = 1 if player_pos.x >= ox else -1
        if dx < 36.0 and dy < 18.0:
            _discover(o)
            o["state"] = 1
            o["st"] = 0.0
    elif st == 1:
        o["st"] = float(o["st"]) + dt
        if float(o["st"]) > 0.7:
            o["state"] = 2
            o["st"] = 0.0
            o["face"] = -1 if player_pos.x >= ox else 1
    else:
        var dir: int = o["face"]
        o["x"] = ox + dir * 64.0 * dt
        o["anim"] = float(o["anim"]) + dt
        o["st"] = float(o["st"]) + dt
        if float(o["st"]) > 3.5:
            o["gone"] = true


func _scare_bird(o: Dictionary) -> void:
    var ox: float = o["x"]
    var oy: float = o["y"]
    var lift: float = o["lift"]
    var dirx := 1.0 if ox >= player_pos.x else -1.0
    o["gone"] = true
    fly_birds.append({"x": ox, "y": oy - lift, "vx": dirx * randf_range(28.0, 52.0),
        "vy": randf_range(-48.0, -26.0),
        "t": 0.0, "v": o["v"], "ph": randf() * 6.0})
    # neighbours take off together
    for b: Dictionary in vis_special:
        if b.has("gone") or b["kind"] != "bird":
            continue
        if absf(float(b["x"]) - ox) < 50.0 and absf(
            float(b["y"]) - float(b["lift"]) - (oy - lift)) < 60.0 and randf() < 0.8:
            b["gone"] = true
            fly_birds.append({"x": b["x"], "y": float(b["y"]) - float(b["lift"]),
                "vx": dirx * randf_range(20.0, 55.0),
                "vy": randf_range(-50.0, -22.0), "t": -randf() * 0.15, "v": b["v"],
                "ph": randf() * 6.0})


func _discover(o: Dictionary) -> void:
    var id: String = o["id"]
    if found_ids.has(id):
        return
    found_ids[id] = true
    discovery_left = 0.5
    facing = 1 if float(o["x"]) >= player_pos.x else -1
    vel = Vector2.ZERO
    moving = false
    var kind: String = o["kind"]
    var n := int(found_counts.get(kind, 0)) + 1
    found_counts[kind] = n
    _save_found()
    for ty: Dictionary in TYPES:
        if ty["id"] == kind:
            if n == 1:
                toasts.append(
                    {"title": "Discovered: " + str(ty["name"]), "sub": ty["text"], "age": 0.0})
            else:
                toasts.append(
                    {"title": str(ty["name"]) + "  (found " + str(n) + ")", "sub": "", "age": 0.0})
    _play_named("chime", -9.0)
    var col := Color(1.0, 0.92, 0.6)
    _burst(float(o["x"]), float(o["y"]) - 8.0, col, 22)


func _burst(wx: float, wy: float, col: Color, n: int) -> void:
    for i in n:
        var a := randf() * TAU
        var sp := randf_range(8.0, 38.0)
        sparks.append({"x": wx, "y": wy, "vx": cos(a) * sp, "vy": sin(a) * sp - 14.0, "life": 0.0,
            "max": randf_range(0.6, 1.3), "c": col.lerp(Color.WHITE, randf() * 0.5)})
    while sparks.size() > 120:
        sparks.pop_front()


func _kick_foot() -> void:
    var on_path := absf(player_pos.y - _path_y(player_pos.x)) < 8.0
    var petal := Color(0, 0, 0, 0)
    for o: Dictionary in vis_items:
        if o.has("pc") and absf(float(o["x"]) - player_pos.x) < 16.0 and absf(
            float(o["y"]) - player_pos.y) < 8.0:
            petal = o["pc"]
            break
    var n := 4 if running else 2
    for i in n:
        var c: Color
        if on_path:
            c = Color("a8875a")
        elif petal.a > 0.0 and randf() < 0.7:
            c = petal
        else:
            c = ForestArt.LEAF[1 + randi() % 4]
        puffs.append({"x": player_pos.x + randf_range(-3.0, 3.0), "y": player_pos.y - 1.0,
            "vx": -facing * randf_range(4.0, 22.0),
            "vy": -randf_range(14.0, 36.0), "life": 0.0, "max": randf_range(0.5, 1.0), "c": c,
            "ph": randf() * TAU,
            "sw": 0.0 if on_path else randf_range(2.0, 5.0)})
    while puffs.size() > 70:
        puffs.pop_front()


func _update_particles(dt: float) -> void:
    var i := sparks.size() - 1
    while i >= 0:
        var s: Dictionary = sparks[i]
        s["life"] = float(s["life"]) + dt
        s["x"] = float(s["x"]) + float(s["vx"]) * dt
        s["y"] = float(s["y"]) + float(s["vy"]) * dt
        s["vx"] = float(s["vx"]) * 0.96
        s["vy"] = float(s["vy"]) * 0.96 - 6.0 * dt
        if float(s["life"]) > float(s["max"]):
            sparks.remove_at(i)
        i -= 1
    i = puffs.size() - 1
    while i >= 0:
        var p: Dictionary = puffs[i]
        p["life"] = float(p["life"]) + dt
        p["x"] = float(p["x"]) + float(p["vx"]) * dt + sin(
            float(p["life"]) * 9.0 + float(p["ph"])) * float(p["sw"]) * dt
        p["y"] = float(p["y"]) + float(p["vy"]) * dt
        p["vy"] = float(p["vy"]) + 70.0 * dt
        p["vx"] = float(p["vx"]) * 0.97
        if float(p["life"]) > float(p["max"]):
            puffs.remove_at(i)
        i -= 1
    i = fly_birds.size() - 1
    while i >= 0:
        var b: Dictionary = fly_birds[i]
        b["t"] = float(b["t"]) + dt
        if float(b["t"]) > 0.0:
            b["x"] = float(b["x"]) + float(b["vx"]) * dt
            b["y"] = float(b["y"]) + float(b["vy"]) * dt
            b["vy"] = float(b["vy"]) * 0.995
        if float(b["t"]) > 4.0 or float(b["y"]) < -12.0:
            fly_birds.remove_at(i)
        i -= 1


func _update_ui(delta: float) -> void:
    var visible := not moving or paused or journal_open or fuel < 0.15
    hud_alpha = move_toward(hud_alpha, 1.0 if visible else 0.0, delta * 3.0)
    journal_amount = move_toward(journal_amount, 1.0 if journal_open else 0.0, delta * 4.0)
    title_t += delta
    if not toasts.is_empty():
        var tw: Dictionary = toasts[0]
        tw["age"] = float(tw["age"]) + delta
        if float(tw["age"]) > 4.2:
            toasts.pop_front()


# ------------------------------------------------------------------- world

func _draw() -> void:
    _draw_sky()
    _draw_hills(0.05, 84.0, 26.0, fog.lerp(pal_top, 0.4))
    _draw_hills(0.1, 96.0, 20.0, fog.darkened(0.1))
    _draw_tree_layer(far_trees, 0.12, 104.0, 34.0, 0.15, 11, fog.darkened(0.28))
    _draw_tree_layer(far_trees2, 0.22, 112.0, 40.0, 0.2, 23, fog.darkened(0.14))
    _draw_tree_layer(mid_trees, 0.4, 121.0, 62.0, 0.3, 37, amb.lerp(fog, 0.35))
    # low mist between the distant and near forest (thicker in the bog)
    for k in 5:
        draw_rect(Rect2(0, 96 + k * 6, VW, 6),
            Color(fog.r, fog.g, fog.b, 0.08 + k * 0.025 + fog_amt * 0.12))
    _draw_tree_layer(hedges, 0.75, 126.0, 24.0, 0.1, 51, amb.darkened(0.15).lerp(fog, 0.12))
    _draw_ground()
    _draw_flats()
    _draw_objects()


func _draw_sky() -> void:
    var bands := 40
    for i in bands:
        var u := float(i) / (bands - 1)
        draw_rect(Rect2(0, i * 4, VW, 4), pal_top.lerp(pal_bot, pow(u, 0.8)))
    if night > 0.05:
        for i in 55:
            var sx := fposmod(_h(i, 1) * VW - cam_x * 0.02, VW)
            var a := night * (0.5 + 0.5 * sin(t * 2.0 + i)) * 0.9
            draw_rect(Rect2(floorf(sx), floorf(_h(i, 2) * 80.0), 1, 1), Color(1, 1, 0.9, a))
    var day_f := time_of_day / 0.62
    if day_f < 1.0:
        var sp := Vector2(lerpf(30.0, 290.0, day_f), 70.0 - 48.0 * sin(PI * day_f))
        draw_circle(sp, 7.0, Color(1.0, 0.95, 0.7, 1.0 - night))
    var moon_f := (time_of_day - 0.62) / 0.38
    if moon_f > 0.0 and moon_f < 1.0:
        var mp := Vector2(lerpf(30.0, 290.0, moon_f), 70.0 - 48.0 * sin(PI * moon_f))
        draw_circle(mp, 8.0, Color(0.9, 0.93, 1.0, night))
        draw_circle(mp + Vector2(-2, 1), 1.5, Color(0.7, 0.75, 0.85, night))
        draw_circle(mp + Vector2(2, -2), 1.0, Color(0.7, 0.75, 0.85, night))


func _draw_hills(p: float, base_y: float, amp: float, color: Color) -> void:
    for x in range(0, VW, 2):
        var wx := x + cam_x * p
        var v := sin(wx * 0.011) * 0.5 + sin(wx * 0.027 + 2.0) * 0.3 + sin(wx * 0.05 + 5.0) * 0.2
        var top := floorf(base_y - (v * 0.5 + 0.5) * amp)
        draw_rect(Rect2(x, top, 2, GROUND_TOP + 4 - top), color)


func _draw_tree_layer(texs: Array, p: float, base_y: float, spacing: float, skip: float, salt: int,
    col: Color) -> void:
    var half := VW / 2.0
    var i0 := floori((cam_x * p - half - 80.0) / spacing)
    var i1 := floori((cam_x * p + half + 80.0) / spacing)
    for i in range(i0, i1 + 1):
        if _h(i, salt) < skip:
            continue
        var wx := i * spacing + (_h(i, salt + 1) - 0.5) * spacing * 0.8
        var tex: Texture2D = texs[int(_h(i, salt + 2) * texs.size()) % texs.size()]
        var sx := wx - cam_x * p + half
        draw_texture(tex, Vector2(floorf(sx - tex.get_width() / 2.0), base_y - tex.get_height()),
            col)


func _draw_ground() -> void:
    var tw := ground_tile.get_width()
    var start := floorf(fposmod(VW / 2.0 - cam_x, tw)) - tw
    for k in range(0, VW / tw + 3):
        draw_texture(ground_tile, Vector2(start + k * tw, GROUND_TOP - 6), amb)
    # winding dirt path
    var edge := Color("4d3a28") * amb
    var base := Color("7a5b3a") * amb
    var light := Color("8c6d48") * amb
    for sx in range(0, VW, 2):
        var wx := sx + cam_x - VW / 2.0
        var cy := _path_y(wx)
        var hw := 7.0 + 2.0 * sin(wx * 0.03)
        var top := floorf(cy - hw)
        var bot := floorf(cy + hw)
        draw_rect(Rect2(sx, top - 1, 2, 1), edge)
        draw_rect(Rect2(sx, top, 2, bot - top), base)
        draw_rect(Rect2(sx, floorf(cy) - 2, 2, 4), light)
        draw_rect(Rect2(sx, bot, 2, 1), edge)
        var r := _h(int(wx) / 2, 9)
        if r < 0.12:
            draw_rect(Rect2(sx, top + 2 + r * 60.0, 1, 1), edge.lightened(0.2))
        elif r > 0.93:
            draw_rect(Rect2(sx, top + 2 + (r - 0.93) * 120.0, 1, 1), light.lightened(0.15))


func _ellipse(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
    var pts := PackedVector2Array()
    for i in 22:
        var a := TAU * i / 22.0
        pts.append(Vector2(floorf(c.x + cos(a) * rx), floorf(c.y + sin(a) * ry)))
    n.draw_colored_polygon(pts, col)


func _draw_flats() -> void:
    for o: Dictionary in vis_flat:
        var c := Vector2(floorf(float(o["x"]) - cam_x + VW / 2.0), floorf(float(o["y"])))
        match str(o["kind"]):
            "pond":
                _draw_pond(c, float(o["rx"]), float(o["ry"]), int(o["seed"]), 0.0)
            "puddle":
                _draw_pond(c, float(o["rx"]), float(o["ry"]), int(o["seed"]), 1.0)
            "glade":
                var warm := Color(1.0, 0.93, 0.62, 0.13 * (1.0 - night))
                var cool := Color(0.65, 0.78, 1.0, 0.13 * night)
                _ellipse(self, c, 50.0, 13.0, warm if night < 0.5 else cool)
                _ellipse(self, c, 32.0, 8.0, warm if night < 0.5 else cool)


func _draw_pond(c: Vector2, rx: float, ry: float, seed_: int, dark: float) -> void:
    var sky := pal_bot.lerp(pal_top, 0.45)
    var deep := sky.darkened(0.4 + dark * 0.25) * Color(0.8, 0.95, 1.0)
    _ellipse(self, c + Vector2(0, 1), rx + 2.0, ry + 1.5, Color(0.08, 0.07, 0.05, 0.9) * amb)
    _ellipse(self, c, rx, ry, deep)
    _ellipse(self, c + Vector2(0, -ry * 0.2), rx * 0.78, ry * 0.55, sky.darkened(0.12 + dark * 0.2))
    # dark reflections of the trees on the far bank
    for i in 4:
        var rxp := c.x + (_h(seed_, i) - 0.5) * rx * 1.4
        draw_rect(Rect2(floorf(rxp), c.y - ry * 0.6, 1, ry * 0.9), Color(0.03, 0.08, 0.06, 0.28))
    # drifting ripples
    for k in 3:
        var ph := fposmod(t * 0.3 + k / 3.0 + _h(seed_, 10 + k), 1.0)
        var rc := c + Vector2((_h(seed_, 20 + k) - 0.5) * rx * 0.9,
            (_h(seed_, 30 + k) - 0.5) * ry * 0.7)
        var pts := PackedVector2Array()
        for i in 13:
            var a := TAU * i / 12.0
            pts.append(Vector2(floorf(rc.x + cos(a) * ph * rx * 0.5),
                floorf(rc.y + sin(a) * ph * ry * 0.5)))
        draw_polyline(pts, Color(1, 1, 1, (1.0 - ph) * 0.3), 1.0)
    # glints, and the moon / sun floating on the water
    for i in 5:
        var g := sin(t * 1.6 + i * 2.3 + seed_)
        if g > 0.7:
            draw_rect(Rect2(floorf(c.x + (_h(seed_, 40 + i) - 0.5) * rx * 1.3),
                floorf(c.y + (_h(seed_, 50 + i) - 0.5) * ry), 2, 1), Color(1, 1, 1, 0.6))
    if night > 0.5 and dark < 0.5:
        var m := floorf(c.x + sin(t * 0.8) * 1.5)
        draw_rect(Rect2(m - 1, c.y - 1, 3, 2), Color(0.9, 0.95, 1.0, 0.55 * night))
        draw_rect(Rect2(m - 3, c.y, 7, 1), Color(0.8, 0.9, 1.0, 0.25 * night))
    # ripples when the player wades in
    if dark < 0.5 and absf(player_pos.x - (c.x + cam_x - VW / 2.0)) < rx and absf(
        player_pos.y - c.y) < ry + 3.0 and (moving or true):
        var pc := Vector2(floorf(player_pos.x - cam_x + VW / 2.0), player_pos.y)
        for k in 2:
            var ph := fposmod(t * 0.9 + k * 0.5, 1.0)
            var pts2 := PackedVector2Array()
            for i in 13:
                var a := TAU * i / 12.0
                pts2.append(Vector2(floorf(pc.x + cos(a) * (3.0 + ph * 9.0)),
                    floorf(pc.y + sin(a) * (1.0 + ph * 3.0))))
            draw_polyline(pts2, Color(1, 1, 1, (1.0 - ph) * 0.5), 1.0)


# ------------------------------------------------- y-sorted undergrowth

func _glade_at(ci: int) -> bool:
    var b := _biome_at(ci * CHUNK + CHUNK * 0.5)
    var rate: float = [0.07, 0.05, 0.0, 0.02, 0.12][b]
    return _h(ci, 777) < rate


func _near_glade(x: float) -> bool:
    var ci := floori(x / CHUNK)
    for c in range(ci - 1, ci + 2):
        if _glade_at(c) and absf(x - (c + 0.5) * CHUNK) < 62.0:
            return true
    return false


func _chunk(ci: int) -> Array:
    if chunks.has(ci):
        return chunks[ci]
    var rng := RandomNumberGenerator.new()
    rng.seed = ci * 7919 + 5000000000
    var arr: Array = []
    var x0 := ci * CHUNK
    var b := _biome_at(x0 + CHUNK * 0.5)
    var cfg: Dictionary = BIO_GEN[b]
    var glade := _glade_at(ci)
    var tw: Array = cfg["tw"]
    # trees
    var nt := (1 if rng.randf() < float(cfg["tree1"]) else 0) + (1 if rng.randf() < float(
        cfg["tree2"]) else 0)
    for i in nt:
        var r := rng.randf()
        var set_: Array = near_oak
        if r < float(tw[0]):
            set_ = near_birch
        elif r < float(tw[0]) + float(tw[1]):
            set_ = near_pine
        var it := _add(arr, set_, rng, x0, 126.0, 168.0, 0.008, 26, true)
        if not it.is_empty() and rng.randf() < 0.3:
            var th: float = (it["tex"] as Texture2D).get_height()
            _add_bird(arr, it, th * rng.randf_range(0.4, 0.6), rng)
    for i in rng.randi_range(0, int(cfg["bush"])):
        var it := _add(arr, bushes, rng, x0, 128.0, 176.0, 0.015, 16, true)
        if not it.is_empty() and rng.randf() < 0.3:
            _add_bird(arr, it, 12.0, rng)
    var fr: Array = cfg["fern"]
    for i in rng.randi_range(int(fr[0]), int(fr[1])):
        _add(arr, ferns, rng, x0, 128.0, 178.0, 0.06, 8, false, true)
    var tr: Array = cfg["tuft"]
    for i in rng.randi_range(int(tr[0]), int(tr[1])):
        _add(arr, tufts, rng, x0, 126.0, 178.0, 0.14, 0, false, true)
    for g in int(cfg["fgroups"]):
        if rng.randf() < float(cfg["flower"]):
            var col := rng.randi() % flowers.size()
            var cx := x0 + rng.randf() * CHUNK
            var cy := rng.randf_range(130.0, 176.0)
            for i in rng.randi_range(3, 7):
                arr.append({"tex": flowers[col], "x": cx + rng.randf_range(-12.0, 12.0),
                    "y": cy + rng.randf_range(-6.0, 6.0),
                    "sway": 0.1, "shadow": 0, "pc": flower_cols[col]})
    if rng.randf() < float(cfg["mush"]):
        var mx := x0 + rng.randf() * CHUNK
        var my := rng.randf_range(132.0, 176.0)
        var mk := rng.randi() % mushrooms.size()
        for i in rng.randi_range(1, 3):
            arr.append({"tex": mushrooms[mk], "x": mx + rng.randf_range(-6.0, 6.0),
                "y": my + rng.randf_range(-3.0, 3.0), "sway": 0.0, "shadow": 6})
    if rng.randf() < float(cfg["rock"]):
        _add(arr, rocks, rng, x0, 130.0, 176.0, 0.0, 14, true)
    if rng.randf() < float(cfg["log"]):
        _add(arr, logs, rng, x0, 132.0, 172.0, 0.0, 30, true)
    # ---- biome props
    for i in int(cfg["reeds"]):
        if rng.randf() < 0.7:
            _add(arr, reeds, rng, x0, 130.0, 176.0, 0.12, 0, false, true)
    if rng.randf() < float(cfg["puddle"]):
        for i in rng.randi_range(1, 2):
            var q := _pos(rng, x0, 138.0, 174.0, true)
            var prx := rng.randf_range(7.0, 13.0)
            arr.append(
                {"kind": "puddle", "x": q.x, "y": q.y, "rx": prx, "ry": prx * 0.3, "flat": true,
                    "seed": ci * 3 + i, "sway": 0.0, "shadow": 0})
    if rng.randf() < float(cfg["arch"]):
        _add(arr, arches, rng, x0, 134.0, 150.0, 0.0, 34, true)
    if rng.randf() < float(cfg["pillar"]):
        for i in rng.randi_range(1, 2):
            _add(arr, pillars, rng, x0, 132.0, 174.0, 0.0, 12, true)
    # ---- discoverables
    if rng.randf() < float(cfg["glow"]):
        var gp := _pos(rng, x0, 132.0, 176.0, false)
        var gid := "glowmush%d" % ci
        for i in rng.randi_range(2, 3):
            arr.append(
                {"kind": "glowmush", "id": gid, "tex": glow_mush[rng.randi() % glow_mush.size()],
                    "x": gp.x + rng.randf_range(-9.0, 9.0), "y": gp.y + rng.randf_range(-3.0, 3.0),
                    "sway": 0.0, "shadow": 6})
    if rng.randf() < float(cfg["bloom"]):
        for i in rng.randi_range(1, 2):
            var bp := _pos(rng, x0, 132.0, 176.0, false)
            arr.append(
                {"kind": "moonbloom", "id": "moonbloom%d_%d" % [ci, i], "tex": moon_bud, "x": bp.x,
                    "y": bp.y,
                    "open": 0.0, "sway": 0.08, "shadow": 0})
    if rng.randf() < float(cfg["fox"]):
        var fp := _pos(rng, x0, 134.0, 172.0, true)
        arr.append(
            {"kind": "fox", "id": "fox%d" % ci, "tex": fox_r[0], "x": fp.x, "y": fp.y, "state": 0,
                "st": 0.0,
                "face": 1, "anim": 0.0, "sway": 0.0, "shadow": 9})
    var shrine_p := Vector2.ZERO
    if rng.randf() < float(cfg["shrine"]):
        shrine_p = _pos(rng, x0, 136.0, 168.0, true)
        arr.append(
            {"kind": "shrine", "id": "shrine%d" % ci, "tex": stones[rng.randi() % stones.size()],
                "x": shrine_p.x, "y": shrine_p.y, "sway": 0.0, "shadow": 12})
        for i in rng.randi_range(2, 3):
            arr.append({"kind": "lampmoss", "tex": lamp_mosses[rng.randi() % lamp_mosses.size()],
                "x": shrine_p.x + rng.randf_range(-26.0, 26.0),
                "y": clampf(shrine_p.y + rng.randf_range(-6.0, 8.0), 130.0, 176.0),
                "sway": 0.12, "shadow": 0})
    if rng.randf() < float(cfg["moss"]):
        var lp := _pos(rng, x0, 132.0, 176.0, false)
        arr.append(
            {"kind": "lampmoss", "tex": lamp_mosses[rng.randi() % lamp_mosses.size()], "x": lp.x,
                "y": lp.y, "sway": 0.12, "shadow": 0})
    if not glade and rng.randf() < float(cfg["pond"]):
        var px := x0 + rng.randf_range(24.0, CHUNK - 24.0)
        var prx := rng.randf_range(16.0, 24.0)
        var pry := prx * 0.3
        var py := rng.randf_range(142.0, 168.0)
        var pd := py - _path_y(px)
        if absf(pd) < pry + 11.0:
            py = _path_y(px) + (pry + 12.0) * (1.0 if pd >= 0.0 else -1.0)
        py = clampf(py, 138.0, 174.0)
        arr.append({"kind": "pond", "id": "pond%d" % ci, "x": px, "y": py, "rx": prx, "ry": pry,
            "flat": true, "seed": ci, "sway": 0.0, "shadow": 0})
        if b == 2 or rng.randf() < 0.3:
            for i in 2:
                arr.append({"tex": reeds[rng.randi() % reeds.size()],
                    "x": px + (-1 if i == 0 else 1) * (prx + rng.randf_range(0.0, 4.0)),
                    "y": py + rng.randf_range(0.0, 3.0), "sway": 0.12, "shadow": 0})
    if glade:
        var gx := x0 + CHUNK * 0.5
        arr.append(
            {"kind": "glade", "id": "glade%d" % ci, "x": gx, "y": 150.0, "flat": true, "sway": 0.0,
                "shadow": 0})
        for i in 10:
            var a := TAU * i / 10.0
            var col2 := rng.randi() % flowers.size()
            arr.append({"tex": flowers[col2], "x": gx + cos(a) * rng.randf_range(32.0, 46.0),
                "y": 150.0 + sin(a) * rng.randf_range(8.0, 14.0),
                "sway": 0.1, "shadow": 0, "pc": flower_cols[col2]})
    chunks[ci] = arr
    # drop chunks far away so memory stays bounded
    if chunks.size() > 40:
        for k in chunks.keys():
            if absi(int(k) - int(cam_x / CHUNK)) > 12:
                chunks.erase(k)
    return arr


func _pos(rng: RandomNumberGenerator, x0: int, y_lo: float, y_hi: float,
    avoid_path: bool) -> Vector2:
    var x := x0 + rng.randf() * CHUNK
    var y := rng.randf_range(y_lo, y_hi)
    if avoid_path:
        var d := y - _path_y(x)
        if absf(d) < 11.0:
            y = clampf(_path_y(x) + (1.0 if d >= 0.0 else -1.0) * (11.0 + rng.randf() * 6.0), y_lo,
                178.0)
    return Vector2(x, y)


func _add(arr: Array, texs: Array, rng: RandomNumberGenerator, x0: int, y_lo: float, y_hi: float,
    sway: float, shadow: int, avoid_path: bool, glade_ok: bool=false) -> Dictionary:
    var p := _pos(rng, x0, y_lo, y_hi, avoid_path)
    var tex: Texture2D = texs[rng.randi() % texs.size()]
    if not glade_ok and _near_glade(p.x):
        return {}
    var o := {"tex": tex, "x": p.x, "y": p.y, "sway": sway, "shadow": shadow}
    arr.append(o)
    return o


func _add_bird(arr: Array, host: Dictionary, lift: float, rng: RandomNumberGenerator) -> void:
    var v := rng.randi() % bird_tex.size()
    var frames_b: Array = bird_tex[v]
    arr.append({"kind": "bird", "tex": frames_b[0], "v": v,
        "x": float(host["x"]) + rng.randf_range(-5.0, 5.0),
        "y": float(host["y"]) + 0.4, "lift": lift, "flip": rng.randf() < 0.5, "sway": 0.0,
        "shadow": 0})


func _shadow(p: Vector2, w: int) -> void:
    if w <= 0:
        return
    var c := Color(0.02, 0.05, 0.08, 0.28)
    draw_rect(Rect2(p.x - w / 2.0, p.y - 1, w, 2), c)
    draw_rect(Rect2(p.x - w / 2.0 + 2, p.y - 2, w - 4, 1), c)
    draw_rect(Rect2(p.x - w / 2.0 + 2, p.y + 1, w - 4, 1), c)


func _draw_objects() -> void:
    vis_items.sort_custom(
        func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
    var emissive := amb.lerp(Color.WHITE, night * 0.85)
    for o: Dictionary in vis_items:
        if o.has("player"):
            _draw_player()
            continue
        if o.has("gone"):
            continue
        var ox: float = o["x"]
        var oy: float = o["y"]
        var kind: String = o.get("kind", "")
        if kind == "bird" and night > 0.55:
            continue
        var tex: Texture2D = o["tex"]
        var col := amb
        var flip := -1.0 if o.has("flip") and o["flip"] else 1.0
        match kind:
            "fox":
                var arr: Array = fox_r if int(o["face"]) > 0 else fox_l
                var fi := 0
                if int(o["state"]) == 2:
                    fi = 1 + int(float(o["anim"]) * 9.0) % 2
                tex = arr[fi]
            "moonbloom":
                var op: float = o["open"]
                if op > 0.5:
                    tex = moon_open
                col = amb.lerp(Color.WHITE, op * 0.6)
            "glowmush", "lampmoss":
                col = emissive
        var sx := ox - cam_x + VW / 2.0
        var basep := Vector2(floorf(sx), floorf(oy))
        _shadow(basep, int(o["shadow"]))
        var sway: float = o["sway"]
        var sw := _wind_at(ox) * sway
        if sway >= 0.05:
            # grass bends away from the player
            var dxp := ox - player_pos.x
            var tgt := 0.0
            if absf(dxp) < 24.0 and absf(oy - player_pos.y) < 9.0:
                tgt = -signf(dxp) * (1.0 - absf(dxp) / 24.0) * 6.0 / tex.get_height()
            var bd: float = o.get("bend", 0.0)
            bd = lerpf(bd, tgt, 0.2)
            o["bend"] = bd
            sw += bd
        var lift: float = o.get("lift", 0.0)
        draw_set_transform_matrix(
            Transform2D(Vector2(flip, 0), Vector2(sw, 1), basep + Vector2(0, -lift)))
        draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()), col)
        draw_set_transform_matrix(Transform2D.IDENTITY)


func _lantern_pos() -> Vector2:
    var pos := Vector2(floorf(player_pos.x - cam_x + VW / 2.0), floorf(player_pos.y))
    var bob := 0.0
    if moving:
        bob = -float(int(anim_t) % 2)
    var hx := 2.0 if facing > 0 else -3.0
    return pos + Vector2(hx + facing * 1.0, -10.0 + bob) + lantern_offset


func _draw_player() -> void:
    var pos := Vector2(floorf(player_pos.x - cam_x + VW / 2.0), floorf(player_pos.y))
    _shadow(pos, 12)
    var frames_arr: Array = player_r if facing > 0 else player_l
    var f := 0
    if moving:
        f = 1 + int(anim_t) % 4
    var tex: Texture2D = frames_arr[f]
    draw_texture(tex, pos + Vector2(-8, -24), amb.lerp(Color.WHITE, 0.4))
    var lp := _lantern_pos()
    draw_line(pos + Vector2(facing * 2, -13), lp, Color("bba079"), 1.0)
    draw_rect(Rect2(floorf(lp.x) - 2, floorf(lp.y) - 2, 5, 7), Color("2a1d16"))
    var flame := Color("ffe08a").lerp(Color("c86a28"), 1.0 - clampf(fuel * 3.0, 0.0, 1.0))
    var height := ceili(fuel * 4.0)
    flame *= Color(lerpf(0.2, 1.0, fuel) * flick, lerpf(0.2, 1.0, fuel) * flick,
        lerpf(0.2, 1.0, fuel) * flick)
    if height > 0:
        draw_rect(Rect2(floorf(lp.x) - 1, floorf(lp.y) + 4 - height, 3, height), flame)
    draw_rect(Rect2(floorf(lp.x), floorf(lp.y) - 3, 1, 1), Color("2a1d16"))


# ---------------------------------------------------------------- overlays

func _draw_overlay() -> void:
    var o := overlay
    # sun glow by day
    var day_f := time_of_day / 0.62
    if day_f < 1.0:
        var sp := Vector2(lerpf(30.0, 290.0, day_f), 70.0 - 48.0 * sin(PI * day_f))
        for r in [40.0, 30.0, 22.0, 15.0]:
            o.draw_circle(sp, r, Color(1.0, 0.85, 0.5, 0.04 * (1.0 - night)))
    # god rays filtering through the canopy
    if shaft > 0.02:
        for k in 7:
            var bx := fposmod(k * 90.0 + 30.0 - cam_x * 0.35, 630.0) - 120.0
            var a := shaft * 0.065 * (0.7 + 0.3 * sin(t * 0.5 + k * 2.0))
            var wdt := 14.0 + _h(k, 5) * 18.0
            o.draw_colored_polygon(PackedVector2Array([
                Vector2(bx, -5), Vector2(bx + wdt, -5),
                Vector2(bx + wdt + 80.0, GROUND_TOP + 28), Vector2(bx + 55.0, GROUND_TOP + 28)]),
                Color(1.0, 0.93, 0.65, a))
            o.draw_colored_polygon(PackedVector2Array([
                Vector2(bx + wdt * 0.3, -5), Vector2(bx + wdt * 0.7, -5),
                Vector2(bx + wdt + 62.0, GROUND_TOP + 28), Vector2(bx + 66.0, GROUND_TOP + 28)]),
                Color(1.0, 0.95, 0.75, a * 0.9))
        for d: Dictionary in dust:
            var dx := fposmod(float(d["x"]) + sin(t * 0.4 + float(d["ph"])) * 10.0 - cam_x * 0.6,
                VW + 20.0) - 10.0
            var dy := float(d["y"]) + cos(t * 0.5 + float(d["ph"])) * 6.0
            var da := shaft * (0.2 + 0.25 * sin(t * 1.5 + float(d["ph"])))
            o.draw_rect(Rect2(floorf(dx), floorf(dy), 1, 1), Color(1.0, 0.95, 0.7, da))
    # fireflies at dusk and night
    if night > 0.15:
        for f: Dictionary in fireflies:
            var ph: float = f["ph"]
            var fx := fposmod(float(f["x"]) - cam_x * 0.9 + sin(t * float(f["sp"]) + ph) * 14.0,
                VW + 40.0) - 20.0
            var fy := float(f["y"]) + cos(t * float(f["sp"]) * 0.8 + ph) * 9.0
            var blink := clampf(0.5 + 0.7 * sin(t * float(f["bs"]) + ph * 3.0), 0.0, 1.0) * night
            var c := Vector2(floorf(fx), floorf(fy))
            o.draw_circle(c, 5.0, Color(0.75, 1.0, 0.35, 0.07 * blink))
            o.draw_circle(c, 2.5, Color(0.8, 1.0, 0.4, 0.18 * blink))
            o.draw_rect(Rect2(c, Vector2(1, 1)), Color(1.0, 1.0, 0.7, blink))
    # emissive discoverables and shafts of light in glades
    var em := 0.3 + 0.7 * night
    for s: Dictionary in vis_special:
        if s.has("gone"):
            continue
        var sx := float(s["x"]) - cam_x + VW / 2.0
        var sy := float(s["y"])
        match str(s["kind"]):
            "glowmush":
                var pu := 0.8 + 0.2 * sin(t * 2.0 + sx)
                o.draw_circle(Vector2(sx, sy - 4.0), 9.0, Color(0.3, 1.0, 0.85, 0.05 * em * pu))
                o.draw_circle(Vector2(sx, sy - 4.0), 5.0, Color(0.4, 1.0, 0.9, 0.09 * em * pu))
            "lampmoss":
                var pu2 := 0.8 + 0.2 * sin(t * 1.6 + sx * 0.3)
                var e2 := 0.55 + 0.45 * night
                o.draw_circle(Vector2(sx, sy - 4.0), 11.0, Color(0.3, 0.9, 1.0, 0.05 * e2 * pu2))
                o.draw_circle(Vector2(sx, sy - 4.0), 6.0, Color(0.5, 1.0, 0.9, 0.09 * e2 * pu2))
            "moonbloom":
                var op: float = s["open"]
                if op > 0.02:
                    o.draw_circle(Vector2(sx, sy - 9.0), 12.0, Color(0.75, 0.7, 1.0, 0.07 * op))
                    o.draw_circle(Vector2(sx, sy - 9.0), 6.0, Color(0.9, 0.9, 1.0, 0.1 * op))
            "shrine":
                var pu3 := 0.7 + 0.3 * sin(t * 1.2)
                o.draw_circle(Vector2(sx, sy - 16.0), 12.0,
                    Color(0.4, 1.0, 0.85, 0.04 * (0.4 + night) * pu3))
                o.draw_circle(Vector2(sx, sy - 16.0), 6.0,
                    Color(0.5, 1.0, 0.9, 0.08 * (0.4 + night) * pu3))
            "glade":
                var beam := Color(1.0, 0.93, 0.65, 0.085 * (1.0 - night)) if night < 0.5 else Color(
                    0.6, 0.75, 1.0, 0.085 * night)
                var sw := 0.9 + 0.1 * sin(t * 0.7)
                o.draw_colored_polygon(PackedVector2Array([
                    Vector2(sx - 18.0, -5), Vector2(sx + 6.0, -5),
                    Vector2(sx + 38.0 * sw, sy + 4.0), Vector2(sx - 40.0 * sw, sy + 4.0)]), beam)
                o.draw_colored_polygon(PackedVector2Array([
                    Vector2(sx - 8.0, -5), Vector2(sx, -5), Vector2(sx + 18.0, sy + 4.0),
                    Vector2(sx - 22.0, sy + 4.0)]), beam)
                for k in 8:
                    var mx := sx + sin(t * 0.5 + k * 1.7) * 26.0 + (k - 4) * 4.0
                    var my := fposmod(sy - 70.0 + k * 13.0 - t * 4.0, 76.0) + sy - 75.0
                    o.draw_rect(Rect2(floorf(mx), floorf(my), 1, 1),
                        Color(beam.r, beam.g, beam.b, 0.55))
    # lantern glow (shrinks with fuel, flickers when low)
    var lp := _lantern_pos() + Vector2(1.0, 2.0)
    var g := (0.25 + night * 0.75) * flick
    for r in [46.0, 38.0, 30.0, 23.0, 17.0, 12.0, 7.0]:
        o.draw_circle(lp, maxf(r * glow_k, 2.0), Color(1.0, 0.7, 0.32, 0.045 * g))
    # sparkles
    for s: Dictionary in sparks:
        var u := float(s["life"]) / float(s["max"])
        var c: Color = s["c"]
        c.a = 1.0 - u
        var p := Vector2(floorf(float(s["x"]) - cam_x + VW / 2.0), floorf(float(s["y"])))
        o.draw_rect(Rect2(p, Vector2(1, 1)), c)
        if u < 0.5:
            c.a *= 0.5
            o.draw_rect(Rect2(p.x - 1, p.y, 3, 1), c)
            o.draw_rect(Rect2(p.x, p.y - 1, 1, 3), c)


func _draw_front() -> void:
    var f := front
    # butterflies by day (more in meadows and groves)
    var day := clampf(1.0 - night * 1.6, 0.0, 1.0)
    var nb := 1 + int(bw[4] * 5.0 + bw[0] * 1.5)
    if day > 0.1:
        for bi in mini(nb, butterflies.size()):
            var b: Dictionary = butterflies[bi]
            var ph: float = b["ph"]
            var bx := fposmod(float(b["x"]) - cam_x * 0.95 + sin(t * float(b["sp"]) + ph) * 40.0,
                VW + 60.0) - 30.0
            var by := float(b["y"]) + sin(t * float(b["sp"]) * 1.7 + ph) * 12.0
            var wing := 1 + int(absf(sin(t * 14.0 + ph)) * 2.0)
            var bc: Color = (b["c"] as Color) * amb
            bc.a = day
            var p := Vector2(floorf(bx), floorf(by))
            f.draw_rect(Rect2(p.x - wing, p.y - 1, wing, 2), bc)
            f.draw_rect(Rect2(p.x + 1, p.y - 1, wing, 2), bc)
            f.draw_rect(Rect2(p.x, p.y - 1, 1, 3), Color(0.15, 0.1, 0.1, day))
    # kicked-up petals and leaves
    for p: Dictionary in puffs:
        var c: Color = p["c"]
        c.a = 1.0 - float(p["life"]) / float(p["max"])
        var q := Vector2(floorf(float(p["x"]) - cam_x + VW / 2.0), floorf(float(p["y"])))
        f.draw_rect(
            Rect2(q, Vector2(2, 1) if int(float(p["life"]) * 8.0) % 2 == 0 else Vector2(1, 2)),
            c * amb.lerp(Color.WHITE, 0.4))
    # startled birds
    for b: Dictionary in fly_birds:
        if float(b["t"]) < 0.0:
            continue
        var frames_b: Array = bird_tex[int(b["v"])]
        var bt: Texture2D = frames_b[1 + int(float(b["t"]) * 14.0 + float(b["ph"])) % 2]
        var bp := Vector2(floorf(float(b["x"]) - cam_x + VW / 2.0), floorf(float(b["y"])))
        var fl := -1.0 if float(b["vx"]) < 0.0 else 1.0
        f.draw_set_transform_matrix(Transform2D(Vector2(-fl, 0), Vector2(0, 1), bp))
        f.draw_texture(bt, Vector2(-bt.get_width() / 2.0, -bt.get_height()),
            amb.lerp(Color.WHITE, 0.3))
        f.draw_set_transform_matrix(Transform2D.IDENTITY)
    # drifting leaves
    for l: Dictionary in leaves:
        var lx := fposmod(float(l["x"]) + t * float(l["vx"]) - cam_x * float(l["par"]),
            VW + 20.0) - 10.0
        var ly := fposmod(float(l["y"]) + t * float(l["vy"]), VH + 20.0) - 10.0 + sin(
            t * 1.5 + float(l["ph"])) * 5.0
        var lc: Color = (l["c"] as Color) * amb
        var flip := int(t * 3.0 + float(l["ph"])) % 2 == 0
        f.draw_rect(Rect2(floorf(lx), floorf(ly), 2 if flip else 1, 1 if flip else 2), lc)
    # bog mist rolling over the ground
    if fog_amt > 0.02:
        var fc := fog.lerp(Color.WHITE, 0.3)
        for k in 6:
            f.draw_rect(Rect2(0, 112 + k * 12, VW, 12),
                Color(fc.r, fc.g, fc.b, fog_amt * (0.03 + 0.022 * k)))
        for i in 12:
            var wx := fposmod(i * 61.0 - cam_x * 0.85 + t * (2.0 + (i % 3) * 1.5),
                VW + 140.0) - 70.0
            var wy := 116.0 + float((i * 23) % 56)
            var ww := 50.0 + float((i * 17) % 50)
            f.draw_rect(Rect2(floorf(wx), floorf(wy), ww, 2),
                Color(fc.r, fc.g, fc.b, fog_amt * 0.14))
            f.draw_rect(Rect2(floorf(wx) + 8, floorf(wy) + 2, ww - 16.0, 1),
                Color(fc.r, fc.g, fc.b, fog_amt * 0.1))
    # close foreground: dark canopy at the top and ferns at the bottom
    var dark := amb * Color(0.55, 0.6, 0.6)
    for i in range(floori((cam_x * 1.25 - 200.0) / 150.0),
        floori((cam_x * 1.25 + 200.0) / 150.0) + 1):
        if _h(i, 71) < 0.3 + bw[4] * 0.45:
            continue
        var tex: Texture2D = fg_leaves[int(_h(i, 72) * fg_leaves.size()) % fg_leaves.size()]
        var sx := i * 150.0 - cam_x * 1.25 + VW / 2.0 + _h(i, 73) * 40.0
        f.draw_texture(tex, Vector2(floorf(sx), -14.0), dark)
    for i in range(floori((cam_x * 1.4 - 200.0) / 120.0),
        floori((cam_x * 1.4 + 200.0) / 120.0) + 1):
        if _h(i, 81) < 0.4:
            continue
        var tex: Texture2D = fg_ferns[int(_h(i, 82) * fg_ferns.size()) % fg_ferns.size()]
        var sx := i * 120.0 - cam_x * 1.4 + VW / 2.0 + _h(i, 83) * 30.0
        f.draw_texture(tex, Vector2(floorf(sx), VH - tex.get_height() + 6.0),
            dark * Color(0.8, 0.85, 0.8))


# ---------------------------------------------------------------------- UI

func _txt(n: CanvasItem, p: Vector2, s: String, col: Color, size: int=8) -> void:
    var font := ThemeDB.fallback_font
    n.draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
        Color(0, 0, 0, col.a * 0.7))
    n.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _txt_c(n: CanvasItem, cx: float, y: float, s: String, col: Color, size: int=8) -> void:
    var w := ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    _txt(n, Vector2(floorf(cx - w / 2.0), y), s, col, size)


func _panel(n: CanvasItem, r: Rect2, fill: Color, border: Color) -> void:
    n.draw_rect(r, fill)
    n.draw_rect(r, border, false)
    n.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)),
        Color(border.r, border.g, border.b, border.a * 0.35), false)


func _wrap(s: String, width: float, size: int) -> Array[String]:
    var font := ThemeDB.fallback_font
    var lines: Array[String] = []
    var cur := ""
    for word in s.split(" "):
        var test := word if cur == "" else cur + " " + word
        if cur != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
            lines.append(cur)
            cur = word
        else:
            cur = test
    if cur != "":
        lines.append(cur)
    return lines


func _draw_ui() -> void:
    var u := ui
    # discovery counter (top left)
    u.draw_rect(Rect2(8, 8, 1, 5), Color(1.0, 0.92, 0.6, 0.85 * hud_alpha))
    u.draw_rect(Rect2(6, 10, 5, 1), Color(1.0, 0.92, 0.6, 0.85 * hud_alpha))
    _txt(u, Vector2(14, 14), "%d found" % _total_found(), Color(1, 0.95, 0.8, 0.8 * hud_alpha))
    _draw_toast(u)
    _draw_title(u)
    if journal_amount > 0.0:
        _draw_journal(u)
    elif paused:
        u.draw_rect(Rect2(0, 0, VW, VH), Color(0.02, 0.03, 0.08, 0.55))
        _txt_c(u, VW / 2.0, VH / 2.0 - 2.0, "PAUSED", Color(1, 0.95, 0.8), 16)
        _txt_c(u, VW / 2.0, VH / 2.0 + 14.0, "P resume   Esc menu", Color(0.8, 0.88, 1.0))
    var alpha := hud_alpha
    if alpha > 0.0 and not journal_open:
        var msg := "Arrows walk   Shift run   J journal   P pause   T time   Esc menu"
        _txt_c(u, VW / 2.0, VH - 6.0, msg, Color(1, 1, 0.9, alpha))


func _draw_toast(u: Node2D) -> void:
    if toasts.is_empty():
        return
    var tw: Dictionary = toasts[0]
    var age: float = tw["age"]
    var a := clampf(minf(age / 0.3, (4.2 - age) / 0.6), 0.0, 1.0)
    var title: String = tw["title"]
    var sub: String = tw["sub"]
    var font := ThemeDB.fallback_font
    var w := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x,
        font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 18.0
    var h := 24.0 if sub != "" else 15.0
    var y := 20.0 - (1.0 - clampf(age / 0.3, 0.0, 1.0)) * 8.0
    var r := Rect2(floorf(VW / 2.0 - w / 2.0), floorf(y), floorf(w), h)
    _panel(u, r, Color(0.05, 0.07, 0.14, 0.82 * a), Color(1.0, 0.88, 0.55, 0.6 * a))
    _txt_c(u, VW / 2.0, r.position.y + 10.0, title, Color(1.0, 0.92, 0.62, a))
    if sub != "":
        _txt_c(u, VW / 2.0, r.position.y + 20.0, sub, Color(0.78, 0.86, 0.95, a * 0.9))


func _draw_title(u: Node2D) -> void:
    if title_t > 4.4 or title_text == "":
        return
    var a := clampf(minf(title_t / 1.0, (4.4 - title_t) / 1.4), 0.0, 1.0) * 0.85
    var y := 64.0
    _txt_c(u, VW / 2.0, y, title_text.to_upper(), Color(1, 1, 0.95, a), 12)
    var w := ThemeDB.fallback_font.get_string_size(title_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
        -1, 12).x
    u.draw_rect(Rect2(VW / 2.0 - w / 2.0 - 14, y - 4, 10, 1), Color(1, 1, 0.9, a * 0.6))
    u.draw_rect(Rect2(VW / 2.0 + w / 2.0 + 4, y - 4, 10, 1), Color(1, 1, 0.9, a * 0.6))


func _draw_icon(u: Node2D, kind: String, box: Rect2, known: bool) -> void:
    var col := Color("a96932") if known else Color(0.1, 0.08, 0.06, 0.95)
    var c := box.get_center()
    var tex: Texture2D = null
    match kind:
        "glowmush":
            tex = glow_mush[0]
        "moonbloom":
            tex = moon_open
        "fox":
            tex = fox_r[0]
        "shrine":
            tex = stones[0]
        "pond":
            _ellipse(u, c + Vector2(0, 2), 10.0, 4.0, Color("a96932") if known else col)
            _ellipse(u, c + Vector2(0, 1), 6.0, 2.0, Color("c28c50") if known else col)
        "glade":
            var lc := Color(1, 0.95, 0.6, 0.55) if known else col
            u.draw_colored_polygon(PackedVector2Array(
                [c + Vector2(-3, -10), c + Vector2(2, -10), c + Vector2(9, 6),
                    c + Vector2(-10, 6)]), lc)
            _ellipse(u, c + Vector2(0, 7), 10.0, 3.0, Color(0.5, 0.8, 0.4) if known else col)
    if tex != null:
        var sz := tex.get_size()
        var s := maxf(floorf(minf(22.0 / sz.x, 22.0 / sz.y)), 1.0)
        if sz.y * s > 24.0:
            s = 1.0
        var tsz := sz * s
        u.draw_texture_rect(tex, Rect2((c - tsz / 2.0).floor(), tsz), false, col)


func _draw_journal(u: Node2D) -> void:
    u.draw_rect(Rect2(0, 0, VW, VH), Color(0.01, 0.02, 0.05, 0.6 * journal_amount))
    var opening := smoothstep(0.0, 1.0, journal_amount)
    var scale_x := lerpf(0.12, 1.0, opening)
    u.draw_set_transform(Vector2(VW * (1.0 - scale_x) / 2.0, (1.0 - opening) * 6.0),
        0.0, Vector2(scale_x, 1.0))
    var r := Rect2(10, 7, VW - 20, VH - 14)
    _panel(u, r, Color("ecd6aa"), Color(0.85, 0.72, 0.45, 0.85))
    _txt_c(u, VW / 2.0, 21.0, "FOREST JOURNAL", Color("704323"), 12)
    u.draw_line(Vector2(VW / 2.0, 41), Vector2(VW / 2.0, VH - 25), Color(0.4, 0.25, 0.1, 0.2))
    var tf := _types_found()
    var total := _total_found()
    _txt_c(u, VW / 2.0, 33.0, "Discoveries: %d      Kinds: %d / %d" % [total, tf, TYPES.size()],
        Color("795d40"))
    u.draw_rect(Rect2(110, 36, 100, 3), Color(0, 0, 0, 0.6))
    u.draw_rect(Rect2(110, 36, floorf(100.0 * tf / TYPES.size()), 3), Color("a96932"))
    for i in TYPES.size():
        var ty: Dictionary = TYPES[i]
        var n := int(found_counts.get(ty["id"], 0))
        var known := n > 0
        var x := 20.0 + (i % 2) * 150.0
        var y := 46.0 + (i / 2) * 38.0
        var box := Rect2(x, y, 26, 26)
        u.draw_rect(box, Color("e2c595") if known else Color("bba584"))
        u.draw_rect(box, Color(0.85, 0.72, 0.45, 0.6 if known else 0.25), false)
        _draw_icon(u, str(ty["id"]), box, known)
        var tx := x + 31.0
        if known:
            _txt(u, Vector2(tx, y + 7.0), str(ty["name"]), Color("704323"))
            _txt(u, Vector2(tx, y + 16.0), "Found: %d" % n, Color("805633"))
            var lines := _wrap(str(ty["text"]), 106.0, 8)
            for li in mini(lines.size(), 2):
                _txt(u, Vector2(tx, y + 25.0 + li * 9.0), lines[li], Color("795d40"))
        else:
            _txt(u, Vector2(tx, y + 7.0), "???", Color("6c5944"))
            _txt(u, Vector2(tx, y + 16.0), "Not yet found", Color("76634e"))
            var hl := _wrap("Hint: " + str(ty["hint"]), 106.0, 8)
            for li in mini(hl.size(), 2):
                _txt(u, Vector2(tx, y + 25.0 + li * 9.0), hl[li], Color("76634e"))
    _txt_c(u, VW / 2.0, VH - 12.0, "J close     Esc close", Color("795d40"))
    u.draw_set_transform(Vector2.ZERO)
