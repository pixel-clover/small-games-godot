extends SceneTree

const SnakeGame := preload("res://games/snake/snake.gd")
const InvadersGame := preload("res://games/space_invaders/invaders.gd")
const ForestWorld := preload("res://games/forest/forest_world.gd")
const BreachGame := preload("res://games/neon_breach/breach.gd")

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


func _button(button: JoyButton, pressed: bool=true, device: int=0) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.button_index = button
    event.pressed = pressed
    event.device = device
    return event


func _motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
    var event := InputEventJoypadMotion.new()
    event.axis = axis
    event.axis_value = value
    return event


func _send(event: InputEvent) -> void:
    Input.parse_input_event(event)
    Input.flush_buffered_events()


func _run() -> void:
    _test_forest_art()
    _check((ThemeDB.fallback_font as FontFile).multichannel_signed_distance_field,
        "The UI font must remain smooth when scaled.")
    for binding in [
        ["ui_accept", JOY_BUTTON_A],
        ["ui_cancel", JOY_BUTTON_B],
        ["pause", JOY_BUTTON_START],
        ["wrap_mode", JOY_BUTTON_X],
        ["journal", JOY_BUTTON_X],
        ["run", JOY_BUTTON_RIGHT_SHOULDER],
        ["advance_time", JOY_BUTTON_Y]
    ]:
        _check(
            _button(binding[1], true, 1).is_action_pressed(binding[0]),
            "Controller bindings must work on any connected device: " + str(binding[0])
        )
    for binding in [
        ["ui_accept", KEY_ENTER],
        ["ui_accept", KEY_KP_ENTER],
        ["ui_accept", KEY_SPACE],
        ["ui_cancel", KEY_ESCAPE],
        ["pause", KEY_P],
        ["wrap_mode", KEY_W],
        ["journal", KEY_J],
        ["run", KEY_SHIFT],
        ["advance_time", KEY_T]
    ]:
        var key := InputEventKey.new()
        key.keycode = binding[1]
        key.pressed = true
        _check(
            key.is_action_pressed(binding[0]),
            "Keyboard bindings must remain available: " + str(binding[0])
        )
    var snake := SnakeGame.new()
    root.add_child(snake)
    snake.set_process(false)
    snake.wrap = false
    snake.food = Vector2i(30, 20)
    snake._unhandled_input(_motion(JOY_AXIS_LEFT_Y, 0.1))
    _check(not snake.started and snake.turns.is_empty(), "Stick drift must not start Snake.")
    snake._unhandled_input(_button(JOY_BUTTON_DPAD_DOWN))
    snake._unhandled_input(_button(JOY_BUTTON_DPAD_RIGHT))
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
    snake._unhandled_input(_motion(JOY_AXIS_LEFT_Y, 0.9))
    _check(snake.turns == [Vector2i.DOWN], "The left stick must queue a Snake turn.")
    snake.turns.clear()
    snake._unhandled_input(_button(JOY_BUTTON_START))
    _check(snake.paused, "Start must pause Snake.")
    snake._unhandled_input(_button(JOY_BUTTON_START))
    _check(not snake.paused, "Start must resume Snake.")
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
    var original_wrap: bool = snake.wrap
    snake._unhandled_input(_button(JOY_BUTTON_X))
    _check(snake.wrap != original_wrap, "X must toggle Snake wrap mode before a run.")
    snake._unhandled_input(_button(JOY_BUTTON_X))
    snake.free()

    var invaders := InvadersGame.new()
    root.add_child(invaders)
    invaders.set_process(false)
    invaders._unhandled_input(_button(JOY_BUTTON_A))
    _check(invaders.state == InvadersGame.State.INTRO, "A must start Invaders.")
    invaders.state = InvadersGame.State.PLAYING
    invaders._unhandled_input(_button(JOY_BUTTON_START))
    _check(invaders.paused, "Start must pause Invaders.")
    invaders._unhandled_input(_button(JOY_BUTTON_START))
    _send(_button(JOY_BUTTON_A))
    invaders._player_fire()
    _send(_button(JOY_BUTTON_A, false))
    _check(
        invaders.recoil_left > 0.0 and invaders.muzzle_frames == 1,
        "Firing must trigger recoil and a one-frame muzzle flash."
    )
    invaders.pbullets.clear()
    _send(_motion(JOY_AXIS_LEFT_X, 0.1))
    _check(Input.get_axis("ui_left", "ui_right") == 0.0, "Stick drift must not move Invaders.")
    _send(_motion(JOY_AXIS_LEFT_X, 0.9))
    var player_x: float = invaders.player_x
    invaders._update_playing(0.01)
    _check(invaders.player_x > player_x, "The left stick must move the cannon.")
    _send(_motion(JOY_AXIS_LEFT_X, 0.0))
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
    _send(_motion(JOY_AXIS_LEFT_X, 0.1))
    _check(
        Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") == Vector2.ZERO,
        "Stick drift must not move the wanderer."
    )
    _send(_motion(JOY_AXIS_LEFT_X, 0.9))
    _send(_button(JOY_BUTTON_RIGHT_SHOULDER))
    forest._move(0.1)
    _check(
        forest.running and forest.vel.x > 0.0,
        "The left stick and right shoulder must support Forest running."
    )
    _send(_motion(JOY_AXIS_LEFT_X, 0.0))
    _send(_button(JOY_BUTTON_RIGHT_SHOULDER, false))
    await process_frame
    _send(_button(JOY_BUTTON_X))
    forest._process(0.01)
    _check(forest.journal_open, "X must open the Forest journal.")
    _send(_button(JOY_BUTTON_X, false))
    await process_frame
    _send(_button(JOY_BUTTON_B))
    forest._process(0.01)
    _check(not forest.journal_open, "B must close the journal before leaving Forest.")
    _send(_button(JOY_BUTTON_B, false))
    await process_frame
    forest.journal_amount = 0.0
    _send(_button(JOY_BUTTON_START))
    forest._process(0.01)
    _check(forest.paused, "Start must pause Forest.")
    _send(_button(JOY_BUTTON_START, false))
    await process_frame
    _send(_button(JOY_BUTTON_START))
    forest._process(0.01)
    _check(not forest.paused, "Start must resume Forest.")
    _send(_button(JOY_BUTTON_START, false))
    await process_frame
    var time: float = forest.time_of_day
    _send(_button(JOY_BUTTON_Y))
    forest._process(0.01)
    _check(fposmod(forest.time_of_day - time, 1.0) >= 0.1, "Y must advance Forest time.")
    _send(_button(JOY_BUTTON_Y, false))
    await process_frame
    forest.sparks.clear()
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
    forest.fly_birds = [
        {"x": forest.player_pos.x, "y": 80.0, "vx": 40.0, "vy": -30.0,
            "t": 0.0, "v": 0, "ph": 0.0},
        {"x": forest.player_pos.x, "y": 90.0, "vx": -40.0, "vy": -30.0,
            "t": 0.0, "v": 0, "ph": 0.0},
    ]
    forest._update_particles(0.1)
    _check(float(forest.fly_birds[0]["x"]) > forest.player_pos.x and
        float(forest.fly_birds[1]["x"]) < forest.player_pos.x,
        "Flying birds must move in both directions.")
    var bird_draws: Array[int] = [0]
    forest.front.draw.connect(func() -> void: bird_draws[0] += 1)
    forest.front.queue_redraw()
    await process_frame
    await process_frame
    _check(bird_draws[0] > 0, "Bird facing checks must execute during drawing.")
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
    await _test_breach()
    await _test_forest_ui()
    current_scene.queue_free()
    await process_frame
    # Let the audio server release playback instances before engine shutdown.
    await create_timer(0.1).timeout
    print("Gameplay checks: %d passed, %d failed." % [checks - failures, failures])
    quit(1 if failures > 0 else 0)


func _test_forest_art() -> void:
    for seed_value in 16:
        var textures: Array[Texture2D] = [
            ForestArt.bush(40, 24, 500 + seed_value),
            ForestArt.bush(26, 18, 600 + seed_value, true),
            ForestArt.hanging_leaves(130, 46, 1300 + seed_value),
            ForestArt.fern(70, 46, 1400 + seed_value, 11),
        ]
        for i in textures.size():
            var image := textures[i].get_image()
            var clipped := false
            for y in image.get_height():
                clipped = (
                    clipped
                    or image.get_pixel(0, y).a > 0.0
                    or image.get_pixel(image.get_width() - 1, y).a > 0.0
                )
            if i < 2:
                for x in image.get_width():
                    clipped = clipped or image.get_pixel(x, image.get_height() - 1).a > 0.0
            _check(
                not clipped, "Foliage must not reach clipped image edges: %d/%d" % [i, seed_value]
            )
        var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_value
        ForestArt._blob(image, 32.0, 32.0, 18.0, 12.0, ForestArt.LEAF, rng)
        var outside := false
        for y in 64:
            for x in 64:
                if image.get_pixel(x, y).a > 0.0:
                    var distance := Vector2((x - 32.0) / 18.0, (y - 32.0) / 12.0)
                    outside = outside or distance.length_squared() >= 1.0
        _check(not outside, "Tree leaf clusters must stay within their drawing bounds.")
        var pine := ForestArt.pine(100, 180, seed_value).get_image()
        var tips: Array[int] = []
        for x in range(25, 75):
            var tip := -1
            for y in pine.get_height():
                var pixel := pine.get_pixel(x, y)
                if pixel.a > 0.0 and pixel.g > pixel.r:
                    tip = y
            if tip >= 0 and not tips.has(tip):
                tips.append(tip)
        _check(tips.size() > 1, "Pine branches must not end in a flat horizontal cut.")


func _test_transitions() -> void:
    for path in [
        "res://games/snake/snake.tscn",
        "res://games/space_invaders/invaders.tscn",
        "res://games/forest/forest.tscn",
        "res://games/neon_breach/breach.tscn"
    ]:
        change_scene_to_file("res://menu/menu.tscn")
        await process_frame
        await process_frame
        var index: int = (
            [
                "res://games/forest/forest.tscn",
                "res://games/snake/snake.tscn",
                "res://games/space_invaders/invaders.tscn",
                "res://games/neon_breach/breach.tscn"
            ]
                .find(path)
        )
        var card: Button = current_scene.get("cards")[index]
        for i in index:
            _send(_button(JOY_BUTTON_DPAD_DOWN))
            _send(_button(JOY_BUTTON_DPAD_DOWN, false))
            await process_frame
        _check(card.has_focus(), "The D-pad must select the correct launcher card.")
        if index == 3:
            _send(_button(JOY_BUTTON_DPAD_DOWN))
            _send(_button(JOY_BUTTON_DPAD_DOWN, false))
            await process_frame
            var slider := root.gui_get_focus_owner() as HSlider
            _check(slider != null, "The controller must reach the volume slider.")
            if slider != null:
                var volume := slider.value
                slider.value = 0.5
                _send(_button(JOY_BUTTON_DPAD_RIGHT))
                _send(_button(JOY_BUTTON_DPAD_RIGHT, false))
                _check(slider.value > 0.5, "The D-pad must adjust the volume slider.")
                slider.value = volume
                _send(_button(JOY_BUTTON_DPAD_UP))
                _send(_button(JOY_BUTTON_DPAD_UP, false))
                await process_frame
                _check(
                    card.has_focus(), "The controller must leave the slider and return to a card."
                )
        _send(_button(JOY_BUTTON_A))
        _send(_button(JOY_BUTTON_A, false))
        await create_timer(0.3).timeout
        _check(current_scene.scene_file_path == path, "Launcher must open " + path)
        if path.contains("forest"):
            var container := current_scene.get("container") as SubViewportContainer
            var world := container.get_child(0).get_child(0)
            world.set("no_save", true)
            _send(_button(JOY_BUTTON_B))
            world.call("_process", 1.0 / 60.0)
            _send(_button(JOY_BUTTON_B, false))
        else:
            current_scene.call("_unhandled_input", _button(JOY_BUTTON_B))
        await process_frame
        await process_frame
        _check(
            current_scene.scene_file_path == "res://menu/menu.tscn",
            "Escape must return to the launcher from " + path
        )


func _test_breach() -> void:
    var game := BreachGame.new()
    root.add_child(game)
    game.set_physics_process(false)
    await physics_frame
    await physics_frame
    _check(
        game.guards_remaining() == 6 and game.ammo == 24 and game.health == 100,
        "The shooter must start with six guards, health, and ammunition."
    )
    for cell: Vector2i in BreachGame.GUARD_CELLS + [BreachGame.EXIT, Vector2i(13, 1)]:
        _check(
            not game.pathfinder.get_id_path(BreachGame.START, cell).is_empty(),
            "Every guard and objective must be reachable: " + str(cell)
        )
    game._unhandled_input(_button(JOY_BUTTON_A))
    _check(game.state == BreachGame.State.PLAYING, "The controller must start Neon Breach.")
    await physics_frame
    await physics_frame
    game._unhandled_input(_button(JOY_BUTTON_START))
    var start: Vector3 = game.player.position
    game._physics_process(1.0)
    _check(game.paused and game.player.position == start, "Pause must halt shooter simulation.")
    game._unhandled_input(_button(JOY_BUTTON_START))
    var mouse := InputEventMouseMotion.new()
    mouse.relative = Vector2(30, 10000)
    game._unhandled_input(mouse)
    _check(
        game.player.rotation.y < 0.0 and is_equal_approx(game.camera.rotation.x, -1.1),
        "Mouse look must turn and clamp vertical aim."
    )
    game.player.rotation.y = 0.0
    game.camera.rotation.x = 0.0
    _send(_motion(JOY_AXIS_RIGHT_X, 0.8))
    game._physics_process(0.01)
    _send(_motion(JOY_AXIS_RIGHT_X, 0.0))
    _check(game.player.rotation.y < 0.0, "The right stick must turn the shooter camera.")
    _check(
        _motion(JOY_AXIS_TRIGGER_RIGHT, 0.9).is_action_pressed("breach_fire"),
        "The controller trigger must fire the shooter weapon."
    )
    _send(_motion(JOY_AXIS_RIGHT_Y, -0.8))
    game._physics_process(0.01)
    _send(_motion(JOY_AXIS_RIGHT_Y, 0.0))
    _check(game.camera.rotation.x > 0.0, "Right-stick up must aim upward.")
    var guard: BreachGame.Guard = game.guards[0]
    game.player.position = game._cell_position(Vector2i(3, 10))
    guard.body.position = game._cell_position(Vector2i(5, 10))
    game.player.rotation.y = -PI / 2.0
    game.camera.rotation.x = 0.0
    await physics_frame
    await physics_frame
    game.fire_cooldown = 0.0
    game.fire()
    _check(
        guard.hp == 1 and game.ammo == 23 and game.hit_marker > 0.0,
        "A hitscan shot must hit the aimed guard and consume one round."
    )
    game.fire()
    _check(game.ammo == 23, "The fire cooldown must prevent repeated instant shots.")
    game.player.position = game._cell_position(Vector2i(2, 7))
    guard.body.position = game._cell_position(Vector2i(2, 10))
    game.player.rotation.y = PI
    await physics_frame
    await physics_frame
    game.fire_cooldown = 0.0
    game.fire()
    _check(
        guard.hp == 1 and not game._can_see_player(guard),
        "Station walls must block gunfire and enemy sight."
    )
    guard.active = true
    game._update_guards(0.1)
    _check(
        guard.body.velocity.z < 0.0, "Aware guards must pursue the player through the station path."
    )
    game.player.position = game._cell_position(Vector2i(2, 7))
    game.player.rotation.y = 0.0
    _send(_event("breach_back"))
    for i in 20:
        await physics_frame
        game._physics_process(1.0 / 60.0)
    Input.action_release("breach_back")
    _check(game.player.position.z < 20.0, "Station walls must block player movement.")
    game._hit_guard(guard)
    var points: int = game.score
    game._hit_guard(guard)
    _check(
        points == 100 and game.score == points and game.guards_remaining() == 5,
        "A guard must award its score only once."
    )
    game.ammo = 0
    game.fire_cooldown = 0.0
    game.fire()
    _check(game.ammo == 0, "Empty fire must not create negative ammunition.")
    game.health = 90
    game.player.position = game._cell_position(Vector2i(5, 11))
    game._update_pickups()
    _check(game.health == 100, "Medkits must cap health at 100.")
    game.player.position = game._cell_position(Vector2i(3, 5))
    game._update_pickups()
    _check(game.ammo == 18, "Ammo crates must refill the weapon.")
    game.player.position = game._cell_position(Vector2i(13, 1))
    game._update_pickups()
    _check(
        game.has_key and not game.exit_ready(),
        "The key alone must not unlock an uncleared station."
    )
    for enemy in game.guards:
        while enemy.hp > 0:
            game._hit_guard(enemy)
    _check(game.exit_ready(), "The key and cleared guards must unlock extraction.")
    game.player.position = game._cell_position(BreachGame.EXIT)
    await physics_frame
    await physics_frame
    game._physics_process(1.0 / 60.0)
    points = game.score
    game.finish(true)
    _check(
        (
            game.state == BreachGame.State.WON
            and game.score == points
            and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
        ),
        "Victory must score once and release the mouse."
    )
    game._start_run()
    _check(
        game.guards_remaining() == 6 and game.score == 0 and not game.has_key,
        "Restart must reset enemies, score, and the keycard."
    )
    game.invulnerable = 0.0
    game.damage(1000)
    _check(
        game.health == 0 and game.state == BreachGame.State.DEAD,
        "Lethal damage must end the run without negative health."
    )
    game.queue_free()
    await process_frame


func _test_forest_ui() -> void:
    change_scene_to_file("res://games/forest/forest.tscn")
    await process_frame
    await process_frame
    var host := current_scene as Control
    var container := host.get("container") as SubViewportContainer
    var ui := host.get("ui") as Node2D
    var viewport := container.get_child(0) as SubViewport
    var world := viewport.get_child(0) as Node2D
    world.set("no_save", true)
    world.set_process(false)
    _check(
        ui.get_viewport() == root and viewport.size == Vector2i(320, 180),
        "Forest text must use the window viewport while the art stays at 320 by 180."
    )
    for resolution in [
        Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2048, 1152)
    ]:
        root.size = resolution
        await process_frame
        host.call("_layout")
        var scale_factor := floorf(minf(resolution.x / 320.0, resolution.y / 180.0))
        _check(
            ui.scale == Vector2.ONE * scale_factor and ui.position == container.position,
            "The window UI must align with the forest at " + str(resolution)
        )
    for discovery: Dictionary in world.get("TYPES"):
        for field in ["text", "hint"]:
            var text: String = discovery[field]
            if field == "hint":
                text = "Hint: " + text
            var lines: Array[String] = world.call("_wrap", text, 106.0, 8)
            _check(lines.size() <= 2, "Journal entries must fit without clipping: " + text)
    change_scene_to_file("res://menu/menu.tscn")
    await process_frame
    await process_frame
