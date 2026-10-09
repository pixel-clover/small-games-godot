extends Control

## Hosts the forest in a fixed 320x180 SubViewport, scaled up with crisp pixels.

const VW := 320
const VH := 180

var container: SubViewportContainer
var ui: Node2D


func _ready() -> void:
    var win := get_window()
    win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    win.size = Vector2i(1280, 720)

    var bg := ColorRect.new()
    bg.color = Color.BLACK
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    container = SubViewportContainer.new()
    container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var viewport := SubViewport.new()
    viewport.size = Vector2i(VW, VH)
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    container.add_child(viewport)
    add_child(container)

    var world := Node2D.new()
    world.set_script(load("res://games/forest/forest_world.gd"))
    viewport.add_child(world)
    # Draw text at window resolution while the forest keeps its pixel canvas.
    ui = world.get("ui") as Node2D
    ui.reparent(self)

    get_viewport().size_changed.connect(_layout)
    _layout()


func _layout() -> void:
    var vs := get_viewport_rect().size
    var s := maxf(floorf(minf(vs.x / VW, vs.y / VH)), 1.0)
    container.size = Vector2(VW, VH)
    container.scale = Vector2(s, s)
    container.position = ((vs - Vector2(VW, VH) * s) / 2.0).floor()
    ui.scale = container.scale
    ui.position = container.position


func _exit_tree() -> void:
    # Restore the settings the other mini-games expect.
    var win := get_window()
    win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    win.size = Vector2i(640, 480)
