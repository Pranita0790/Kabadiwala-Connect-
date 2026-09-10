from __future__ import annotations

import csv
import shutil
from pathlib import Path

import torch
from PIL import Image
from torchvision import models, transforms


# ============================================================
# PATHS
# ============================================================

ROOT = Path(__file__).resolve().parents[1]

DATA_ROOT = (
    ROOT
    / "data"
    / "processed"
    / "baseline_clean"
)

TEST_ROOT = DATA_ROOT / "images" / "test"

TRAINING_ROOT = DATA_ROOT / "training"

MODEL_PATH = (
    TRAINING_ROOT
    / "best_model.pth"
)

OUTPUT_ROOT = (
    TRAINING_ROOT
    / "misclassified"
)

CSV_PATH = (
    TRAINING_ROOT
    / "error_analysis.csv"
)


# ============================================================
# CONFIG
# ============================================================

IMAGE_SIZE = 224

DEVICE = torch.device("cpu")

TRANSFORM = transforms.Compose(
    [
        transforms.Resize(
            (IMAGE_SIZE, IMAGE_SIZE)
        ),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[
                0.485,
                0.456,
                0.406,
            ],
            std=[
                0.229,
                0.224,
                0.225,
            ],
        ),
    ]
)


# ============================================================
# MODEL
# ============================================================

def load_model():

    checkpoint = torch.load(
        MODEL_PATH,
        map_location=DEVICE,
    )

    class_names = checkpoint[
        "class_names"
    ]

    model = models.mobilenet_v3_small(
        weights=None
    )

    in_features = (
        model.classifier[-1].in_features
    )

    model.classifier[-1] = torch.nn.Linear(
        in_features,
        len(class_names),
    )

    model.load_state_dict(
        checkpoint[
            "model_state_dict"
        ]
    )

    model.to(DEVICE)

    model.eval()

    return model, class_names


# ============================================================
# PREDICTION
# ============================================================

def predict(
    model,
    image,
):

    tensor = TRANSFORM(
        image
    ).unsqueeze(0)

    with torch.no_grad():

        logits = model(
            tensor
        )

        probabilities = torch.softmax(
            logits,
            dim=1,
        )

    confidence, prediction = (
        probabilities.max(dim=1)
    )

    return (
        prediction.item(),
        confidence.item(),
    )


# ============================================================
# MAIN
# ============================================================

def main():

    if not MODEL_PATH.exists():

        raise FileNotFoundError(
            f"Model not found:\n{MODEL_PATH}"
        )

    print("=" * 70)
    print(
        "Kabadiwala Connect — "
        "Baseline Error Analysis"
    )
    print("=" * 70)

    model, class_names = load_model()

    print(
        "\nClasses:"
    )

    for index, name in enumerate(
        class_names
    ):

        print(
            f"  {index}: {name}"
        )

    # --------------------------------------------------------
    # Recreate output directory.
    # --------------------------------------------------------

    if OUTPUT_ROOT.exists():

        print(
            "\nRemoving previous error-analysis output..."
        )

        shutil.rmtree(
            OUTPUT_ROOT
        )

    OUTPUT_ROOT.mkdir(
        parents=True,
        exist_ok=True,
    )

    rows = []

    total = 0
    correct = 0
    errors = 0

    # --------------------------------------------------------
    # Iterate over test images.
    # --------------------------------------------------------

    for true_class in class_names:

        class_dir = (
            TEST_ROOT
            / true_class
        )

        if not class_dir.exists():
            continue

        for image_path in sorted(
            class_dir.glob("*.jpg")
        ):

            total += 1

            try:

                with Image.open(
                    image_path
                ) as image:

                    image = image.convert(
                        "RGB"
                    )

                    predicted_index, confidence = (
                        predict(
                            model,
                            image,
                        )
                    )

            except Exception as exc:

                print(
                    f"[WARNING] "
                    f"Could not process "
                    f"{image_path}: {exc}"
                )

                continue

            predicted_class = (
                class_names[
                    predicted_index
                ]
            )

            is_correct = (
                predicted_class
                == true_class
            )

            if is_correct:

                correct += 1

            else:

                errors += 1

                destination = (
                    OUTPUT_ROOT
                    / (
                        f"{true_class}"
                        f"_TO_"
                        f"{predicted_class}"
                    )
                )

                destination.mkdir(
                    parents=True,
                    exist_ok=True,
                )

                shutil.copy2(
                    image_path,
                    destination
                    / image_path.name,
                )

            rows.append(
                {
                    "filename":
                        image_path.name,

                    "true_class":
                        true_class,

                    "predicted_class":
                        predicted_class,

                    "confidence":
                        round(
                            confidence,
                            6,
                        ),

                    "correct":
                        is_correct,
                }
            )

    # --------------------------------------------------------
    # Save CSV.
    # --------------------------------------------------------

    with CSV_PATH.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as f:

        writer = csv.DictWriter(
            f,
            fieldnames=[
                "filename",
                "true_class",
                "predicted_class",
                "confidence",
                "correct",
            ],
        )

        writer.writeheader()

        writer.writerows(
            rows
        )

    # --------------------------------------------------------
    # Summary.
    # --------------------------------------------------------

    print(
        "\n"
        + "=" * 70
    )

    print(
        "ERROR ANALYSIS SUMMARY"
    )

    print(
        "=" * 70
    )

    print(
        f"\nTotal test images: "
        f"{total}"
    )

    print(
        f"Correct: "
        f"{correct}"
    )

    print(
        f"Misclassified: "
        f"{errors}"
    )

    if total:

        print(
            f"Accuracy: "
            f"{correct / total:.4f}"
        )

    # --------------------------------------------------------
    # Print errors.
    # --------------------------------------------------------

    print(
        "\nMisclassified images:"
    )

    for row in rows:

        if not row["correct"]:

            print(
                f"  {row['true_class']}"
                f" -> "
                f"{row['predicted_class']}"
                f" | "
                f"confidence="
                f"{row['confidence']}"
                f" | "
                f"{row['filename']}"
            )

    print(
        "\nError folders:"
    )

    if errors == 0:

        print(
            "  None — test set had no errors."
        )

    else:

        for path in sorted(
            OUTPUT_ROOT.iterdir()
        ):

            if path.is_dir():

                count = len(
                    list(
                        path.glob(
                            "*.jpg"
                        )
                    )
                )

                print(
                    f"  {path.name}: "
                    f"{count} image(s)"
                )

    print(
        f"\nCSV:"
        f"\n{CSV_PATH}"
    )

    print(
        f"\nMisclassified images:"
        f"\n{OUTPUT_ROOT}"
    )

    print(
        "\nDONE."
    )


if __name__ == "__main__":
    main()