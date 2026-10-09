extends Node3D

## A small retro FPS with procedural station art, guards, and sound.

enum State {TITLE, PLAYING, WON, DEAD}

const Art := preload("res://games/neon_breach/breach_art.gd")
const CELL := 2.5
const LEVEL := [
    "################",
    "#.....#........#",
    "#.....#........#",
    "#.....#........#",
    "###.#####.######",
    "#.......#......#",
    "#.......#......#",
    "#.......#......#",
    "###.#####.######",
    "#.......#......#",
    "#.......#......#",
    "#..............#",
    "################",
]
const START := Vector2i(2, 10)
const EXIT := Vector2i(12, 2)
const GUARD_CELLS := [
    Vector2i(5, 10),
    Vector2i(4, 6),
    Vector2i(5, 2),
    Vector2i(11, 10),
    Vector2i(11, 6),
    Vector2i(13, 2)
]


class Guard:
    var body: CharacterBody3D
    var sprite: Sprite3D
    var hp := 2
    var active := false
    var cooldown := 1.0
    var path_timer := 0.0
    var target := Vector3.ZERO
    var flash := 0.0


class Pickup:
    var node: Sprite3D
    var kind: String
    var base_y := 0.5


var state := State.TITLE
var paused := false
var player: CharacterBody3D
var camera: Camera3D
var hud: Node2D
var pathfinder := AStarGrid2D.new()
var guards: Array[Guard] = []
var pickups: Array[Pickup] = []
var players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_player := 0
var guard_textures: Array[Texture2D] = []
var pickup_textures: Dictionary = {}
var exit_material: StandardMaterial3D
var health := 100
var ammo := 24
var score := 0
var best := 0
var has_key := false
var fire_cooldown := 0.0
var recoil := 0.0
var hit_marker := 0.0
var damage_flash := 0.0
var pickup_flash := 0.0
var invulnerable := 0.0
var age := 0.0
var stride := 0.0
var toast := ""
var toast_left := 0.0
var _focused := true


func _ready() -> void:
    _focused = DisplayServer.get_name() == "headless" or get_window().has_focus()
    Save.apply_volume()
    best = Save.get_high("neon_breach")
    _build_station()
    player = CharacterBody3D.new()
    player.collision_layer = 4
    player.collision_mask = 3
    _add_capsule(player)
    add_child(player)
    camera = Camera3D.new()
    camera.position.y = 1.45
    camera.fov = 78.0
    camera.near = 0.05
    player.add_child(camera)
    camera.make_current()
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Node2D.new()
    layer.add_child(hud)
    hud.draw.connect(_draw_hud)
    guard_textures = [Art.guard(), Art.guard(true)]
    for kind in ["health", "ammo", "key"]:
        pickup_textures[kind] = Art.pickup(kind)
    for i in 4:
        var sound_player := AudioStreamPlayer.new()
        add_child(sound_player)
        players.append(sound_player)
    sounds = {
        "shot": Sfx.build([[100, 45, 0.09, "noise", 0.5], [70, 30, 0.07, "square", 0.25]]),
        "hit": Sfx.build([[240, 70, 0.09, "noise", 0.3]]),
        "kill": Sfx.build([[170, 35, 0.2, "noise", 0.4]]),
        "hurt": Sfx.build([[120, 50, 0.18, "square", 0.3]]),
        "pickup": Sfx.build([[660, 880, 0.07, "sine", 0.3], [1047, 1047, 0.1, "sine", 0.2]]),
        "empty": Sfx.build([[100, 100, 0.035, "square", 0.1]]),
        "win":
            Sfx.build(
                [
                    [523, 523, 0.1, "sine", 0.3],
                    [659, 659, 0.1, "sine", 0.3],
                    [784, 1047, 0.25, "sine", 0.3]
                ]
            ),
        "dead": Sfx.build([[220, 80, 0.5, "square", 0.25]]),
    }
    reset_run()


func _cell_position(cell: Vector2i) -> Vector3:
    return Vector3((cell.x + 0.5) * CELL, 0.0, (cell.y + 0.5) * CELL)


func _grid_position(pos: Vector3) -> Vector2i:
    return Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))


func _material(texture: Texture2D, color: Color=Color.WHITE) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.albedo_color = color
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.roughness = 1.0
    material.uv1_triplanar = true
    material.uv1_scale = Vector3.ONE / CELL
    return material


func _box(pos: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    body.collision_layer = 1
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    body.add_child(visual)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)


func _build_station() -> void:
    pathfinder.region = Rect2i(0, 0, LEVEL[0].length(), LEVEL.size())
    pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    pathfinder.update()
    var wall_material := _material(Art.wall())
    var floor_material := _material(Art.floor_tile())
    for z in LEVEL.size():
        var x := 0
        while x < LEVEL[z].length():
            if LEVEL[z][x] != "#":
                x += 1
                continue
            var first := x
            while x < LEVEL[z].length() and LEVEL[z][x] == "#":
                pathfinder.set_point_solid(Vector2i(x, z))
                x += 1
            _box(
                Vector3((first + x) * CELL / 2.0, 1.5, (z + 0.5) * CELL),
                Vector3((x - first) * CELL, 3.0, CELL),
                wall_material
            )
    var size := Vector3(LEVEL[0].length() * CELL, 0.2, LEVEL.size() * CELL)
    _box(Vector3(size.x / 2.0, -0.1, size.z / 2.0), size, floor_material)
    _box(
        Vector3(size.x / 2.0, 3.1, size.z / 2.0), size, _material(Art.floor_tile(), Color("617185"))
    )
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("101b28")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("91abc6")
    environment.ambient_light_energy = 0.65
    var world := WorldEnvironment.new()
    world.environment = environment
    add_child(world)
    for cell in [
        Vector2i(3, 2),
        Vector2i(11, 2),
        Vector2i(4, 6),
        Vector2i(11, 6),
        Vector2i(3, 10),
        Vector2i(11, 10)
    ]:
        var light := OmniLight3D.new()
        light.position = _cell_position(cell) + Vector3(0, 2.5, 0)
        light.omni_range = 9.0
        light.light_energy = 2.2
        light.light_color = Color("64bbc8") if cell.x < 8 else Color("e9a666")
        add_child(light)
        var lamp_material := StandardMaterial3D.new()
        lamp_material.albedo_color = light.light_color
        lamp_material.emission_enabled = true
        lamp_material.emission = light.light_color
        _box(light.position + Vector3(0, 0.38, 0), Vector3(1.3, 0.12, 0.4), lamp_material)
    exit_material = StandardMaterial3D.new()
    exit_material.albedo_color = Color("9b3939")
    exit_material.emission_enabled = true
    exit_material.emission = Color("9b3939")
    var marker := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(1.6, 0.03, 1.6)
    mesh.material = exit_material
    marker.mesh = mesh
    marker.position = _cell_position(EXIT) + Vector3(0, 0.025, 0)
    add_child(marker)


func _add_capsule(body: CharacterBody3D) -> void:
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.28
    shape.height = 1.6
    collision.shape = shape
    collision.position.y = 0.8
    body.add_child(collision)


func _sprite(texture: Texture2D, pixel_size: float) -> Sprite3D:
    var sprite := Sprite3D.new()
    # shortcut: Godot 4.3's headless sprite meshes hit #86806; remove at a 4.4 minimum.
    if DisplayServer.get_name() != "headless":
        sprite.texture = texture
    sprite.pixel_size = pixel_size
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    return sprite


func reset_run() -> void:
    for guard in guards:
        if is_instance_valid(guard.body):
            guard.body.collision_layer = 0
            guard.body.queue_free()
    for pickup in pickups:
        pickup.node.queue_free()
    guards.clear()
    pickups.clear()
    player.position = _cell_position(START)
    player.rotation = Vector3.ZERO
    player.rotation.y = -PI / 2.0
    player.velocity = Vector3.ZERO
    camera.rotation = Vector3.ZERO
    camera.position.y = 1.45
    health = 100
    ammo = 24
    score = 0
    has_key = false
    fire_cooldown = 0.25
    recoil = 0.0
    hit_marker = 0.0
    damage_flash = 0.0
    pickup_flash = 0.0
    invulnerable = 1.0
    stride = 0.0
    paused = false
    toast = "Find the keycard. Clear the station. Reach the exit."
    toast_left = 4.0
    for i in GUARD_CELLS.size():
        var guard := Guard.new()
        guard.body = CharacterBody3D.new()
        guard.body.collision_layer = 2
        guard.body.collision_mask = 7
        _add_capsule(guard.body)
        guard.body.position = _cell_position(GUARD_CELLS[i])
        guard.hp = 4 if i == GUARD_CELLS.size() - 1 else 2
        guard.cooldown = 1.0 + i * 0.15
        guard.sprite = _sprite(guard_textures[1 if guard.hp == 4 else 0], 0.035)
        guard.sprite.position.y = 0.85
        guard.body.add_child(guard.sprite)
        add_child(guard.body)
        guards.append(guard)
    _add_pickup(Vector2i(5, 11), "health")
    _add_pickup(Vector2i(3, 5), "ammo")
    _add_pickup(Vector2i(12, 7), "ammo")
    _add_pickup(Vector2i(13, 1), "key")
    _update_exit()


func _add_pickup(cell: Vector2i, kind: String) -> void:
    var pickup := Pickup.new()
    pickup.kind = kind
    pickup.node = _sprite(pickup_textures[kind], 0.035)
    pickup.node.position = _cell_position(cell) + Vector3(0, pickup.base_y, 0)
    add_child(pickup.node)
    pickups.append(pickup)


func _start_run() -> void:
    reset_run()
    state = State.PLAYING
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
    if not _focused:
        return
    if event.is_action_pressed("ui_cancel"):
        get_tree().change_scene_to_file("res://menu/menu.tscn")
    elif event.is_action_pressed("pause") and state == State.PLAYING:
        _set_paused(not paused)
    elif event.is_action_pressed("ui_accept") and state != State.PLAYING:
        _start_run()
    elif event is InputEventMouseMotion and state == State.PLAYING and not paused:
        player.rotation.y -= event.screen_relative.x * 0.0028
        camera.rotation.x = clampf(camera.rotation.x - event.screen_relative.y * 0.0028, -1.1, 1.1)


func _set_paused(value: bool) -> void:
    paused = value
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _focused = false
        if state == State.PLAYING:
            _set_paused(true)
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        _focused = true


func _process(_delta: float) -> void:
    hud.queue_redraw()


func _physics_process(delta: float) -> void:
    if state != State.PLAYING or paused:
        return
    age += delta
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    recoil = maxf(0.0, recoil - delta)
    hit_marker = maxf(0.0, hit_marker - delta)
    damage_flash = maxf(0.0, damage_flash - delta)
    pickup_flash = maxf(0.0, pickup_flash - delta)
    invulnerable = maxf(0.0, invulnerable - delta)
    toast_left = maxf(0.0, toast_left - delta)
    player.rotation.y -= Input.get_axis("breach_turn_left", "breach_turn_right") * delta * 2.2
    camera.rotation.x = clampf(
        camera.rotation.x - Input.get_axis("breach_look_up", "breach_look_down") * delta * 1.7,
        -1.1,
        1.1
    )
    var input := Input.get_vector("breach_left", "breach_right", "breach_forward", "breach_back")
    var direction := player.basis * Vector3(input.x, 0, input.y)
    var speed := 6.0 if Input.is_action_pressed("run") else 4.2
    player.velocity.x = direction.x * speed
    player.velocity.z = direction.z * speed
    player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - delta * 20.0
    player.move_and_slide()
    if input.length() > 0.1:
        stride += delta * speed * 2.0
    camera.position.y = 1.45 + sin(stride) * input.length() * 0.035
    if Input.is_action_pressed("breach_fire"):
        fire()
    _update_guards(delta)
    if state != State.PLAYING:
        return
    _update_pickups()
    if exit_ready() and player.position.distance_to(_cell_position(EXIT)) < 0.9:
        finish(true)


func fire() -> void:
    if state != State.PLAYING or paused or fire_cooldown > 0.0:
        return
    fire_cooldown = 0.24
    if ammo == 0:
        _play("empty")
        toast = "Out of ammo. Find an ammo crate."
        toast_left = 1.0
        return
    ammo -= 1
    recoil = 0.12
    _play("shot")
    var start := camera.global_position
    var end := start - camera.global_basis.z * 50.0
    var query := PhysicsRayQueryParameters3D.create(start, end, 3)
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    for guard in guards:
        if guard.hp > 0 and hit["collider"] == guard.body:
            _hit_guard(guard)
            return


func _hit_guard(guard: Guard) -> void:
    if guard.hp <= 0:
        return
    guard.hp -= 1
    guard.active = true
    guard.flash = 0.12
    guard.cooldown = maxf(guard.cooldown, 0.4)
    hit_marker = 0.15
    if guard.hp > 0:
        _play("hit")
        return
    score += 100
    guard.body.collision_layer = 0
    guard.body.queue_free()
    _play("kill")
    _update_exit()


func guards_remaining() -> int:
    var count := 0
    for guard in guards:
        if guard.hp > 0:
            count += 1
    return count


func exit_ready() -> bool:
    return has_key and guards_remaining() == 0


func _update_exit() -> void:
    var color := Color("55dca0") if exit_ready() else Color("9b3939")
    exit_material.albedo_color = color
    exit_material.emission = color
    if exit_ready():
        toast = "Station clear. Reach the green exit pad."
        toast_left = 4.0


func _can_see_player(guard: Guard) -> bool:
    var start := guard.body.global_position + Vector3(0, 1.3, 0)
    var query := PhysicsRayQueryParameters3D.create(start, camera.global_position, 7,
        [guard.body.get_rid()])
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and hit["collider"] == player


func _update_guards(delta: float) -> void:
    for guard in guards:
        if guard.hp <= 0:
            continue
        guard.flash = maxf(0.0, guard.flash - delta)
        guard.sprite.modulate = Color(3, 3, 3) if guard.flash > 0.0 else Color.WHITE
        var distance := guard.body.position.distance_to(player.position)
        var visible := distance < 16.0 and _can_see_player(guard)
        if visible:
            guard.active = true
        if not guard.active:
            continue
        guard.cooldown -= delta
        if visible and distance < 11.0 and guard.cooldown <= 0.0:
            guard.cooldown = 1.5
            guard.flash = 0.08
            damage(10)
            if state != State.PLAYING:
                return
        guard.path_timer -= delta
        if guard.path_timer <= 0.0:
            guard.path_timer = 0.4
            var path := pathfinder.get_id_path(
                _grid_position(guard.body.position), _grid_position(player.position)
            )
            guard.target = _cell_position(path[1]) if path.size() > 1 else player.position
        var direction := guard.target - guard.body.position
        direction.y = 0.0
        if direction.length() > 0.1 and distance > 2.0:
            direction = direction.normalized() * 1.5
        else:
            direction = Vector3.ZERO
        guard.body.velocity = Vector3(direction.x, -2.0, direction.z)
        guard.body.move_and_slide()


func damage(amount: int) -> void:
    if state != State.PLAYING or paused or invulnerable > 0.0:
        return
    health = maxi(0, health - amount)
    invulnerable = 0.35
    damage_flash = 0.22
    _play("hurt")
    if health == 0:
        finish(false)


func _update_pickups() -> void:
    for i in range(pickups.size() - 1, -1, -1):
        var pickup := pickups[i]
        pickup.node.position.y = pickup.base_y + sin(age * 3.0 + i) * 0.08
        var offset := player.position - pickup.node.position
        offset.y = 0.0
        if offset.length() > 0.75:
            continue
        match pickup.kind:
            "health":
                if health == 100:
                    continue
                health = mini(100, health + 35)
                toast = "Medkit: +35 health"
            "ammo":
                if ammo == 99:
                    continue
                ammo = mini(99, ammo + 18)
                toast = "Ammo crate: +18 rounds"
            "key":
                has_key = true
                toast = "Keycard acquired. Clear the remaining guards."
                _update_exit()
        toast_left = 2.5
        pickup_flash = 0.2
        _play("pickup")
        pickup.node.queue_free()
        pickups.remove_at(i)


func finish(won: bool) -> void:
    if state != State.PLAYING:
        return
    state = State.WON if won else State.DEAD
    if won:
        score += health * 5 + ammo * 2
    Save.submit_score("neon_breach", score)
    best = maxi(best, score)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _play("win" if won else "dead")


func _play(sound: String) -> void:
    var sound_player := players[next_player]
    next_player = (next_player + 1) % players.size()
    sound_player.stream = sounds[sound]
    sound_player.play()


func _exit_tree() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    for sound_player in players:
        sound_player.stop()
        sound_player.stream = null


func _text(text: String, pos: Vector2, size: int=18, color: Color=Color.WHITE) -> void:
    hud.draw_string(
        ThemeDB.fallback_font,
        pos + Vector2.ONE,
        text,
        HORIZONTAL_ALIGNMENT_LEFT,
        -1,
        size,
        Color(0, 0, 0, color.a * 0.7)
    )
    hud.draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _center(text: String, y: float, size: int=22, color: Color=Color.WHITE) -> void:
    var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    _text(text, Vector2((hud.get_viewport_rect().size.x - width) / 2.0, y), size, color)


func _draw_hud() -> void:
    var size := hud.get_viewport_rect().size
    var centre := size / 2.0
    if state != State.TITLE:
        hud.draw_rect(Rect2(0, 0, size.x, 42), Color(0.03, 0.05, 0.08, 0.8))
        _text("SCORE %d   BEST %d" % [score, best], Vector2(14, 27), 16)
        _text(
            "GUARDS %d   KEY %s" % [guards_remaining(), "YES" if has_key else "NO"],
            Vector2(size.x - 210, 27),
            16,
            Color("edc171")
        )
        hud.draw_rect(Rect2(0, size.y - 50, size.x, 50), Color(0.03, 0.05, 0.08, 0.95))
        _text(
            "HEALTH %d" % health,
            Vector2(16, size.y - 18),
            22,
            Color("ff7474") if health < 30 else Color("83ddbc")
        )
        _text("AMMO %d" % ammo, Vector2(size.x - 140, size.y - 18), 22, Color("edc171"))
        if state == State.PLAYING:
            var color := Color("ffd16d") if hit_marker > 0.0 else Color("e4f5f4")
            hud.draw_line(centre + Vector2(-9, 0), centre + Vector2(-3, 0), color, 2.0)
            hud.draw_line(centre + Vector2(3, 0), centre + Vector2(9, 0), color, 2.0)
            hud.draw_line(centre + Vector2(0, -9), centre + Vector2(0, -3), color, 2.0)
            hud.draw_line(centre + Vector2(0, 3), centre + Vector2(0, 9), color, 2.0)
            var gun := Vector2(centre.x + sin(stride) * 3.0, size.y - 52 + recoil * 100.0)
            hud.draw_rect(Rect2(gun + Vector2(-32, -80), Vector2(65, 85)), Color("101923"))
            hud.draw_rect(Rect2(gun + Vector2(-22, -100), Vector2(44, 76)), Color("4c5c70"))
            hud.draw_rect(Rect2(gun + Vector2(-14, -92), Vector2(28, 64)), Color("8695a1"))
            hud.draw_rect(Rect2(gun + Vector2(-10, -104), Vector2(20, 8)), Color("132a33"))
            hud.draw_rect(Rect2(gun + Vector2(-8, -110), Vector2(16, 5)), Color("edc171"))
            hud.draw_rect(Rect2(gun + Vector2(-43, -14), Vector2(27, 35)), Color("a47759"))
            hud.draw_rect(Rect2(gun + Vector2(16, -14), Vector2(27, 35)), Color("a47759"))
            if recoil > 0.075:
                var tip := gun + Vector2(0, -115)
                hud.draw_colored_polygon(
                    PackedVector2Array(
                        [
                            tip + Vector2(-30, 0),
                            tip + Vector2(-8, -12),
                            tip + Vector2(0, -36),
                            tip + Vector2(9, -12),
                            tip + Vector2(31, -3),
                            tip + Vector2(8, 9)
                        ]
                    ),
                    Color("ffd581")
                )
            if toast_left > 0.0:
                _center(toast, 67, 15, Color("eed28a"))
    if damage_flash > 0.0:
        hud.draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.1, 0.1, damage_flash * 0.7))
    if pickup_flash > 0.0:
        hud.draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 1, 0.5, pickup_flash * 0.4))
    if state == State.TITLE or state == State.WON or state == State.DEAD or paused:
        hud.draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.04, 0.83))
        var title := "NEON BREACH"
        if paused:
            title = "PAUSED"
        elif state == State.WON:
            title = "STATION CLEAR"
        elif state == State.DEAD:
            title = "YOU WENT DOWN"
        _center(title, centre.y - 95, 36, Color("79d9d4"))
        if state == State.TITLE:
            _center("Clear six guards, find the keycard, and reach the exit.", centre.y - 52, 17)
            _center("WASD move   Mouse look   Q/E turn   Shift run", centre.y - 18, 16)
            _center("Click/Space fire   P pause   Esc menu", centre.y + 8, 16)
            _center("Controller: left stick move, right stick look, RT/A fire", centre.y + 40, 15)
            _center("Enter / A: breach the station", centre.y + 87, 22, Color("edc171"))
        elif paused:
            _center("P / Start: resume    Esc / B: menu", centre.y, 20)
        else:
            _center("Score %d    Personal best %d" % [score, best], centre.y - 35, 22)
            _center("Enter / A: retry    Esc / B: menu", centre.y + 25, 20)
