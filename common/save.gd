class_name Save
extends RefCounted

## Persistent high scores and settings, stored in user://arcade.cfg.
## Games are identified by a short key: "snake", "invaders", "forest".

const PATH := "user://arcade.cfg"


static func _load() -> ConfigFile:
    var cfg := ConfigFile.new()
    cfg.load(PATH)  # missing file is fine: we just get defaults
    return cfg


static func get_value(section: String, key: String, default: Variant=null) -> Variant:
    return _load().get_value(section, key, default)


static func set_value(section: String, key: String, value: Variant) -> void:
    var cfg := _load()
    cfg.set_value(section, key, value)
    cfg.save(PATH)


static func get_high(game: String) -> int:
    return int(get_value("scores", game, 0))


## Stores the score if it beats the record. Returns true on a new record.
static func submit_score(game: String, score: int) -> bool:
    if score > get_high(game):
        set_value("scores", game, score)
        return true
    return false


static func get_volume() -> float:
    return clampf(float(get_value("settings", "volume", 0.8)), 0.0, 1.0)


static func set_volume(v: float) -> void:
    set_value("settings", "volume", clampf(v, 0.0, 1.0))
    apply_volume()


## Applies the saved master volume. Call once at startup (the menu does this).
static func apply_volume() -> void:
    var v := get_volume()
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
    AudioServer.set_bus_mute(0, v <= 0.001)
