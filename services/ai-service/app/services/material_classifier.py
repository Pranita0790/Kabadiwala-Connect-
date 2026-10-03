from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageFilter, ImageStat

from app.services.material_capabilities import MODEL_SUPPORTED_MATERIALS, SUPPORTED_MATERIALS


@dataclass(frozen=True)
class MaterialClassification:
    material: str
    confidence: float


MODEL_VERSION = "sih-visual-v2"
CONFIDENCE_THRESHOLD = 0.60
DRY_RECYCLABLE_OVERRIDE = 0.58

MODEL_PATH = (
    Path(__file__).resolve().parents[4]
    / "data"
    / "processed"
    / "sih_5class"
    / "training"
    / "best_model.pth"
)

TYPICAL_WEIGHT_KG: dict[str, float] = {
    "paper": 2.0,
    "book": 3.0,
    "mixed_plastics": 4.0,
    "pcb": 1.5,
    "cable": 5.0,
    "battery": 2.0,
    "lcd_panel": 8.0,
    "crt": 12.0,
    "motor": 15.0,
    "magnet_bearing_assembly": 10.0,
    "unknown": 5.0,
}

SUGGESTED_CONDITION: dict[str, str] = {
    "paper": "average",
    "book": "average",
    "mixed_plastics": "good",
    "pcb": "scrap",
    "cable": "average",
    "battery": "average",
    "lcd_panel": "average",
    "crt": "scrap",
    "motor": "scrap",
    "magnet_bearing_assembly": "scrap",
    "unknown": "average",
}

_model = None
_class_names: tuple[str, ...] | None = None
_torch_ready: bool | None = None
_transform = None
_torch = None
_models = None
_transforms = None


def _try_import_torch() -> bool:
    """Load torch lazily so the API can start without GPU ML deps."""
    global _torch_ready, _torch, _models, _transforms, _transform

    if _torch_ready is not None:
        return _torch_ready

    try:
        import torch
        from torchvision import models, transforms

        _torch = torch
        _models = models
        _transforms = transforms
        _transform = transforms.Compose(
            [
                transforms.Resize((224, 224)),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225],
                ),
            ]
        )
        _torch_ready = True
    except Exception:
        _torch_ready = False

    return _torch_ready


def _load_model():
    global _model, _class_names

    if _model is not None and _class_names is not None:
        return _model, _class_names

    if not _try_import_torch():
        return None, None

    if not MODEL_PATH.exists():
        return None, None

    torch = _torch
    models = _models
    device = torch.device("cpu")

    checkpoint = torch.load(
        MODEL_PATH,
        map_location=device,
    )

    class_names = tuple(checkpoint["class_names"])

    unexpected_classes = set(class_names) - set(MODEL_SUPPORTED_MATERIALS)

    if unexpected_classes:
        raise ValueError(
            f"Model contains unsupported material classes: {unexpected_classes}"
        )

    model = models.mobilenet_v3_small(weights=None)
    in_features = model.classifier[-1].in_features
    model.classifier[-1] = torch.nn.Linear(in_features, len(class_names))
    model.load_state_dict(checkpoint["model_state_dict"])
    model.to(device)
    model.eval()

    _model = model
    _class_names = class_names
    return _model, _class_names


def _classify_with_model(image: Image.Image) -> MaterialClassification | None:
    model, class_names = _load_model()
    if model is None or class_names is None or _transform is None or _torch is None:
        return None

    torch = _torch
    image = image.convert("RGB")
    tensor = _transform(image).unsqueeze(0)

    with torch.no_grad():
        outputs = model(tensor)
        probabilities = torch.softmax(outputs, dim=1)

    confidence, predicted_index = probabilities.max(dim=1)
    confidence_value = float(confidence.item())

    if confidence_value < CONFIDENCE_THRESHOLD:
        return MaterialClassification(
            material="unknown",
            confidence=confidence_value,
        )

    material = class_names[predicted_index.item()]
    return MaterialClassification(
        material=material,
        confidence=confidence_value,
    )


def _image_stats(image: Image.Image) -> dict[str, float]:
    rgb = image.convert("RGB").resize((96, 96))
    pixels = list(rgb.getdata())
    count = max(len(pixels), 1)

    avg_r = sum(p[0] for p in pixels) / count
    avg_g = sum(p[1] for p in pixels) / count
    avg_b = sum(p[2] for p in pixels) / count
    brightness = (avg_r + avg_g + avg_b) / 3.0
    saturation = max(avg_r, avg_g, avg_b) - min(avg_r, avg_g, avg_b)

    white = 0
    bright = 0
    dark = 0
    green = 0
    copper = 0
    colorful = 0
    cream = 0
    for r, g, b in pixels:
        lum = (r + g + b) / 3.0
        sat = max(r, g, b) - min(r, g, b)
        if lum > 200:
            bright += 1
        if lum < 55:
            dark += 1
        if r > 200 and g > 200 and b > 200 and sat < 28:
            white += 1
        if r > 190 and g > 170 and b > 140 and sat < 50 and r >= g >= b - 8:
            cream += 1
        if g > r + 12 and g > b + 8:
            green += 1
        if r > g + 22 and r > b + 18 and g > b:
            copper += 1
        if sat > 55:
            colorful += 1

    gray = rgb.convert("L")
    variance = float(ImageStat.Stat(gray).var[0])
    edges = gray.filter(ImageFilter.FIND_EDGES)
    edge_mean = float(ImageStat.Stat(edges).mean[0])

    return {
        "avg_r": avg_r,
        "avg_g": avg_g,
        "avg_b": avg_b,
        "brightness": brightness,
        "saturation": saturation,
        "white_frac": white / count,
        "bright_frac": bright / count,
        "dark_frac": dark / count,
        "green_frac": green / count,
        "copper_frac": copper / count,
        "colorful_frac": colorful / count,
        "cream_frac": cream / count,
        "variance": variance,
        "edge_mean": edge_mean,
    }


def _classify_heuristic(image: Image.Image) -> MaterialClassification:
    """
    Visual inference for local lots: e-waste plus paper, books, and plastic.

    Colour/texture statistics, not elemental proof (AGENTS.md section 7).
    """
    s = _image_stats(image)

    scores: dict[str, float] = {name: 0.0 for name in SUPPORTED_MATERIALS}

    paper_signal = (
        0.45 * s["white_frac"]
        + 0.25 * s["cream_frac"]
        + 0.20 * s["bright_frac"]
        + (0.12 if s["saturation"] < 28 else 0.0)
        + (0.08 if s["variance"] < 1800 else 0.0)
    )
    book_signal = (
        0.22 * s["cream_frac"]
        + 0.18 * (1.0 - s["bright_frac"])
        + (0.20 if 900 < s["variance"] < 4500 else 0.0)
        + (0.16 if s["edge_mean"] > 12 else 0.0)
        + (0.10 if 70 < s["brightness"] < 190 else 0.0)
        + (0.10 if s["colorful_frac"] < 0.35 else 0.0)
    )
    plastic_signal = (
        0.55 * s["colorful_frac"]
        + (0.22 if s["saturation"] > 40 else 0.0)
        + (0.12 if s["bright_frac"] > 0.15 and s["saturation"] > 30 else 0.0)
        + (0.08 if s["green_frac"] < 0.20 else 0.0)
    )

    scores["paper"] = paper_signal
    scores["book"] = book_signal
    scores["mixed_plastics"] = plastic_signal
    scores["pcb"] = 0.90 * s["green_frac"] + (0.15 if s["avg_g"] > s["avg_r"] + 10 else 0.0)
    scores["cable"] = 0.90 * s["copper_frac"] + (
        0.15 if s["avg_r"] > s["avg_g"] + 18 else 0.0
    )
    scores["battery"] = (
        0.70 * s["dark_frac"]
        + (0.20 if s["saturation"] < 35 and s["brightness"] < 80 else 0.0)
    )
    scores["lcd_panel"] = (
        (0.25 if s["brightness"] > 140 and s["saturation"] < 45 and s["white_frac"] < 0.35 else 0.0)
        + (0.20 if s["edge_mean"] > 18 else 0.0)
        + 0.10 * (1.0 - s["colorful_frac"])
    )
    scores["crt"] = (
        (0.25 if 50 < s["brightness"] < 130 and s["saturation"] < 30 else 0.0)
        + 0.20 * s["dark_frac"]
    )
    scores["motor"] = (0.20 if s["dark_frac"] > 0.35 and s["edge_mean"] > 16 else 0.0)
    scores["magnet_bearing_assembly"] = scores["motor"] * 0.4

    material, raw = max(scores.items(), key=lambda item: item[1])
    if raw < 0.18:
        material = "unknown"
        confidence = 0.45
    else:
        confidence = min(0.92, 0.55 + raw * 0.45)

    return MaterialClassification(material=material, confidence=confidence)


def classify_material(image: Image.Image) -> MaterialClassification:
    heuristic = _classify_heuristic(image)
    dry_recyclables = {"paper", "book", "mixed_plastics"}

    # 5-class e-waste weights cannot label paper/books/plastic. Prefer the
    # visual rule when it is clearly a dry recyclable.
    if heuristic.material in dry_recyclables and heuristic.confidence >= DRY_RECYCLABLE_OVERRIDE:
        return heuristic

    model_result = _classify_with_model(image)
    if model_result is not None and model_result.material != "unknown":
        return model_result

    return heuristic


def typical_weight_kg(material: str) -> float:
    return TYPICAL_WEIGHT_KG.get(material, 5.0)


def suggested_condition(material: str) -> str:
    return SUGGESTED_CONDITION.get(material, "average")
