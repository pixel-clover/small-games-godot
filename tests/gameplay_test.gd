extends SceneTree

const SnakeGame := preload("res://games/snake/snake.gd")
const InvadersGame := preload("res://games/space_invaders/invaders.gd")
const ForestWorld := preload("res://games/forest/forest_world.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
    create_timer(30.0).timeout.connect(
        func() -> void:
            push_error("Gameplay tests did not finish.")
            quit(1)
    )
    _run.call_deferred()


func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)


func _event(action: String) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = action
    event.pressed = true
    return event


func _run() -> void:
    var snake := SnakeGame.new()
    root.add_child(snake)
    snake.set_process(false)
    snake.wrap = false
    snake.food = Vector2i(30, 20)
    snake._unhandled_input(_event("ui_down"))
    snake._unhandled_input(_event("ui_right"))
    _check(snake.turns == [Vector2i.DOWN, Vector2i.RIGHT], "Both fast turns must be retained.")
    snake.queue_turn(Vector2i.UP)
    _check(snake.turns.size() == 2, "The input buffer must remain bounded.")
    var head: Vector2i = snake.snake[0]
    snake.step()
    snake.step()
    _check(
        snake.snake[0] == head + Vector2i.DOWN + Vector2i.RIGHT,
        "Buffered turns must execute on successive ticks."
    )
    snake.queue_turn(Vector2i.LEFT)
    _check(snake.turns.is_empty(), "Immediate reversal must be rejected.")
    snake.queue_turn(Vector2i.DOWN)
    snake.queue_turn(Vector2i.UP)
    _check(snake.turns == [Vector2i.DOWN], "Reversal against a queued turn must be rejected.")
    snake.turns.clear()
    snake.rocks = [snake.snake[0] + Vector2i.UP]
    snake.near_rewarded = false
    snake._reward_near_miss()
    var points: int = snake.score
    snake._reward_near_miss()
    _check(points > 0 and snake.score == points, "Near misses must not award repeated points.")
    snake.snake = [Vector2i(0, 10), Vector2i(0, 11), Vector2i(0, 12)]
    snake.rocks = [Vector2i(31, 10)]
    snake.wrap = true
    snake.near_rewarded = false
    snake._reward_near_miss()
    _check(snake.score > points, "Near misses must account for wrapped board edges.")
    snake.food = snake.snake[0] + Vector2i.RIGHT
    snake.combo = 2
    snake.combo_left = 1.0
    snake.step()
    _check(
        not snake.near_rewarded and snake.swallow_age == 0.0,
        "Eating must reset near-miss eligibility and start the body ripple."
    )
    var eat_player := snake.players[(snake.next_player + 3) % 4]
    _check(
        is_equal_approx(eat_player.pitch_scale, pow(2.0, 4.0 / 12.0)),
        "The third combo step must use the third major pentatonic note."
    )
    snake.paused = true
    head = snake.snake[0]
    snake._process(1.0)
    _check(snake.snake[0] == head, "Pause must halt Snake simulation.")
    snake.paused = false
    snake.score = 0
    snake.end_game()
    for i in 3:
        snake._process(1.0 / 60.0)
    _check(
        snake.death_age == 0.0 and snake.death_freeze == 0,
        "The death sequence must freeze for three frames."
    )
    snake.score = 50
    for i in 60:
        snake._process(0.07)
    _check(snake.final_score == 50, "The final score must count up without overshooting.")
    snake.reset_game()
    _check(
        snake.turns.is_empty() and snake.final_score == 0 and snake.death_freeze == 0,
        "Restart must clear buffered inputs and death feedback."
    )
    snake.free()

    var invaders := InvadersGame.new()
    root.add_child(invaders)
    invaders.set_process(false)
    invaders.start_game()
    invaders.state = InvadersGame.State.PLAYING
    Input.action_press("ui_accept")
    invaders._player_fire()
    Input.action_release("ui_accept")
    _check(
        invaders.recoil_left > 0.0 and invaders.muzzle_frames == 1,
        "Firing must trigger recoil and a one-frame muzzle flash."
    )
    invaders.pbullets.clear()
    var alien := InvadersGame.Alien.new()
    alien.pos = Vector2(300, 160)
    alien.row = 0
    alien.col = 0
    alien.tough = true
    alien.hp = 2
    invaders.aliens = [alien]
    var bullet := InvadersGame.PBullet.new()
    bullet.pos = alien.pos + Vector2(10, 5)
    _check(
        invaders._pbullet_hits(bullet) and alien.hp == 1 and invaders.hit_stop_frames == 2,
        "Tough alien hits must trigger two frames of hit stop."
    )
    var cooldown: float = invaders.fire_cd
    for i in 2:
        invaders._process(1.0)
    _check(
        invaders.fire_cd == cooldown and invaders.hit_stop_frames == 0,
        "Hit stop must freeze simulation timers for exactly two frames."
    )
    invaders.hit_stop_frames = 2
    invaders.paused = true
    invaders._process(1.0)
    _check(invaders.hit_stop_frames == 2, "Pause must retain pending hit-stop frames.")
    invaders.paused = false
    invaders.hit_stop_frames = 0
    alien.pos = Vector2(invaders.player_x - 12, invaders.PLAYER_Y - 50)
    invaders.fire_cd = 0.14
    invaders._kill_alien(0)
    _check(invaders.fire_cd == 0.0, "Close kills must reset rapid-fire cooldown.")
    invaders._build_bunkers()
    _check(
        invaders._bunker_color(0) == Color.LIME_GREEN.darkened(0.2),
        "An intact bunker must be green."
    )
    for i in 50:
        invaders.bunker_cells[i] = 0
    _check(invaders._bunker_color(0) == Color.GOLD, "A damaged bunker must be yellow.")
    for i in invaders.BUNKER_COLS * invaders.BUNKER_ROWS:
        invaders.bunker_cells[i] = 0
    _check(invaders._bunker_color(0) == Color.TOMATO, "A depleted bunker must be red.")
    invaders.level = 5
    invaders.start_level()
    invaders.boss_pattern = 1
    invaders.boss_cd = 0.1
    invaders._update_boss(0.05)
    _check(
        invaders.boss_warned and invaders.alien_bullets.is_empty(),
        "Boss spreads must warn before firing."
    )
    invaders._update_boss(0.15)
    _check(
        invaders.alien_bullets.is_empty(), "Boss warning must last the full anticipation period."
    )
    invaders._update_boss(0.16)
    _check(
        invaders.alien_bullets.size() == 5 and not invaders.boss_warned,
        "Boss spreads must fire once after their warning."
    )
    invaders.lost_life = false
    points = invaders.score
    invaders._level_cleared()
    _check(
        invaders.score == points + 5000 and invaders.celebration_left > 0.0,
        "Flawless waves must award the bonus and celebration."
    )
    invaders.lost_life = true
    invaders.celebration_left = 0.0
    points = invaders.score
    invaders._level_cleared()
    _check(
        invaders.score == points and invaders.celebration_left == 0.0,
        "Damaged waves must not award a flawless bonus."
    )
    invaders.free()

    var forest := ForestWorld.new()
    forest.no_save = true
    root.add_child(forest)
    forest.set_process(false)
    forest.found_ids.clear()
    forest.found_counts.clear()
    forest._discover({"id": "test_shrine", "kind": "shrine", "x": 10.0, "y": 152.0})
    _check(
        forest.discovery_left == 0.5 and forest.sparks.size() == 22,
        "A new discovery must pause movement and spawn sparks."
    )
    forest.discovery_left = 0.2
    forest._discover({"id": "test_shrine", "kind": "shrine", "x": 10.0, "y": 152.0})
    _check(
        forest.discovery_left == 0.2 and forest._total_found() == 1,
        "Rediscovering the same object must not restart the pause or count twice."
    )
    var pos: Vector2 = forest.player_pos
    Input.action_press("ui_right")
    forest._process(0.1)
    Input.action_release("ui_right")
    _check(forest.player_pos == pos, "Discovery pause must prevent held movement input.")
    forest.cur_biome = 2
    forest.vis_flat.clear()
    _check(forest._terrain() == 2, "Bog footsteps must use the splash sound.")
    forest.cur_biome = 0
    forest.player_pos.y = forest._path_y(forest.player_pos.x)
    _check(forest._terrain() == 0, "Path footsteps must use the dirt sound.")
    forest.player_pos.y += 12.0
    _check(forest._terrain() == 1, "Off-path footsteps must use the grass sound.")
    forest.snd = {
        "shrine_cue": Sfx.build([[1047, 1047, 0.05, "sine", 0.1]]),
        "pond_cue": Sfx.build([[200, 100, 0.05, "sine", 0.1]]),
    }
    forest.vis_special = [
        {
            "id": "cue_shrine",
            "kind": "shrine",
            "x": forest.player_pos.x + 80.0,
            "y": forest.player_pos.y
        }
    ]
    forest.breadcrumb_timer = 0.0
    forest._update_breadcrumbs(0.1)
    _check(
        (
            forest.landmark_player.stream == forest.snd["shrine_cue"]
            and forest.landmark_player.position.x > 160.0
        ),
        "Undiscovered landmarks must play spatial cues toward the object."
    )
    forest.landmark_player.stop()
    forest.landmark_player.stream = null
    forest.found_ids["cue_shrine"] = true
    forest.breadcrumb_timer = 0.0
    forest._update_breadcrumbs(0.1)
    _check(
        forest.landmark_player.stream == null,
        "Discovered landmarks must stop offering audio breadcrumbs."
    )
    forest.snd.clear()
    forest.audio_from = PackedFloat32Array([1, 0, 0, 0, 0])
    forest.cur_biome = 1
    forest.audio_fade = 0.0
    forest._blend_audio(1.5)
    _check(
        (
            is_equal_approx(forest.audio_weights[0], 0.5)
            and is_equal_approx(forest.audio_weights[1], 0.5)
        ),
        "Biome audio must crossfade over three seconds."
    )
    forest._blend_audio(1.5)
    _check(is_equal_approx(forest.audio_weights[1], 1.0), "Biome audio must reach its new target.")
    forest.audio_weights = PackedFloat32Array([0.5, 0.5, 0, 0, 0])
    forest.cur_biome = 1
    forest._goto_biome(4)
    forest._update_biome()
    forest._blend_audio(0.0)
    _check(
        (
            is_equal_approx(forest.audio_weights[0], 0.5)
            and is_equal_approx(forest.audio_weights[1], 0.5)
        ),
        "Crossing another biome during a fade must preserve the current mix."
    )
    forest.lantern_offset = Vector2(4, -2)
    forest.lantern_velocity = Vector2.ZERO
    forest.vel = Vector2.ZERO
    forest.moving = false
    forest.discovery_left = 0.0
    for i in 180:
        forest._update_lantern(1.0 / 60.0)
    _check(forest.lantern_offset.length() < 0.01, "The lantern spring must settle after stopping.")
    forest.vel.x = 38.0
    forest._update_lantern(0.1)
    _check(
        forest.lantern_offset.x < 0.0,
        "The lantern must lag behind the wanderer when movement starts."
    )
    forest.moving = true
    forest.fuel = 1.0
    forest._update_ui(1.0)
    _check(forest.hud_alpha == 0.0, "The HUD must hide during continuous walking.")
    forest.fuel = 0.1
    forest._update_ui(1.0)
    _check(forest.hud_alpha == 1.0, "Low fuel must reveal the HUD.")
    forest.journal_open = true
    forest._update_ui(0.3)
    _check(forest.journal_amount == 1.0, "The journal must finish opening.")
    pos = forest.player_pos
    forest._process(0.1)
    _check(forest.player_pos == pos, "The journal must halt movement.")
    _check(forest.journal_icons.size() == 4, "Journal ink textures must be cached during setup.")
    forest.queue_free()
    await process_frame

    var noise := [[200, 100, 0.02, "noise", 0.2]]
    var first_noise := Sfx.build(noise)
    var second_noise := Sfx.build(noise)
    _check(
        first_noise.data == second_noise.data,
        "Procedural effects must produce deterministic audio."
    )
    var steps := ForestAudio.footsteps()
    _check(
        steps.size() == 3 and steps[0].data != steps[1].data and steps[1].data != steps[2].data,
        "Dirt, grass, and bog footsteps must have distinct timbres."
    )

    await _test_transitions()
    current_scene.queue_free()
    await process_frame
    # Let the audio server release playback instances before engine shutdown.
    await create_timer(0.1).timeout
    print("Gameplay checks: %d passed, %d failed." % [checks - failures, failures])
    quit(1 if failures > 0 else 0)


func _test_transitions() -> void:
    for path in [
        "res://games/snake/snake.tscn",
        "res://games/space_invaders/invaders.tscn",
        "res://games/forest/forest.tscn"
    ]:
        change_scene_to_file("res://menu/menu.tscn")
        await process_frame
        await process_frame
        current_scene.call("_activate", path)
        await create_timer(0.3).timeout
        _check(current_scene.scene_file_path == path, "Launcher must open " + path)
        if path.contains("forest"):
            var container := current_scene.get("container") as SubViewportContainer
            var world := container.get_child(0).get_child(0)
            world.set("no_save", true)
            Input.action_press("ui_cancel")
            world.call("_process", 1.0 / 60.0)
            Input.action_release("ui_cancel")
        else:
            current_scene.call("_unhandled_input", _event("ui_cancel"))
        await process_frame
        await process_frame
        _check(
            current_scene.scene_file_path == "res://menu/menu.tscn",
            "Escape must return to the launcher from " + path
        )
