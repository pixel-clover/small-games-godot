extends Control

## Launcher menu: pick a game, see high scores and set the master volume.
## Built in code so the scene stays trivial.

var players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_player := 0
var cards: Array[Button] = []
var focus_tweens: Dictionary = {}
var age := 0.0
var leaving := false


func _ready() -> void:
    Save.apply_volume()
    for i in 3:
        var p := AudioStreamPlayer.new()
        add_child(p)
        players.append(p)
    sounds = {
        "move": Sfx.build([[660, 880, 0.035, "sine", 0.2]]),
        "launch":
            Sfx.build(
                [
                    [523, 523, 0.06, "sine", 0.3],
                    [659, 659, 0.06, "sine", 0.3],
                    [784, 784, 0.09, "sine", 0.3]
                ]
            ),
        "cancel": Sfx.build([[440, 220, 0.12, "sine", 0.25]]),
        "volume": Sfx.build([[659, 659, 0.04, "sine", 0.3], [784, 784, 0.06, "sine", 0.3]]),
    }
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.06, 0.09)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    box.add_theme_constant_override("separation", 10)
    add_child(box)

    var title := Label.new()
    title.text = "SMALL GAMES"
    title.add_theme_font_size_override("font_size", 42)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var first := _add_button(
        box,
        "Forest Walk",
        "res://games/forest/forest.tscn",
        "Discovered: %d" % int(Save.get_value("forest", "total", 0))
    )
    _add_button(
        box,
        "Snake",
        "res://games/snake/snake.tscn",
        "Best: %d   Wrap: %d" % [Save.get_high("snake"), Save.get_high("snake_wrap")]
    )
    _add_button(
        box,
        "Space Invaders",
        "res://games/space_invaders/invaders.tscn",
        "Best: %d" % Save.get_high("invaders")
    )

    var vol_row := HBoxContainer.new()
    vol_row.alignment = BoxContainer.ALIGNMENT_CENTER
    var vol_label := Label.new()
    vol_label.text = "Volume"
    vol_row.add_child(vol_label)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.05
    slider.value = Save.get_volume()
    slider.custom_minimum_size = Vector2(160, 24)
    slider.value_changed.connect(
        func(value: float) -> void:
            Save.set_volume(value)
            _play("volume")
    )
    vol_row.add_child(slider)
    box.add_child(vol_row)

    var quit := Button.new()
    quit.text = "Quit"
    quit.custom_minimum_size = Vector2(300, 40)
    quit.pressed.connect(_activate.bind(""))
    box.add_child(quit)
    _connect_focus(quit)
    slider.focus_entered.connect(_play.bind("move"))
    var hint := Label.new()
    hint.text = "Controller: stick/D-pad select   A launch   B quit"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 14)
    box.add_child(hint)
    first.grab_focus()


func _add_button(parent: Control, text: String, scene: String, sub: String) -> Button:
    var b := Button.new()
    b.text = "%s\n%s" % [text, sub]
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.add_theme_constant_override("outline_size", 0)
    b.custom_minimum_size = Vector2(400, 66)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.15, 0.2)
    style.content_margin_left = 82
    b.add_theme_stylebox_override("normal", style)
    var hover := style.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.2, 0.25, 0.3)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", hover)
    b.pressed.connect(_activate.bind(scene))
    parent.add_child(b)
    var kind := cards.size()
    cards.append(b)
    b.draw.connect(_draw_card.bind(b, kind))
    _connect_focus(b)
    return b


func _play(sound: String) -> void:
    var p := players[next_player]
    next_player = (next_player + 1) % players.size()
    p.stream = sounds[sound]
    p.play()


func _exit_tree() -> void:
    for player in players:
        player.stop()
        player.stream = null


func _connect_focus(button: Button) -> void:
    button.focus_entered.connect(
        func() -> void:
            _play("move")
            _focus(button, true)
    )
    button.focus_exited.connect(_focus.bind(button, false))


func _focus(button: Button, focused: bool) -> void:
    if focus_tweens.has(button):
        (focus_tweens[button] as Tween).kill()
    button.pivot_offset = button.size / 2.0
    var tween := create_tween()
    focus_tweens[button] = tween
    (
        tween
            .tween_property(button, "scale", Vector2.ONE * (1.035 if focused else 1.0), 0.2)
            .set_trans(Tween.TRANS_BACK)
            .set_ease(Tween.EASE_OUT)
    )


func _activate(scene: String) -> void:
    if leaving:
        return
    leaving = true
    _play("cancel" if scene == "" else "launch")
    await get_tree().create_timer(0.22).timeout
    if scene == "":
        get_tree().quit()
    else:
        get_tree().change_scene_to_file(scene)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _activate("")


func _process(delta: float) -> void:
    age += delta
    for card in cards:
        card.queue_redraw()


func _draw_card(button: Button, kind: int) -> void:
    button.draw_rect(Rect2(8, 8, 62, 50), Color(0.04, 0.07, 0.09))
    match kind:
        0:
            for i in 3:
                var x := 18.0 + i * 18.0
                button.draw_rect(Rect2(x, 31, 3, 22), Color("76563c"))
                button.draw_circle(Vector2(x + sin(age + i), 26), 10, Color("43805a"))
            var p := Vector2(38 + sin(age) * 9, 46)
            button.draw_circle(p + Vector2(5, -4), 5 + sin(age * 3), Color(1, 0.8, 0.3, 0.3))
            button.draw_rect(Rect2(p, Vector2(4, 8)), Color("ffd27a"))
        1:
            for i in 5:
                var p := Vector2(14 + i * 9, 32 + sin(age * 3 - i * 0.5) * 6)
                button.draw_rect(
                    Rect2(p, Vector2(8, 8)), Color.GREEN_YELLOW if i == 4 else Color.GREEN
                )
            button.draw_circle(Vector2(60, 20), 3, Color.TOMATO)
        2:
            for i in 3:
                var x := 15 + i * 16 + int(sin(age * 2) * 4)
                button.draw_rect(Rect2(x, 18, 11, 6), Color.LIME_GREEN)
                button.draw_rect(Rect2(x + 3, 15, 5, 3), Color.LIME_GREEN)
            button.draw_rect(Rect2(32, 47, 16, 5), Color.GREEN_YELLOW)
            button.draw_rect(Rect2(38, 42, 4, 5), Color.GREEN_YELLOW)
            button.draw_rect(Rect2(39, 42 - fmod(age * 28, 23), 2, 5), Color.WHITE)
