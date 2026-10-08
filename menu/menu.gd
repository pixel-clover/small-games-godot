extends Control
## Launcher menu: pick a game, see high scores and set the master volume.
## Built in code so the scene stays trivial.


func _ready() -> void:
    Save.apply_volume()
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.06, 0.09)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.grow_horizontal = Control.GROW_DIRECTION_BOTH
    box.grow_vertical = Control.GROW_DIRECTION_BOTH
    box.add_theme_constant_override("separation", 12)
    add_child(box)

    var title := Label.new()
    title.text = "SMALL GAMES"
    title.add_theme_font_size_override("font_size", 42)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var first := _add_button(box, "Forest Walk", "res://games/forest/forest.tscn",
        "Discovered: %d" % int(Save.get_value("forest", "total", 0)))
    _add_button(box, "Snake", "res://games/snake/snake.tscn",
        "Best: %d   Wrap: %d" % [Save.get_high("snake"), Save.get_high("snake_wrap")])
    _add_button(box, "Space Invaders", "res://games/space_invaders/invaders.tscn",
        "Best: %d" % Save.get_high("invaders"))

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
    slider.value_changed.connect(Save.set_volume)
    vol_row.add_child(slider)
    box.add_child(vol_row)

    var quit := Button.new()
    quit.text = "Quit"
    quit.custom_minimum_size = Vector2(300, 40)
    quit.pressed.connect(get_tree().quit)
    box.add_child(quit)
    first.grab_focus()


func _add_button(parent: Control, text: String, scene: String, sub: String) -> Button:
    var b := Button.new()
    b.text = "%s    (%s)" % [text, sub]
    b.custom_minimum_size = Vector2(300, 44)
    b.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene))
    parent.add_child(b)
    return b
