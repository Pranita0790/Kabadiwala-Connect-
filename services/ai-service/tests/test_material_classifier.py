from PIL import Image

from app.services.material_classifier import classify_material, typical_weight_kg


def _solid(color: tuple[int, int, int]) -> Image.Image:
    return Image.new("RGB", (128, 128), color)


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
