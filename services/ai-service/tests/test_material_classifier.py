from PIL import Image, ImageDraw

from app.services.material_classifier import classify_material, typical_weight_kg


def _solid(color: tuple[int, int, int]) -> Image.Image:
    return Image.new("RGB", (128, 128), color)


def _pcb_like() -> Image.Image:
    """Populated green FR4: black headers + gold pads. Must not look like a book."""
    image = Image.new("RGB", (224, 224), (28, 128, 58))
    draw = ImageDraw.Draw(image)
    for left in (18, 70, 122, 174):
        draw.rectangle((left, 16, left + 32, 58), fill=(22, 22, 22))
        draw.rectangle((left, 168, left + 32, 210), fill=(22, 22, 22))
    draw.rectangle((40, 80, 90, 110), fill=(18, 18, 18))
    draw.rectangle((130, 85, 190, 125), fill=(16, 16, 16))
    for x in range(24, 210, 10):
        draw.rectangle((x, 140, x + 5, 148), fill=(198, 158, 42))
    return image


def test_white_sheet_is_paper():
    result = classify_material(_solid((245, 245, 242)))
    assert result.material == "paper"
    assert typical_weight_kg("paper") == 2.0


def test_saturated_colour_is_plastic():
    result = classify_material(_solid((30, 90, 220)))
    assert result.material == "mixed_plastics"


def test_green_board_is_pcb():
    result = classify_material(_solid((40, 140, 55)))
    assert result.material == "pcb"


def test_populated_pcb_is_not_book():
    result = classify_material(_pcb_like())
    assert result.material == "pcb"
    assert result.confidence >= 0.60


def _nine_volt_battery() -> Image.Image:
    """HIW-style 6F22 9V: white label, red brand, cyan body. Must not be a book."""
    image = Image.new("RGB", (224, 224), (168, 132, 92))
    draw = ImageDraw.Draw(image)
    draw.rectangle((58, 18, 166, 206), fill=(236, 238, 242))
    draw.rectangle((58, 18, 166, 108), fill=(248, 248, 250))
    draw.rectangle((70, 34, 154, 78), fill=(196, 36, 42))
    draw.rectangle((58, 118, 166, 206), fill=(46, 148, 210))
    draw.rectangle((78, 138, 146, 168), fill=(230, 240, 248))
    return image


def test_nine_volt_pack_is_battery_not_book():
    result = classify_material(_nine_volt_battery())
    assert result.material == "battery"
    assert result.confidence >= 0.60


def _blue_buck_module() -> Image.Image:
    """Blue FR4 LM2596-style module with electrolytic caps. Must not be a display."""
    image = Image.new("RGB", (224, 224), (28, 78, 168))
    draw = ImageDraw.Draw(image)
    draw.ellipse((28, 24, 88, 84), fill=(18, 18, 18))
    draw.ellipse((132, 22, 196, 86), fill=(16, 16, 16))
    draw.rectangle((86, 96, 148, 158), fill=(12, 12, 12))
    draw.rectangle((40, 168, 100, 198), fill=(24, 24, 24))
    draw.rectangle((16, 200, 208, 214), fill=(236, 236, 240))
    return image


def test_blue_converter_module_is_pcb_not_display():
    result = classify_material(_blue_buck_module())
    assert result.material == "pcb"
    assert result.confidence >= 0.60
