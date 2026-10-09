extends RefCounted

## Original station textures and sprites, generated once per game.


static func wall() -> ImageTexture:
    var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in 64:
        for x in 64:
            var shade := 0.22 + float((x * 13 + y * 7) % 5) * 0.008
            var color := Color(shade * 0.8, shade, shade * 1.2)
            if x % 32 < 2 or y % 32 < 2:
                color = Color("151b25")
            if y >= 26 and y < 30:
                color = Color("c37932") if (x / 6) % 2 == 0 else Color("392e25")
            if (x % 32 == 5 or x % 32 == 26) and (y % 32 == 5 or y % 32 == 26):
                color = Color("9daab4")
            image.set_pixel(x, y, color)
    return ImageTexture.create_from_image(image)


static func floor_tile() -> ImageTexture:
    var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color("252c37"))
    for y in 32:
        for x in 32:
            if x == 0 or y == 0:
                image.set_pixel(x, y, Color("121923"))
            elif x % 8 == y % 8:
                image.set_pixel(x, y, Color("35414e"))
    return ImageTexture.create_from_image(image)


static func guard(boss: bool = false) -> ImageTexture:
    var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
    var armor := Color("bc493e") if boss else Color("586997")
    image.fill_rect(Rect2i(11, 3, 10, 10), Color("223044"))
    image.fill_rect(Rect2i(12, 7, 9, 3), Color("efb755") if boss else Color("62e2cb"))
    image.fill_rect(Rect2i(7, 15, 18, 15), armor.darkened(0.3))
    image.fill_rect(Rect2i(10, 13, 13, 14), armor)
    image.fill_rect(Rect2i(14, 15, 5, 8), armor.lightened(0.25))
    image.fill_rect(Rect2i(4, 18, 6, 14), armor.darkened(0.2))
    image.fill_rect(Rect2i(23, 18, 5, 12), armor.darkened(0.2))
    image.fill_rect(Rect2i(9, 29, 6, 14), Color("253543"))
    image.fill_rect(Rect2i(18, 29, 6, 14), Color("253543"))
    image.fill_rect(Rect2i(8, 42, 8, 4), Color("111923"))
    image.fill_rect(Rect2i(17, 42, 8, 4), Color("111923"))
    image.fill_rect(Rect2i(4, 27, 17, 4), Color("14202a"))
    image.fill_rect(Rect2i(13, 25, 7, 3), Color("b8c6cc"))
    return ImageTexture.create_from_image(image)


static func pickup(kind: String) -> ImageTexture:
    var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
    match kind:
        "health":
            image.fill_rect(Rect2i(3, 5, 18, 15), Color("e0ddd0"))
            image.fill_rect(Rect2i(9, 7, 6, 11), Color("d74646"))
            image.fill_rect(Rect2i(6, 10, 12, 5), Color("d74646"))
        "ammo":
            image.fill_rect(Rect2i(3, 6, 18, 14), Color("60513c"))
            for x in [6, 11, 16]:
                image.fill_rect(Rect2i(x, 7, 3, 10), Color("edbe5d"))
                image.fill_rect(Rect2i(x, 5, 3, 2), Color("d97739"))
        "key":
            image.fill_rect(Rect2i(2, 6, 20, 12), Color("f2cf60"))
            image.fill_rect(Rect2i(5, 9, 5, 6), Color("8d5c28"))
            image.fill_rect(Rect2i(13, 9, 6, 2), Color("fff2b3"))
    return ImageTexture.create_from_image(image)
