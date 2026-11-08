extends RefCounted

const BURST_TEXTURE := preload("res://common/effects/invader-burst.png")
const BURST_SIZE := Vector2(48, 48)
const BURST_DURATION := 0.3
const BURST_FPS := 30.0


static func draw_burst(canvas: CanvasItem, pos: Vector2, age: float, tint: Color,
        scale_factor: float=1.0) -> void:
    if age < 0.0 or age >= BURST_DURATION:
        return
    var frame := mini(int(age * BURST_FPS), 9)
    var source := Rect2(Vector2(frame % 4, floori(frame / 4.0)) * BURST_SIZE, BURST_SIZE)
    var size := BURST_SIZE * scale_factor
    canvas.draw_texture_rect_region(BURST_TEXTURE, Rect2(pos - size / 2.0, size), source, tint)
