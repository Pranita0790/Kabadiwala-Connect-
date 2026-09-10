from dataclasses import dataclass
from pathlib import Path

import torch
from PIL import Image
from torchvision import models, transforms

from app.services.material_capabilities import MODEL_SUPPORTED_MATERIALS


@dataclass(frozen=True)
class MaterialClassification:
    material: str
    confidence: float


MODEL_VERSION = "baseline-3class-v1"
CONFIDENCE_THRESHOLD = 0.60

MODEL_PATH = (
    Path(__file__).resolve().parents[4]
    / "data"
    / "processed"
    / "baseline_clean"
    / "training"
    / "best_model.pth"
)

DEVICE = torch.device("cpu")

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


def _load_model():
    checkpoint = torch.load(
        MODEL_PATH,
        map_location=DEVICE,
    )

    class_names = tuple(checkpoint["class_names"])

    unexpected_classes = set(class_names) - set(MODEL_SUPPORTED_MATERIALS)

    if unexpected_classes:
        raise ValueError(
            f"Model contains unsupported material classes: {unexpected_classes}"
        )

    model = models.mobilenet_v3_small(weights=None)

    in_features = model.classifier[-1].in_features

    model.classifier[-1] = torch.nn.Linear(
        in_features,
        len(class_names),
    )

    model.load_state_dict(checkpoint["model_state_dict"])
    model.to(DEVICE)
    model.eval()

    return model, class_names


_model, _class_names = _load_model()


def classify_material(
    image: Image.Image,
) -> MaterialClassification:

    image = image.convert("RGB")

    tensor = _transform(image).unsqueeze(0)

    with torch.no_grad():
        outputs = _model(tensor)
        probabilities = torch.softmax(outputs, dim=1)

    confidence, predicted_index = probabilities.max(dim=1)

    confidence_value = float(confidence.item())

    if confidence_value < CONFIDENCE_THRESHOLD:
        return MaterialClassification(
            material="unknown",
            confidence=confidence_value,
        )

    material = _class_names[predicted_index.item()]

    return MaterialClassification(
        material=material,
        confidence=confidence_value,
    )
