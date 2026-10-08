extends Node2D

const W := 640
const H := 480
const PLAYER_Y := 440.0
const PLAYER_W := 30.0
const PLAYER_H := 16.0
const PLAYER_SPEED := 280.0
const ALIEN_W := 24.0
const ALIEN_H := 16.0
const COLS := 8
const ROW_POINTS := [30, 20, 20, 10, 10, 10]
const ROW_COLORS := [Color.MAGENTA, Color.CYAN, Color.CYAN, Color.LIME_GREEN, Color.LIME_GREEN,
    Color.LIME_GREEN]
const TOUGH_COLOR := Color.GOLD
const DIVER_COLOR := Color(1.0, 0.5, 0.1)

# Bunkers: 4 shields built from 4px cells
const CELL := 4.0
const BUNKER_COLS := 11
const BUNKER_ROWS := 8
const BUNKER_COUNT := 4
const BUNKER_Y := 360.0
const BUNKER_X0 := 58.0
const BUNKER_SPACING := 160.0

const UFO_Y := 40.0
const BOSS_Y := 62.0
const BOSS_W := 110.0
const BOSS_H := 40.0

# Power-up kinds
const P_RAPID := 0
const P_SPREAD := 1
const P_SHIELD := 2
const POWER_NAMES := ["RAPID", "SPREAD", "SHIELD"]
const POWER_LETTERS := ["R", "S", "B"]
const POWER_COLORS := [Color.YELLOW, Color.MAGENTA, Color.CYAN]
const POWER_TIME := [8.0, 8.0, 6.0]

enum State {TITLE, INTRO, PLAYING, GAME_OVER}

class Alien:
    var pos: Vector2
    var row: int
    var col: int
    var hp := 1
    var tough := false
    var diving := false
    var dive_t := 0.0
    var dive_x := 0.0

class PBullet:
    var pos: Vector2
    var vx := 0.0

class EBullet:
    var pos: Vector2
    var vel: Vector2
    var size := Vector2(3, 10)
    var color := Color.ORANGE_RED

class Drop:
    var pos: Vector2
    var kind: int


var state := State.TITLE
var paused := false
var level := 1
var score := 0
var hi_score := 0
var lives := 3
var new_record := false

var player_x := W / 2.0
var invuln := 0.0
var pbullets: Array[PBullet] = []
var fire_cd := 0.0

var rapid_t := 0.0
var spread_t := 0.0
var shield_t := 0.0
var drops: Array[Drop] = []

var aliens: Array[Alien] = []
var total_aliens := 1
var alien_dir := 1
var alien_anim := false
var step_timer := 0.0
var step_note := 0
var alien_bullets: Array[EBullet] = []
var fire_timer := 1.0
var dive_timer := 4.0

var bunker_cells := PackedByteArray()

var ufo_active := false
var ufo_x := 0.0
var ufo_dir := 1
var ufo_timer := 10.0
var ufo_player: AudioStreamPlayer

var boss_active := false
var boss_x := W / 2.0
var boss_dir := 1
var boss_hp := 1
var boss_max := 1
var boss_cd := 1.0
var boss_pattern := 0
var boss_flash := 0.0

var lost_life := false
var intro_msg := ""

var effects: Array = []  # [Vector2 position, float age, Color]
var texts: Array = []  # [Vector2 position, float age, String, Color]
var stars: Array[Vector2] = []
var intro_timer := 0.0

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0


func _ready() -> void:
    hi_score = Save.get_high("invaders")
    for i in 60:
        stars.append(Vector2(randf() * W, randf() * H))
    for i in 8:
        var p := AudioStreamPlayer.new()
        add_child(p)
        players.append(p)
    sounds = {
        "shoot": Sfx.build([[900, 200, 0.15, "square", 0.25]]),
        "kill": Sfx.build([[400, 80, 0.25, "noise", 0.5]]),
        "hit": Sfx.build([[200, 40, 0.6, "noise", 0.7], [120, 40, 0.3, "square", 0.3]]),
        "step0": Sfx.build([[110, 110, 0.07, "square", 0.3]]),
        "step1": Sfx.build([[98, 98, 0.07, "square", 0.3]]),
        "step2": Sfx.build([[87, 87, 0.07, "square", 0.3]]),
        "step3": Sfx.build([[78, 78, 0.07, "square", 0.3]]),
        "start": Sfx.build([[440, 440, 0.08, "square", 0.3], [660, 660, 0.08, "square", 0.3],
            [880, 880, 0.12, "square", 0.3]]),
        "level": Sfx.build([[523, 523, 0.1, "square", 0.3], [659, 659, 0.1, "square", 0.3],
            [784, 784, 0.1, "square", 0.3], [1047, 1047, 0.25, "square", 0.3]]),
        "gameover": Sfx.build([[440, 330, 0.25, "square", 0.3], [330, 220, 0.25, "square", 0.3],
            [220, 110, 0.5, "square", 0.3]]),
        "ufo": Sfx.build([[600, 1000, 0.12, "sine", 0.25], [1000, 600, 0.12, "sine", 0.25],
            [600, 1000, 0.12, "sine", 0.25], [1000, 600, 0.12, "sine", 0.25]]),
        "ufo_hit": Sfx.build([[900, 100, 0.5, "sine", 0.4], [300, 60, 0.4, "noise", 0.6]]),
        "pickup": Sfx.build([[600, 600, 0.06, "square", 0.25], [800, 800, 0.06, "square", 0.25],
            [1200, 1200, 0.1, "square", 0.25]]),
        "boss_hit": Sfx.build([[300, 150, 0.08, "square", 0.35], [150, 100, 0.05, "noise", 0.3]]),
        "boss_death": Sfx.build([[300, 40, 0.9, "noise", 0.8], [200, 30, 0.7, "square", 0.4],
            [100, 20, 0.5, "noise", 0.5]]),
        "shield": Sfx.build([[1200, 300, 0.2, "sine", 0.4], [500, 500, 0.08, "noise", 0.3]]),
    }
    ufo_player = AudioStreamPlayer.new()
    add_child(ufo_player)
    ufo_player.stream = sounds["ufo"]


func play(sound: String) -> void:
    var p := players[next_player]
    next_player = (next_player + 1) % players.size()
    p.stream = sounds[sound]
    p.play()


func start_game() -> void:
    level = 1
    score = 0
    lives = 3
    new_record = false
    intro_msg = ""
    rapid_t = 0.0
    spread_t = 0.0
    shield_t = 0.0
    drops.clear()
    effects.clear()
    texts.clear()
    play("start")
    start_level()


func start_level() -> void:
    aliens.clear()
    boss_active = false
    if level % 5 == 0:
        # Boss level instead of the normal wave
        boss_active = true
        boss_max = 30 + 15 * (level / 5 - 1)
        boss_hp = boss_max
        boss_x = W / 2.0
        boss_dir = 1
        boss_cd = 1.5
        boss_pattern = 0
        boss_flash = 0.0
    else:
        var rows := mini(3 + level, 6)
        var y0 := 60.0 + 10.0 * mini(level - 1, 4)
        for r in rows:
            for c in COLS:
                var a := Alien.new()
                a.row = r
                a.col = c
                a.pos = Vector2(80 + c * 44, y0 + r * 32)
                if (level >= 4 and r % 3 != 2) or (level >= 2 and r % 3 == 1):
                    a.tough = true
                    a.hp = 2
                aliens.append(a)
    total_aliens = maxi(aliens.size(), 1)
    alien_dir = 1
    step_timer = 0.0
    alien_bullets.clear()
    pbullets.clear()
    fire_cd = 0.0
    player_x = W / 2.0
    invuln = 0.0
    fire_timer = 1.0
    dive_timer = randf_range(3.0, 6.0)
    lost_life = false
    _build_bunkers()
    _ufo_leave()
    ufo_timer = randf_range(8.0, 15.0)
    state = State.INTRO
    intro_timer = 2.2 if intro_msg != "" else 1.5


func _build_bunkers() -> void:
    bunker_cells.resize(BUNKER_COUNT * BUNKER_COLS * BUNKER_ROWS)
    for b in BUNKER_COUNT:
        for r in BUNKER_ROWS:
            for c in BUNKER_COLS:
                var alive := 1
                if r == 0 and (c == 0 or c == BUNKER_COLS - 1):
                    alive = 0
                if r >= 5 and c >= 4 and c <= 6:
                    alive = 0
                bunker_cells[_cell_index(b, c, r)] = alive


func _cell_index(b: int, c: int, r: int) -> int:
    return (b * BUNKER_ROWS + r) * BUNKER_COLS + c


func _bunker_rect(b: int) -> Rect2:
    return Rect2(BUNKER_X0 + b * BUNKER_SPACING, BUNKER_Y, BUNKER_COLS * CELL, BUNKER_ROWS * CELL)


## Cell range [c0, c1, r0, r1] of bunker b overlapped by rect r
func _cell_range(b: int, r: Rect2) -> Array[int]:
    var br := _bunker_rect(b)
    var c0 := clampi(int(floor((r.position.x - br.position.x) / CELL)), 0, BUNKER_COLS - 1)
    var c1 := clampi(int(floor((r.end.x - br.position.x) / CELL)), 0, BUNKER_COLS - 1)
    var r0 := clampi(int(floor((r.position.y - br.position.y) / CELL)), 0, BUNKER_ROWS - 1)
    var r1 := clampi(int(floor((r.end.y - br.position.y) / CELL)), 0, BUNKER_ROWS - 1)
    return [c0, c1, r0, r1]


## A bullet hitting a bunker: destroys the first cell it touches plus some neighbours.
func _bunker_hit(r: Rect2, going_up: bool) -> bool:
    for b in BUNKER_COUNT:
        if not r.intersects(_bunker_rect(b)):
            continue
        var cr := _cell_range(b, r)
        var rows: Array[int] = []
        for row in range(cr[2], cr[3] + 1):
            rows.append(row)
        if going_up:
            rows.reverse()
        for row in rows:
            for c in range(cr[0], cr[1] + 1):
                if bunker_cells[_cell_index(b, c, row)] == 1:
                    _erode(b, c, row)
                    return true
    return false


func _erode(b: int, c: int, r: int) -> void:
    bunker_cells[_cell_index(b, c, r)] = 0
    for dr in range(-1, 2):
        for dc in range(-1, 2):
            var nc := c + dc
            var nr := r + dr
            if nc < 0 or nc >= BUNKER_COLS or nr < 0 or nr >= BUNKER_ROWS:
                continue
            if randf() < 0.4:
                bunker_cells[_cell_index(b, nc, nr)] = 0


## Aliens crushing through bunkers remove every cell they touch.
func _erode_rect(r: Rect2) -> void:
    if r.end.y < BUNKER_Y or r.position.y > BUNKER_Y + BUNKER_ROWS * CELL:
        return
    for b in BUNKER_COUNT:
        if not r.intersects(_bunker_rect(b)):
            continue
        var cr := _cell_range(b, r)
        for row in range(cr[2], cr[3] + 1):
            for c in range(cr[0], cr[1] + 1):
                bunker_cells[_cell_index(b, c, row)] = 0


func _to_title() -> void:
    if state == State.PLAYING or state == State.INTRO:
        Save.submit_score("invaders", score)
    state = State.TITLE
    paused = false
    _ufo_leave()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if state == State.TITLE:
            get_tree().change_scene_to_file("res://menu/menu.tscn")
        else:
            _to_title()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
        if state == State.PLAYING or state == State.INTRO:
            paused = not paused
            ufo_player.stream_paused = paused
        return
    if event.is_action_pressed("ui_accept") and (state == State.TITLE or state == State.GAME_OVER):
        start_game()


func _process(delta: float) -> void:
    if not paused:
        match state:
            State.INTRO:
                intro_timer -= delta
                if intro_timer <= 0.0:
                    state = State.PLAYING
                _update_effects(delta)
            State.PLAYING:
                _update_playing(delta)
                _update_effects(delta)
    queue_redraw()


func _update_effects(delta: float) -> void:
    for i in range(effects.size() - 1, -1, -1):
        effects[i][1] += delta
        if effects[i][1] > 0.3:
            effects.remove_at(i)
    for i in range(texts.size() - 1, -1, -1):
        texts[i][1] += delta
        if texts[i][1] > 1.0:
            texts.remove_at(i)


func _add_score(n: int) -> void:
    score += n
    hi_score = maxi(hi_score, score)


func _float_text(pos: Vector2, text: String, color: Color) -> void:
    texts.append([pos, 0.0, text, color])


func _update_playing(delta: float) -> void:
    # Player movement and shooting
    player_x = clampf(player_x + Input.get_axis("ui_left", "ui_right") * PLAYER_SPEED * delta,
        PLAYER_W / 2.0, W - PLAYER_W / 2.0)
    invuln = maxf(invuln - delta, 0.0)
    rapid_t = maxf(rapid_t - delta, 0.0)
    spread_t = maxf(spread_t - delta, 0.0)
    shield_t = maxf(shield_t - delta, 0.0)
    fire_cd -= delta
    _player_fire()
    _update_pbullets(delta)
    _update_drops(delta)
    _update_ufo(delta)
    if boss_active:
        _update_boss(delta)

    # Level cleared
    if aliens.is_empty() and not boss_active:
        _level_cleared()
        return

    # Alien marching: speeds up as fewer remain, and with level
    if not aliens.is_empty():
        var frac := float(aliens.size()) / total_aliens
        var interval := maxf(lerpf(0.04, 0.7, frac) / (1.0 + 0.2 * (level - 1)), 0.025)
        step_timer += delta
        if step_timer >= interval:
            step_timer = 0.0
            _alien_step()
            if state != State.PLAYING:
                return

    # Diving aliens break formation from level 3 on
    if level >= 3 and not aliens.is_empty():
        dive_timer -= delta
        if dive_timer <= 0.0:
            dive_timer = randf_range(3.0, 6.0) / (1.0 + 0.1 * (level - 3))
            var candidates: Array[Alien] = []
            for a in aliens:
                if not a.diving:
                    candidates.append(a)
            if candidates.size() > 3:
                var d: Alien = candidates.pick_random()
                d.diving = true
                d.dive_t = 0.0
                d.dive_x = d.pos.x
    _update_divers(delta)
    if state != State.PLAYING:
        return

    # Alien shooting: only the lowest alien in each column fires
    fire_timer -= delta
    if fire_timer <= 0.0:
        fire_timer = maxf(randf_range(0.4, 1.2) / (1.0 + 0.15 * (level - 1)), 0.2)
        var lowest := {}
        for a in aliens:
            if a.diving:
                continue
            if not lowest.has(a.col) or a.pos.y > lowest[a.col].pos.y:
                lowest[a.col] = a
        if not lowest.is_empty():
            var shooter: Alien = lowest.values().pick_random()
            var eb := EBullet.new()
            eb.pos = shooter.pos + Vector2(ALIEN_W / 2.0 - 1.5, ALIEN_H)
            eb.vel = Vector2(0, 180.0 + 20.0 * level)
            alien_bullets.append(eb)

    # Alien bullets
    var prect := Rect2(player_x - PLAYER_W / 2.0, PLAYER_Y, PLAYER_W, PLAYER_H)
    for i in range(alien_bullets.size() - 1, -1, -1):
        var eb := alien_bullets[i]
        eb.pos += eb.vel * delta
        var erect := Rect2(eb.pos, eb.size)
        if eb.pos.y > H or eb.pos.y < -20 or eb.pos.x < -20 or eb.pos.x > W + 20:
            alien_bullets.remove_at(i)
        elif _bunker_hit(erect, false):
            alien_bullets.remove_at(i)
        elif invuln <= 0.0 and erect.intersects(prect):
            _player_hit()
            return


func _player_fire() -> void:
    var spread := spread_t > 0.0
    var need := 3 if spread else 1
    var max_bullets := 3 if rapid_t > 0.0 else 1
    if spread:
        max_bullets *= 3
    if fire_cd > 0.0 or pbullets.size() + need > max_bullets or not Input.is_action_pressed(
        "ui_accept"):
        return
    fire_cd = 0.14 if rapid_t > 0.0 else 0.0
    var speeds: Array[float] = [0.0]
    if spread:
        speeds = [-90.0, 0.0, 90.0]
    for vx in speeds:
        var pb := PBullet.new()
        pb.pos = Vector2(player_x - 1.5, PLAYER_Y - 10)
        pb.vx = vx
        pbullets.append(pb)
    play("shoot")


func _update_pbullets(delta: float) -> void:
    for i in range(pbullets.size() - 1, -1, -1):
        var pb := pbullets[i]
        pb.pos.y -= 500.0 * delta
        pb.pos.x += pb.vx * delta
        if pb.pos.y < -10 or pb.pos.x < -10 or pb.pos.x > W + 10 or _pbullet_hits(pb):
            pbullets.remove_at(i)


## Returns true when the bullet is used up.
func _pbullet_hits(pb: PBullet) -> bool:
    var brect := Rect2(pb.pos, Vector2(3, 10))
    if _bunker_hit(brect, true):
        return true
    if ufo_active and brect.intersects(Rect2(ufo_x - 16, UFO_Y, 32, 14)):
        _ufo_killed()
        return true
    if boss_active and brect.intersects(Rect2(boss_x - BOSS_W / 2.0, BOSS_Y, BOSS_W, BOSS_H)):
        _boss_hit()
        return true
    for i in range(aliens.size() - 1, -1, -1):
        var a := aliens[i]
        if brect.intersects(Rect2(a.pos, Vector2(ALIEN_W, ALIEN_H))):
            a.hp -= 1
            if a.hp > 0:
                play("boss_hit")
            else:
                _kill_alien(i)
            return true
    return false


func _kill_alien(i: int) -> void:
    var a := aliens[i]
    var base: int = ROW_POINTS[a.row]
    if a.tough:
        base *= 2
    if a.diving:
        base += 150
    # Risk/reward: the lower the alien, the more it is worth (x1 to x4)
    var depth := clampf((a.pos.y - 60.0) / (PLAYER_Y - 60.0), 0.0, 1.0)
    var pts := base * (1 + int(depth * 3.99))
    _add_score(pts)
    var center := a.pos + Vector2(ALIEN_W, ALIEN_H) / 2.0
    effects.append([center, 0.0, _alien_color(a)])
    _float_text(center, "+%d" % pts, Color.WHITE)
    _maybe_drop(center, 0.1 if not a.diving else 0.3)
    aliens.remove_at(i)
    play("kill")


func _maybe_drop(pos: Vector2, chance: float) -> void:
    if randf() < chance:
        var d := Drop.new()
        d.pos = pos
        d.kind = randi() % 3
        drops.append(d)


func _update_drops(delta: float) -> void:
    var prect := Rect2(player_x - PLAYER_W / 2.0, PLAYER_Y, PLAYER_W, PLAYER_H)
    for i in range(drops.size() - 1, -1, -1):
        var d := drops[i]
        d.pos.y += 70.0 * delta
        if d.pos.y > H:
            drops.remove_at(i)
        elif Rect2(d.pos - Vector2(8, 8), Vector2(16, 16)).intersects(prect):
            match d.kind:
                P_RAPID:
                    rapid_t = POWER_TIME[P_RAPID]
                P_SPREAD:
                    spread_t = POWER_TIME[P_SPREAD]
                P_SHIELD:
                    shield_t = POWER_TIME[P_SHIELD]
            _float_text(Vector2(player_x, PLAYER_Y - 10), POWER_NAMES[d.kind], POWER_COLORS[d.kind])
            play("pickup")
            drops.remove_at(i)


func _update_ufo(delta: float) -> void:
    if ufo_active:
        ufo_x += ufo_dir * 110.0 * delta
        if ufo_x < -40.0 or ufo_x > W + 40.0:
            _ufo_leave()
            ufo_timer = randf_range(12.0, 25.0)
        elif not ufo_player.playing:
            ufo_player.play()  # warble loops while the UFO is on screen
    else:
        ufo_timer -= delta
        if ufo_timer <= 0.0:
            ufo_active = true
            ufo_dir = 1 if randf() < 0.5 else -1
            ufo_x = -30.0 if ufo_dir > 0 else W + 30.0
            ufo_player.play()


func _ufo_leave() -> void:
    ufo_active = false
    if ufo_player != null:
        ufo_player.stop()


func _ufo_killed() -> void:
    var options := [50, 100, 150, 200, 300]
    var pts: int = options.pick_random()
    _add_score(pts)
    var pos := Vector2(ufo_x, UFO_Y + 6)
    effects.append([pos, 0.0, Color.RED])
    _float_text(pos, "+%d" % pts, Color.RED)
    _maybe_drop(pos, 0.7)
    _ufo_leave()
    ufo_timer = randf_range(12.0, 25.0)
    play("ufo_hit")


func _update_boss(delta: float) -> void:
    boss_flash = maxf(boss_flash - delta, 0.0)
    var speed := 90.0 + 10.0 * (level / 5)
    boss_x += boss_dir * speed * delta
    if boss_x < BOSS_W / 2.0 + 10.0:
        boss_x = BOSS_W / 2.0 + 10.0
        boss_dir = 1
    elif boss_x > W - BOSS_W / 2.0 - 10.0:
        boss_x = W - BOSS_W / 2.0 - 10.0
        boss_dir = -1
    boss_cd -= delta
    if boss_cd <= 0.0:
        _boss_fire()
        var base := maxf(1.0 - 0.05 * mini(level / 5, 6), 0.45)
        boss_cd = base * (0.7 if boss_hp < boss_max / 2 else 1.0)


func _boss_bullet(origin: Vector2, vel: Vector2) -> void:
    var eb := EBullet.new()
    eb.size = Vector2(5, 5)
    eb.pos = origin - eb.size / 2.0
    eb.vel = vel
    eb.color = Color.MAGENTA
    alien_bullets.append(eb)


func _boss_fire() -> void:
    var origin := Vector2(boss_x, BOSS_Y + BOSS_H)
    var aim := (Vector2(player_x, PLAYER_Y) - origin).normalized()
    match boss_pattern % 3:
        0:  # single aimed shot
            _boss_bullet(origin, aim * 260.0)
        1:  # fan spread
            for k in range(-2, 3):
                _boss_bullet(origin, Vector2(0, 1).rotated(k * 0.35) * 200.0)
        2:  # aimed triple
            for k in range(-1, 2):
                _boss_bullet(origin, aim.rotated(k * 0.18) * 240.0)
    boss_pattern += 1


func _boss_hit() -> void:
    boss_hp -= 1
    boss_flash = 0.08
    if boss_hp > 0:
        play("boss_hit")
        return
    boss_active = false
    var pts := 1000 + 500 * level
    _add_score(pts)
    var pos := Vector2(boss_x, BOSS_Y + BOSS_H / 2.0)
    for k in 5:
        effects.append([pos + Vector2(randf_range(-45, 45), randf_range(-15, 15)), -0.05 * k,
            Color.ORANGE_RED])
    _float_text(pos, "+%d" % pts, Color.YELLOW)
    var d := Drop.new()
    d.pos = pos
    d.kind = randi() % 3
    drops.append(d)
    alien_bullets.clear()
    play("boss_death")


func _update_divers(delta: float) -> void:
    var prect := Rect2(player_x - PLAYER_W / 2.0, PLAYER_Y, PLAYER_W, PLAYER_H)
    for i in range(aliens.size() - 1, -1, -1):
        var a := aliens[i]
        if not a.diving:
            continue
        a.dive_t += delta
        a.dive_x += clampf(player_x - ALIEN_W / 2.0 - a.dive_x, -1.0, 1.0) * 40.0 * delta
        a.pos.x = clampf(a.dive_x + sin(a.dive_t * 4.0) * 50.0, 0.0, W - ALIEN_W)
        a.pos.y += 140.0 * delta
        var arect := Rect2(a.pos, Vector2(ALIEN_W, ALIEN_H))
        _erode_rect(arect)
        if a.pos.y > H:
            aliens.remove_at(i)
        elif invuln <= 0.0 and arect.intersects(prect):
            effects.append([a.pos + Vector2(ALIEN_W, ALIEN_H) / 2.0, 0.0, DIVER_COLOR])
            aliens.remove_at(i)
            _player_hit()
            return


func _level_cleared() -> void:
    intro_msg = ""
    if not lost_life:
        var bonus := 1000 * level
        _add_score(bonus)
        intro_msg = "FLAWLESS!  +%d" % bonus
    level += 1
    play("level")
    start_level()


func _alien_step() -> void:
    var hit_edge := false
    for a in aliens:
        if a.diving:
            continue
        var nx := a.pos.x + alien_dir * 8.0
        if nx < 10.0 or nx + ALIEN_W > W - 10.0:
            hit_edge = true
            break
    if hit_edge:
        alien_dir = -alien_dir
        for a in aliens:
            if not a.diving:
                a.pos.y += 16.0
    else:
        for a in aliens:
            if not a.diving:
                a.pos.x += alien_dir * 8.0
    alien_anim = not alien_anim
    play("step%d" % step_note)
    step_note = (step_note + 1) % 4
    for a in aliens:
        if a.diving:
            continue
        _erode_rect(Rect2(a.pos, Vector2(ALIEN_W, ALIEN_H)))
        if a.pos.y + ALIEN_H >= PLAYER_Y:
            _game_over()
            return


func _player_hit() -> void:
    alien_bullets.clear()
    if shield_t > 0.0:
        # The shield bubble absorbs the hit
        shield_t = 0.0
        invuln = 0.6
        effects.append([Vector2(player_x, PLAYER_Y + 8), 0.0, Color.CYAN])
        play("shield")
        return
    lives -= 1
    lost_life = true
    rapid_t = 0.0
    spread_t = 0.0
    play("hit")
    effects.append([Vector2(player_x, PLAYER_Y + 8), 0.0, Color.WHITE])
    if lives <= 0:
        _game_over()
    else:
        invuln = 1.5


func _game_over() -> void:
    state = State.GAME_OVER
    hi_score = maxi(hi_score, score)
    new_record = Save.submit_score("invaders", score)
    _ufo_leave()
    play("gameover")


func _text(text: String, y: float, size: int=20, color:=Color.WHITE) -> void:
    draw_string(ThemeDB.fallback_font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, W, size,
        color)


func _draw() -> void:
    draw_rect(Rect2(0, 0, W, H), Color.BLACK)
    for s in stars:
        draw_rect(Rect2(s, Vector2(1, 1)), Color(1, 1, 1, 0.5))

    if state == State.TITLE:
        _text("SPACE INVADERS", 170, 40, Color.LIME_GREEN)
        _text("Arrows: move    Space: fire    P: pause    Esc: back", 250, 16)
        _text("Power-ups: R rapid fire   S spread shot   B shield", 280, 14, Color.CYAN)
        _text("Press Enter or Space to start", 330, 22, Color.YELLOW)
        _text("High score: %d" % hi_score, 390, 16, Color.CYAN)
        return

    # HUD
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(10, 22), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
    _text("LEVEL %d    HI %d" % [level, hi_score], 22, 16)
    draw_string(font, Vector2(0, 22), "LIVES %d" % lives, HORIZONTAL_ALIGNMENT_RIGHT, W - 10, 16)
    draw_line(Vector2(0, PLAYER_Y + PLAYER_H + 6), Vector2(W, PLAYER_Y + PLAYER_H + 6), Color.GREEN,
        2)
    var hx := 10.0
    var timers := [rapid_t, spread_t, shield_t]
    for k in 3:
        var t: float = timers[k]
        if t > 0.0:
            var label: String = "%s %.1f" % [POWER_NAMES[k], t]
            draw_string(font, Vector2(hx, 476), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
                POWER_COLORS[k])
            hx += 110.0

    # Bunkers
    for b in BUNKER_COUNT:
        var br := _bunker_rect(b)
        for r in BUNKER_ROWS:
            for c in BUNKER_COLS:
                if bunker_cells[_cell_index(b, c, r)] == 1:
                    draw_rect(Rect2(br.position + Vector2(c, r) * CELL, Vector2(CELL, CELL)),
                        Color.LIME_GREEN.darkened(0.2))

    # UFO
    if ufo_active:
        var up := Vector2(ufo_x - 16, UFO_Y)
        draw_rect(Rect2(up + Vector2(8, 0), Vector2(16, 4)), Color.RED)
        draw_rect(Rect2(up + Vector2(0, 4), Vector2(32, 6)), Color.RED)
        draw_rect(Rect2(up + Vector2(4, 10), Vector2(6, 3)), Color.RED)
        draw_rect(Rect2(up + Vector2(22, 10), Vector2(6, 3)), Color.RED)
        for k in 3:
            draw_rect(Rect2(up + Vector2(6 + k * 8, 5), Vector2(4, 3)), Color.YELLOW)

    # Boss
    if boss_active:
        _draw_boss()

    # Aliens
    for a in aliens:
        _draw_alien(a)

    # Power-up drops
    for d in drops:
        var pc: Color = POWER_COLORS[d.kind]
        draw_rect(Rect2(d.pos - Vector2(8, 8), Vector2(16, 16)), Color(pc, 0.3))
        draw_rect(Rect2(d.pos - Vector2(8, 8), Vector2(16, 16)), pc, false, 2)
        draw_string(font, d.pos + Vector2(-8, 5), POWER_LETTERS[d.kind],
            HORIZONTAL_ALIGNMENT_CENTER, 16, 14, pc)

    # Player (blinks while invulnerable)
    if state != State.GAME_OVER and (invuln <= 0.0 or int(invuln * 10) % 2 == 0):
        var px := player_x - PLAYER_W / 2.0
        draw_rect(Rect2(px, PLAYER_Y + 8, PLAYER_W, 8), Color.GREEN_YELLOW)
        draw_rect(Rect2(player_x - 3, PLAYER_Y, 6, 8), Color.GREEN_YELLOW)
    if state != State.GAME_OVER and shield_t > 0.0 and (shield_t > 1.5 or int(
        shield_t * 8) % 2 == 0):
        var sc := Vector2(player_x, PLAYER_Y + 8)
        var glow := 0.6 + 0.3 * sin(Time.get_ticks_msec() / 80.0)
        draw_circle(sc, 22, Color(0.3, 0.8, 1.0, 0.15))
        draw_arc(sc, 22, 0, TAU, 24, Color(0.4, 0.9, 1.0, glow), 2)

    # Bullets
    for pb in pbullets:
        draw_rect(Rect2(pb.pos, Vector2(3, 10)), Color.WHITE)
    for eb in alien_bullets:
        draw_rect(Rect2(eb.pos, eb.size), eb.color)

    # Explosions
    for e in effects:
        var r: float = 4.0 + e[1] * 50.0
        var c: Color = e[2]
        c.a = 1.0 - e[1] / 0.3
        var p: Vector2 = e[0]
        draw_line(p - Vector2(r, 0), p + Vector2(r, 0), c, 2)
        draw_line(p - Vector2(0, r), p + Vector2(0, r), c, 2)
        draw_line(p - Vector2(r, r) * 0.7, p + Vector2(r, r) * 0.7, c, 2)
        draw_line(p - Vector2(r, -r) * 0.7, p + Vector2(r, -r) * 0.7, c, 2)

    # Floating score texts
    for t in texts:
        var tp: Vector2 = t[0]
        var age: float = t[1]
        var tc: Color = t[3]
        tc.a = 1.0 - age
        draw_string(font, Vector2(tp.x - 50, tp.y - age * 30.0), t[2], HORIZONTAL_ALIGNMENT_CENTER,
            100, 12, tc)

    if state == State.INTRO:
        _text("LEVEL %d" % level, H / 2.0, 36, Color.YELLOW)
        if boss_active:
            _text("BOSS!", H / 2.0 + 30, 24, Color.TOMATO)
        if intro_msg != "":
            _text(intro_msg, H / 2.0 + 60, 22, Color.CYAN)
    elif state == State.GAME_OVER:
        _text("GAME OVER", H / 2.0 - 20, 40, Color.TOMATO)
        if new_record:
            _text("NEW HIGH SCORE!", H / 2.0 + 5, 20, Color.YELLOW)
        _text("Score: %d" % score, H / 2.0 + 30, 20)
        _text("Enter: play again    Esc: title", H / 2.0 + 65, 16)

    if paused:
        draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
        _text("PAUSED - P resume, Esc title", H / 2.0, 24, Color.YELLOW)


func _alien_color(a: Alien) -> Color:
    if a.diving:
        return DIVER_COLOR
    if a.tough:
        return TOUGH_COLOR if a.hp > 1 else TOUGH_COLOR.darkened(0.45)
    return ROW_COLORS[a.row]


func _draw_alien(a: Alien) -> void:
    var c := _alien_color(a)
    var p := a.pos
    draw_rect(Rect2(p + Vector2(4, 0), Vector2(16, 4)), c)
    draw_rect(Rect2(p + Vector2(0, 4), Vector2(24, 8)), c)
    draw_rect(Rect2(p + Vector2(6, 6), Vector2(4, 3)), Color.BLACK)
    draw_rect(Rect2(p + Vector2(14, 6), Vector2(4, 3)), Color.BLACK)
    if a.tough:
        draw_rect(Rect2(p + Vector2(0, 0), Vector2(4, 4)), c)
        draw_rect(Rect2(p + Vector2(20, 0), Vector2(4, 4)), c)
    if alien_anim != a.diving:
        draw_rect(Rect2(p + Vector2(2, 12), Vector2(4, 4)), c)
        draw_rect(Rect2(p + Vector2(18, 12), Vector2(4, 4)), c)
    else:
        draw_rect(Rect2(p + Vector2(6, 12), Vector2(4, 4)), c)
        draw_rect(Rect2(p + Vector2(14, 12), Vector2(4, 4)), c)


func _draw_boss() -> void:
    var c := Color.WHITE if boss_flash > 0.0 else Color.CRIMSON
    var p := Vector2(boss_x - BOSS_W / 2.0, BOSS_Y)
    draw_rect(Rect2(p + Vector2(20, 0), Vector2(70, 8)), c)
    draw_rect(Rect2(p + Vector2(0, 8), Vector2(BOSS_W, 20)), c)
    draw_rect(Rect2(p + Vector2(8, 28), Vector2(14, 12)), c)
    draw_rect(Rect2(p + Vector2(48, 28), Vector2(14, 12)), c)
    draw_rect(Rect2(p + Vector2(88, 28), Vector2(14, 12)), c)
    draw_rect(Rect2(p + Vector2(24, 13), Vector2(14, 8)), Color.YELLOW)
    draw_rect(Rect2(p + Vector2(72, 13), Vector2(14, 8)), Color.YELLOW)
    # Health bar
    var frac := float(boss_hp) / boss_max
    draw_rect(Rect2(120, 30, 400, 6), Color(0.3, 0.0, 0.0))
    draw_rect(Rect2(120, 30, 400.0 * frac, 6), Color.RED)
    draw_rect(Rect2(120, 30, 400, 6), Color.WHITE, false, 1)
