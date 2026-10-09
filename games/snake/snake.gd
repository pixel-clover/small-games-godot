extends Node2D

const CELL := 20
const GRID := Vector2i(32, 24)  # 640x480 playfield
const STEP_TIME := 0.12
const MIN_STEP_TIME := 0.06
const STEP_DECREASE := 0.002  # seconds shaved off per food
const SLOW_FACTOR := 1.8  # step time multiplier while slow-motion is active

const FOOD_POINTS := 10
const BONUS_MULT := 5
const BONUS_TIME := 6.0
const POWER_TIME_SLOW := 5.0
const POWER_TIME_DOUBLE := 8.0
const POWER_LIFETIME := 8.0  # how long an uncollected power-up stays
const COMBO_TIME := 3.0
const MAX_COMBO := 5
const MAX_ROCKS := 14
const SAFE_ZONE := 5  # cells ahead of the head that never get rocks
const COMBO_NOTES := [0, 2, 4, 7, 9]

var snake: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var turns: Array[Vector2i] = []
var food := Vector2i.ZERO
var score := 0
var game_over := false
var timer := 0.0

var started := false
var paused := false
var wrap := false
var high_score := 0
var new_record := false
var foods_eaten := 0

var bonus_active := false
var bonus_pos := Vector2i.ZERO
var bonus_left := 0.0
var foods_until_bonus := 4

var rocks: Array[Vector2i] = []

var power_active := false
var power_pos := Vector2i.ZERO
var power_kind := "slow"  # "slow" or "double"
var power_left := 0.0
var power_spawn_in := 10.0
var slow_left := 0.0
var double_left := 0.0

var combo := 1
var combo_left := 0.0
var move_age := 1.0
var swallow_age := 99.0
var near_rewarded := false
var sparkle_pos := Vector2.ZERO
var sparkle_left := 0.0
var death_freeze := 0
var death_age := 0.0
var final_score := 0
var count_timer := 0.0
var record_target := 10

var players: Array[AudioStreamPlayer] = []
var next_player := 0
var sounds: Dictionary = {}


func _ready() -> void:
    get_window().size = GRID * CELL
    wrap = bool(Save.get_value("snake", "wrap", false))
    for i in 4:
        var p := AudioStreamPlayer.new()
        add_child(p)
        players.append(p)
    sounds = {
        "eat": Sfx.build([[500, 800, 0.08, "square", 0.25]]),
        "bonus": Sfx.build([[700, 700, 0.07, "square", 0.25], [900, 900, 0.07, "square", 0.25],
            [1200, 1200, 0.12, "square", 0.25]]),
        "power": Sfx.build([[400, 900, 0.2, "sine", 0.4]]),
        "tick": Sfx.build([[880, 880, 0.025, "sine", 0.15]]),
        "near": Sfx.build([[1200, 1600, 0.05, "sine", 0.15]]),
        "gameover": Sfx.build([[440, 330, 0.2, "square", 0.3], [330, 220, 0.2, "square", 0.3],
            [220, 110, 0.4, "square", 0.3]]),
    }
    reset_game()


func play(sound: String, pitch: float=1.0) -> void:
    var p := players[next_player]
    next_player = (next_player + 1) % players.size()
    p.stream = sounds[sound]
    p.pitch_scale = pitch
    p.play()


func game_key() -> String:
    return "snake_wrap" if wrap else "snake"


func reset_game() -> void:
    var start := GRID / 2
    snake = [start, start - Vector2i.RIGHT, start - Vector2i.RIGHT * 2]
    direction = Vector2i.RIGHT
    turns.clear()
    score = 0
    game_over = false
    started = false
    paused = false
    new_record = false
    timer = 0.0
    foods_eaten = 0
    bonus_active = false
    foods_until_bonus = randi_range(4, 5)
    rocks.clear()
    power_active = false
    power_spawn_in = randf_range(10.0, 16.0)
    slow_left = 0.0
    double_left = 0.0
    combo = 1
    combo_left = 0.0
    move_age = 1.0
    swallow_age = 99.0
    near_rewarded = false
    sparkle_left = 0.0
    death_freeze = 0
    death_age = 0.0
    final_score = 0
    count_timer = 0.0
    high_score = Save.get_high(game_key())
    record_target = maxi(high_score, FOOD_POINTS)
    spawn_food()
    queue_redraw()


## Free cells: not snake, food, bonus, power-up or rock
func free_cells() -> Array[Vector2i]:
    var free: Array[Vector2i] = []
    for x in GRID.x:
        for y in GRID.y:
            var c := Vector2i(x, y)
            if snake.has(c) or rocks.has(c) or c == food:
                continue
            if (bonus_active and c == bonus_pos) or (power_active and c == power_pos):
                continue
            free.append(c)
    return free


func spawn_food() -> void:
    var free := free_cells()
    if free.is_empty():
        end_game()
        return
    food = free.pick_random()


func spawn_bonus() -> void:
    var free := free_cells()
    if free.is_empty():
        return
    bonus_pos = free.pick_random()
    bonus_left = BONUS_TIME
    bonus_active = true


func spawn_power() -> void:
    var free := free_cells()
    if free.is_empty():
        return
    power_pos = free.pick_random()
    power_kind = "slow" if randf() < 0.5 else "double"
    power_left = POWER_LIFETIME
    power_active = true


func spawn_rocks(count: int) -> void:
    # Keep a safe zone in front of the head
    var danger: Array[Vector2i] = []
    for k in range(1, SAFE_ZONE + 1):
        danger.append(wrap_cell(snake[0] + direction * k))
    for i in count:
        if rocks.size() >= MAX_ROCKS:
            return
        var free := free_cells()
        free = free.filter(func(c: Vector2i) -> bool: return not danger.has(c))
        if free.size() < 20:
            return
        rocks.append(free.pick_random())


func wrap_cell(c: Vector2i) -> Vector2i:
    return Vector2i(posmod(c.x, GRID.x), posmod(c.y, GRID.y))


func end_game() -> void:
    if game_over:
        return
    game_over = true
    death_freeze = 3
    new_record = Save.submit_score(game_key(), score)
    if new_record:
        high_score = score
    play("gameover")
    queue_redraw()


func toggle_wrap() -> void:
    wrap = not wrap
    Save.set_value("snake", "wrap", wrap)
    reset_game()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_tree().change_scene_to_file("res://menu/menu.tscn")
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_W and (not started or game_over):
            toggle_wrap()
            return
        if event.keycode == KEY_P and started and not game_over:
            paused = not paused
            queue_redraw()
            return
    if game_over:
        if event.is_action_pressed("ui_accept"):
            reset_game()
        return
    if paused:
        return
    var new_dir := direction
    if event.is_action_pressed("ui_up"):
        new_dir = Vector2i.UP
    elif event.is_action_pressed("ui_down"):
        new_dir = Vector2i.DOWN
    elif event.is_action_pressed("ui_left"):
        new_dir = Vector2i.LEFT
    elif event.is_action_pressed("ui_right"):
        new_dir = Vector2i.RIGHT
    else:
        return
    queue_turn(new_dir)
    started = true


func queue_turn(new_dir: Vector2i) -> void:
    var previous: Vector2i = direction if turns.is_empty() else turns.back()
    if turns.size() < 2 and new_dir != previous and new_dir != -previous:
        turns.append(new_dir)


func step_time() -> float:
    var t := maxf(MIN_STEP_TIME, STEP_TIME - foods_eaten * STEP_DECREASE)
    if slow_left > 0.0:
        t *= SLOW_FACTOR
    return t


func _process(delta: float) -> void:
    if paused:
        return
    if game_over:
        _update_death(delta)
        queue_redraw()
        return
    if not started:
        return
    move_age += delta
    swallow_age += delta
    sparkle_left = maxf(0.0, sparkle_left - delta)
    # Timed things
    if combo_left > 0.0:
        combo_left -= delta
        if combo_left <= 0.0:
            combo = 1
    slow_left = maxf(slow_left - delta, 0.0)
    double_left = maxf(double_left - delta, 0.0)
    if bonus_active:
        bonus_left -= delta
        if bonus_left <= 0.0:
            bonus_active = false
    if power_active:
        power_left -= delta
        if power_left <= 0.0:
            power_active = false
    else:
        power_spawn_in -= delta
        if power_spawn_in <= 0.0:
            spawn_power()
            power_spawn_in = randf_range(12.0, 20.0)
    timer += delta
    var st := step_time()
    if timer >= st:
        timer -= st
        step()
    queue_redraw()


func _update_death(delta: float) -> void:
    if death_freeze > 0:
        death_freeze -= 1
        return
    death_age += delta
    if death_age < snake.size() * 0.04 or final_score >= score:
        return
    count_timer += delta
    if count_timer >= 0.07:
        count_timer = fmod(count_timer, 0.07)
        final_score = mini(score, final_score + maxi(1, ceili(score / 20.0)))
        play("tick")


func add_points(base: int) -> void:
    var mult := 2 if double_left > 0.0 else 1
    score += base * combo * mult


func step() -> void:
    if not turns.is_empty():
        direction = turns.pop_front()
    move_age = 0.0
    var head := snake[0] + direction
    if wrap:
        head = wrap_cell(head)
    var growing := head == food or (bonus_active and head == bonus_pos)
    # The tail moves away this step unless we're growing
    var body := snake if growing else snake.slice(0, snake.size() - 1)
    if head.x < 0 or head.y < 0 or head.x >= GRID.x or head.y >= GRID.y or body.has(
        head) or rocks.has(head):
        end_game()
        return
    snake.push_front(head)
    if head == food:
        combo = mini(combo + 1, MAX_COMBO) if combo_left > 0.0 else 1
        combo_left = COMBO_TIME
        add_points(FOOD_POINTS)
        foods_eaten += 1
        near_rewarded = false
        swallow_age = 0.0
        foods_until_bonus -= 1
        play("eat", pow(2.0, COMBO_NOTES[combo - 1] / 12.0))
        if foods_eaten % 5 == 0:
            spawn_rocks(randi_range(1, 2))
        spawn_food()
        if foods_until_bonus <= 0 and not bonus_active:
            spawn_bonus()
            foods_until_bonus = randi_range(4, 5)
    elif bonus_active and head == bonus_pos:
        combo = mini(combo + 1, MAX_COMBO) if combo_left > 0.0 else 1
        combo_left = COMBO_TIME
        add_points(FOOD_POINTS * BONUS_MULT)
        bonus_active = false
        near_rewarded = false
        swallow_age = 0.0
        play("bonus")
    else:
        snake.pop_back()
        if power_active and head == power_pos:
            power_active = false
            if power_kind == "slow":
                slow_left = POWER_TIME_SLOW
            else:
                double_left = POWER_TIME_DOUBLE
            add_points(FOOD_POINTS)
            play("power")
    _reward_near_miss()
    queue_redraw()


func _reward_near_miss() -> void:
    if near_rewarded:
        return
    var head := snake[0]
    var hazards: Array[Vector2i] = rocks.duplicate()
    # Skip the neck, which is always adjacent to the head.
    hazards.append_array(snake.slice(3))
    for hazard in hazards:
        var dx := absi(head.x - hazard.x)
        var dy := absi(head.y - hazard.y)
        if wrap:
            dx = mini(dx, GRID.x - dx)
            dy = mini(dy, GRID.y - dy)
        if dx + dy == 1:
            near_rewarded = true
            add_points(2)
            sparkle_pos = Vector2(head * CELL) + Vector2.ONE * CELL / 2.0
            sparkle_left = 0.35
            play("near")
            return


func cell_rect(c: Vector2i, inset: float=1.0) -> Rect2:
    return Rect2(Vector2(c * CELL) + Vector2.ONE * inset, Vector2.ONE * (CELL - inset * 2.0))


func draw_bar(pos: Vector2, size: Vector2, frac: float, color: Color) -> void:
    draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.5))
    draw_rect(Rect2(pos, Vector2(size.x * clampf(frac, 0.0, 1.0), size.y)), color)


func _draw() -> void:
    var font := ThemeDB.fallback_font
    var w := GRID.x * CELL
    var h := GRID.y * CELL
    draw_rect(Rect2(Vector2.ZERO, GRID * CELL), Color(0.07, 0.09, 0.11))
    # Subtle checkerboard
    for x in GRID.x:
        for y in GRID.y:
            if (x + y) % 2 == 0:
                draw_rect(Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL), Color(1, 1, 1, 0.025))
    if not wrap:
        draw_rect(Rect2(Vector2.ZERO, GRID * CELL), Color(0.8, 0.3, 0.3, 0.6), false, 3.0)
    # Rocks
    for r in rocks:
        draw_rect(cell_rect(r, 1.0), Color(0.45, 0.45, 0.5))
        draw_rect(cell_rect(r, 4.0), Color(0.6, 0.6, 0.66))
    # Food
    draw_circle(Vector2(food * CELL) + Vector2.ONE * CELL / 2.0, CELL / 2.0 - 2.0, Color.TOMATO)
    # Bonus with shrinking countdown ring
    if bonus_active:
        var bc := Vector2(bonus_pos * CELL) + Vector2.ONE * CELL / 2.0
        draw_circle(bc, CELL / 2.0 - 3.0, Color.GOLD)
        draw_arc(bc, CELL / 2.0 + 2.0, -PI / 2.0, -PI / 2.0 + TAU * bonus_left / BONUS_TIME, 32,
            Color.YELLOW, 2.0)
    # Power-up
    if power_active:
        var pc := Vector2(power_pos * CELL) + Vector2.ONE * CELL / 2.0
        var col := Color.DODGER_BLUE if power_kind == "slow" else Color.MEDIUM_ORCHID
        var blink := power_left > 2.5 or int(power_left * 6.0) % 2 == 0
        if blink:
            draw_rect(cell_rect(power_pos, 2.0), col)
            draw_string(font, pc + Vector2(-4, 5), "S" if power_kind == "slow" else "x2",
                HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
        draw_arc(pc, CELL / 2.0 + 2.0, -PI / 2.0,
            -PI / 2.0 + TAU * power_left / POWER_LIFETIME, 32, col, 2.0)
    # Snake
    for i in snake.size():
        if game_over and death_freeze == 0 and i < int(death_age / 0.04):
            var origin := cell_rect(snake[i]).get_center()
            var crumble := clampf((death_age - i * 0.04) / 0.25, 0.0, 1.0)
            if crumble < 1.0:
                for k in 4:
                    var offset := Vector2(-1 if k % 2 == 0 else 1, -1 if k < 2 else 1)
                    draw_rect(Rect2(origin + offset * (3.0 + crumble * 12.0), Vector2.ONE * 4),
                        Color(0.3, 0.8, 0.4, 1.0 - crumble))
            continue
        var color := Color(0.2, 0.75, 0.3) if i > 0 else Color.GREEN_YELLOW
        if slow_left > 0.0:
            color = color.lerp(Color.DODGER_BLUE, 0.5)
        if double_left > 0.0:
            color = color.lerp(Color.MEDIUM_ORCHID, 0.4)
        var rect := cell_rect(snake[i])
        if not game_over:
            if i == 0:
                var stretch := maxf(0.0, 1.0 - move_age / 0.08) * 3.0
                rect.position += Vector2(direction) * stretch * 0.5
                rect = rect.grow_individual(stretch if direction.x != 0 else 0.0,
                    stretch if direction.y != 0 else 0.0,
                    stretch if direction.x != 0 else 0.0, stretch if direction.y != 0 else 0.0)
            var ripple := swallow_age - i * 0.025
            if ripple >= 0.0 and ripple < 0.15:
                rect = rect.grow(sin(ripple / 0.15 * PI) * 2.0)
        draw_rect(rect, color)
        if slow_left > 0.0 or double_left > 0.0:
            draw_rect(rect.grow(1.0), Color.MEDIUM_ORCHID if double_left > 0.0
                else Color.DODGER_BLUE, false, 1.5)
    if sparkle_left > 0.0:
        for k in 6:
            var p := sparkle_pos + Vector2.RIGHT.rotated(k * TAU / 6.0) * \
                (1.0 - sparkle_left / 0.35) * 22.0
            draw_line(p - Vector2(2, 0), p + Vector2(2, 0), Color(1, 1, 0.6, sparkle_left / 0.35))
    # HUD
    var mode := "Wrap" if wrap else "Walls"
    draw_string(font, Vector2(8, 20), "Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
    draw_string(font, Vector2(0, 20), "Best (%s): %d" % [mode, high_score],
        HORIZONTAL_ALIGNMENT_RIGHT, w - 8, 16)
    var score_scale := maxf(record_target * 1.25, score)
    draw_bar(Vector2(220, 28), Vector2(180, 5), score / score_scale, Color.GREEN)
    var marker := 220.0 + 180.0 * record_target / score_scale
    draw_line(Vector2(marker, 26), Vector2(marker, 35), Color(1, 1, 1, 0.5))
    var combo_text := "Combo x%d" % combo
    draw_string(font, Vector2(8, 40), combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.ORANGE)
    draw_bar(Vector2(90, 30), Vector2(70, 8),
        combo_left / COMBO_TIME if combo > 1 or combo_left > 0.0 else 0.0, Color.ORANGE)
    var hy := 58.0
    if slow_left > 0.0:
        draw_string(font, Vector2(8, hy), "Slow", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
            Color.DODGER_BLUE)
        draw_bar(Vector2(90, hy - 9), Vector2(70, 8), slow_left / POWER_TIME_SLOW,
            Color.DODGER_BLUE)
        hy += 18.0
    if double_left > 0.0:
        draw_string(font, Vector2(8, hy), "Score x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
            Color.MEDIUM_ORCHID)
        draw_bar(Vector2(90, hy - 9), Vector2(70, 8), double_left / POWER_TIME_DOUBLE,
            Color.MEDIUM_ORCHID)
    if not started and not game_over:
        draw_string(font, Vector2(0, h / 2.0 - 50),
            "Press an arrow key to start  (W: toggle wrap mode)",
            HORIZONTAL_ALIGNMENT_CENTER, w, 20)
        draw_string(font, Vector2(0, h / 2.0 - 24), "Mode: %s   P: pause   Esc: menu" % mode,
            HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(0.8, 0.8, 0.8))
    if paused:
        draw_rect(Rect2(Vector2.ZERO, GRID * CELL), Color(0, 0, 0, 0.6))
        draw_string(font, Vector2(0, h / 2.0), "PAUSED - P resume, Esc menu",
            HORIZONTAL_ALIGNMENT_CENTER, w, 24)
    if game_over and death_freeze == 0:
        draw_rect(Rect2(Vector2.ZERO, GRID * CELL), Color(0, 0, 0, 0.5))
        draw_string(font, Vector2(0, h / 2.0), "Game Over - press Enter to restart",
            HORIZONTAL_ALIGNMENT_CENTER, w, 24)
        draw_string(font, Vector2(0, h / 2.0 + 28), "Score: %d" % final_score,
            HORIZONTAL_ALIGNMENT_CENTER, w, 18)
        if new_record:
            draw_string(font, Vector2(0, h / 2.0 + 54), "New record!", HORIZONTAL_ALIGNMENT_CENTER,
                w, 20, Color.GOLD)
        draw_string(font, Vector2(0, h / 2.0 + 80), "W: toggle wrap mode (now %s)" % mode,
            HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0.8, 0.8, 0.8))
