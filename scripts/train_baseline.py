from __future__ import annotations

import csv
import random
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import torch
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    ConfusionMatrixDisplay,
    f1_score,
    precision_score,
    recall_score,
)
from torch import nn, optim
from torch.utils.data import DataLoader
from torchvision import datasets, models, transforms


# ============================================================
# CONFIGURATION
# ============================================================

ROOT = Path(__file__).resolve().parents[1]

DATA_ROOT = (
    ROOT
    / "data"
    / "processed"
    / "baseline_clean"
    / "images"
)

OUTPUT_ROOT = (
    ROOT
    / "data"
    / "processed"
    / "baseline_clean"
    / "training"
)

SEED = 42

IMAGE_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 10
LEARNING_RATE = 1e-3

NUM_WORKERS = 0

DEVICE = torch.device("cpu")


# ============================================================
# REPRODUCIBILITY
# ============================================================

def set_seed(seed: int):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


# ============================================================
# DATA TRANSFORMS
# ============================================================

train_transform = transforms.Compose(
    [
        transforms.Resize(
            (IMAGE_SIZE, IMAGE_SIZE)
        ),

        transforms.RandomHorizontalFlip(
            p=0.5
        ),

        transforms.RandomRotation(
            degrees=10
        ),

        transforms.ColorJitter(
            brightness=0.15,
            contrast=0.15,
            saturation=0.15,
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


eval_transform = transforms.Compose(
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
# DATASET
# ============================================================

def create_datasets():

    train_dataset = datasets.ImageFolder(
        DATA_ROOT / "train",
        transform=train_transform,
    )

    val_dataset = datasets.ImageFolder(
        DATA_ROOT / "val",
        transform=eval_transform,
    )

    test_dataset = datasets.ImageFolder(
        DATA_ROOT / "test",
        transform=eval_transform,
    )

    return (
        train_dataset,
        val_dataset,
        test_dataset,
    )


# ============================================================
# DATALOADERS
# ============================================================

def create_loaders(
    train_dataset,
    val_dataset,
    test_dataset,
):

    train_loader = DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
        num_workers=NUM_WORKERS,
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=NUM_WORKERS,
    )

    test_loader = DataLoader(
        test_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=NUM_WORKERS,
    )

    return (
        train_loader,
        val_loader,
        test_loader,
    )


# ============================================================
# MODEL
# ============================================================

def create_model(num_classes: int):

    weights = (
        models.MobileNet_V3_Small_Weights.DEFAULT
    )

    model = models.mobilenet_v3_small(
        weights=weights
    )

    # --------------------------------------------------------
    # Freeze pretrained backbone.
    # --------------------------------------------------------

    for parameter in model.parameters():
        parameter.requires_grad = False

    # --------------------------------------------------------
    # Replace classifier.
    # --------------------------------------------------------

    in_features = (
        model.classifier[-1].in_features
    )

    model.classifier[-1] = nn.Linear(
        in_features,
        num_classes,
    )

    return model.to(DEVICE)


# ============================================================
# CLASS WEIGHTS
# ============================================================

def calculate_class_weights(dataset):

    targets = np.array(
        dataset.targets
    )

    counts = np.bincount(
        targets
    )

    total = counts.sum()
    num_classes = len(counts)

    weights = (
        total
        / (
            num_classes
            * counts
        )
    )

    weights = torch.tensor(
        weights,
        dtype=torch.float32,
        device=DEVICE,
    )

    return weights


# ============================================================
# TRAIN / VALIDATE
# ============================================================

def run_epoch(
    model,
    loader,
    criterion,
    optimizer=None,
):

    training = optimizer is not None

    if training:
        model.train()
    else:
        model.eval()

    running_loss = 0.0

    all_targets = []
    all_predictions = []

    for images, targets in loader:

        images = images.to(DEVICE)
        targets = targets.to(DEVICE)

        if training:
            optimizer.zero_grad()

        with torch.set_grad_enabled(
            training
        ):

            outputs = model(images)

            loss = criterion(
                outputs,
                targets,
            )

            if training:
                loss.backward()
                optimizer.step()

        running_loss += (
            loss.item()
            * images.size(0)
        )

        predictions = (
            outputs.argmax(dim=1)
        )

        all_targets.extend(
            targets.cpu().numpy()
        )

        all_predictions.extend(
            predictions.cpu().numpy()
        )

    epoch_loss = (
        running_loss
        / len(loader.dataset)
    )

    epoch_accuracy = accuracy_score(
        all_targets,
        all_predictions,
    )

    epoch_f1 = f1_score(
        all_targets,
        all_predictions,
        average="macro",
        zero_division=0,
    )

    return (
        epoch_loss,
        epoch_accuracy,
        epoch_f1,
    )


# ============================================================
# FULL EVALUATION
# ============================================================

def evaluate(
    model,
    loader,
    class_names,
):

    model.eval()

    targets = []
    predictions = []

    with torch.no_grad():

        for images, labels in loader:

            images = images.to(DEVICE)

            outputs = model(
                images
            )

            preds = (
                outputs.argmax(dim=1)
                .cpu()
                .numpy()
            )

            predictions.extend(
                preds
            )

            targets.extend(
                labels.numpy()
            )

    accuracy = accuracy_score(
        targets,
        predictions,
    )

    precision = precision_score(
        targets,
        predictions,
        average="macro",
        zero_division=0,
    )

    recall = recall_score(
        targets,
        predictions,
        average="macro",
        zero_division=0,
    )

    f1 = f1_score(
        targets,
        predictions,
        average="macro",
        zero_division=0,
    )

    report = classification_report(
        targets,
        predictions,
        target_names=class_names,
        zero_division=0,
    )

    matrix = confusion_matrix(
        targets,
        predictions,
    )

    return (
        accuracy,
        precision,
        recall,
        f1,
        report,
        matrix,
    )


# ============================================================
# PLOTS
# ============================================================

def save_training_history(history):

    plt.figure()

    epochs = range(
        1,
        len(history["train_loss"]) + 1,
    )

    plt.plot(
        epochs,
        history["train_loss"],
        label="Train Loss",
    )

    plt.plot(
        epochs,
        history["val_loss"],
        label="Validation Loss",
    )

    plt.xlabel("Epoch")
    plt.ylabel("Loss")
    plt.title(
        "Kabadiwala Connect Baseline Training"
    )

    plt.legend()

    plt.tight_layout()

    plt.savefig(
        OUTPUT_ROOT
        / "training_history.png",
        dpi=150,
    )

    plt.close()


def save_confusion_matrix(
    matrix,
    class_names,
):

    display = ConfusionMatrixDisplay(
        confusion_matrix=matrix,
        display_labels=class_names,
    )

    display.plot(
        xticks_rotation=45
    )

    plt.title(
        "Baseline Test Confusion Matrix"
    )

    plt.tight_layout()

    plt.savefig(
        OUTPUT_ROOT
        / "confusion_matrix.png",
        dpi=150,
    )

    plt.close()


# ============================================================
# MAIN
# ============================================================

def main():

    set_seed(SEED)

    OUTPUT_ROOT.mkdir(
        parents=True,
        exist_ok=True,
    )

    print("=" * 70)
    print(
        "Kabadiwala Connect — "
        "MobileNetV3-Small Baseline"
    )
    print("=" * 70)

    print(
        f"\nDevice: {DEVICE}"
    )

    print(
        f"Epochs: {EPOCHS}"
    )

    print(
        f"Batch size: {BATCH_SIZE}"
    )

    # --------------------------------------------------------
    # Dataset
    # --------------------------------------------------------

    (
        train_dataset,
        val_dataset,
        test_dataset,
    ) = create_datasets()

    class_names = (
        train_dataset.classes
    )

    num_classes = len(
        class_names
    )

    print(
        "\nClasses:"
    )

    for index, name in enumerate(
        class_names
    ):

        print(
            f"  {index}: {name}"
        )

    print(
        f"\nTrain images: "
        f"{len(train_dataset)}"
    )

    print(
        f"Validation images: "
        f"{len(val_dataset)}"
    )

    print(
        f"Test images: "
        f"{len(test_dataset)}"
    )

    # --------------------------------------------------------
    # Loaders
    # --------------------------------------------------------

    (
        train_loader,
        val_loader,
        test_loader,
    ) = create_loaders(
        train_dataset,
        val_dataset,
        test_dataset,
    )

    # --------------------------------------------------------
    # Model
    # --------------------------------------------------------

    model = create_model(
        num_classes
    )

    # --------------------------------------------------------
    # Class-weighted loss
    # --------------------------------------------------------

    class_weights = (
        calculate_class_weights(
            train_dataset
        )
    )

    print(
        "\nClass weights:"
    )

    for name, weight in zip(
        class_names,
        class_weights.cpu().numpy(),
    ):

        print(
            f"  {name}: "
            f"{weight:.4f}"
        )

    criterion = nn.CrossEntropyLoss(
        weight=class_weights
    )

    optimizer = optim.Adam(
        model.classifier.parameters(),
        lr=LEARNING_RATE,
    )

    # --------------------------------------------------------
    # Training
    # --------------------------------------------------------

    history = {
        "train_loss": [],
        "val_loss": [],
        "train_accuracy": [],
        "val_accuracy": [],
        "train_f1": [],
        "val_f1": [],
    }

    best_val_f1 = -1.0

    best_model_path = (
        OUTPUT_ROOT
        / "best_model.pth"
    )

    print(
        "\nStarting training..."
    )

    for epoch in range(
        1,
        EPOCHS + 1,
    ):

        train_loss, train_acc, train_f1 = (
            run_epoch(
                model,
                train_loader,
                criterion,
                optimizer,
            )
        )

        val_loss, val_acc, val_f1 = (
            run_epoch(
                model,
                val_loader,
                criterion,
            )
        )

        history[
            "train_loss"
        ].append(train_loss)

        history[
            "val_loss"
        ].append(val_loss)

        history[
            "train_accuracy"
        ].append(train_acc)

        history[
            "val_accuracy"
        ].append(val_acc)

        history[
            "train_f1"
        ].append(train_f1)

        history[
            "val_f1"
        ].append(val_f1)

        print(
            f"\nEpoch {epoch}/{EPOCHS}"
        )

        print(
            f"  Train loss: "
            f"{train_loss:.4f}"
        )

        print(
            f"  Train accuracy: "
            f"{train_acc:.4f}"
        )

        print(
            f"  Train macro-F1: "
            f"{train_f1:.4f}"
        )

        print(
            f"  Val loss: "
            f"{val_loss:.4f}"
        )

        print(
            f"  Val accuracy: "
            f"{val_acc:.4f}"
        )

        print(
            f"  Val macro-F1: "
            f"{val_f1:.4f}"
        )

        # ----------------------------------------------------
        # Save best model using validation macro-F1.
        # ----------------------------------------------------

        if val_f1 > best_val_f1:

            best_val_f1 = val_f1

            torch.save(
                {
                    "model_state_dict":
                        model.state_dict(),
                    "class_names":
                        class_names,
                    "image_size":
                        IMAGE_SIZE,
                    "seed":
                        SEED,
                },
                best_model_path,
            )

            print(
                "  ✓ Best model saved"
            )

    # --------------------------------------------------------
    # Save training metrics.
    # --------------------------------------------------------

    metrics_path = (
        OUTPUT_ROOT
        / "metrics.csv"
    )

    with metrics_path.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as f:

        writer = csv.writer(f)

        writer.writerow(
            [
                "epoch",
                "train_loss",
                "val_loss",
                "train_accuracy",
                "val_accuracy",
                "train_macro_f1",
                "val_macro_f1",
            ]
        )

        for i in range(EPOCHS):

            writer.writerow(
                [
                    i + 1,
                    history[
                        "train_loss"
                    ][i],
                    history[
                        "val_loss"
                    ][i],
                    history[
                        "train_accuracy"
                    ][i],
                    history[
                        "val_accuracy"
                    ][i],
                    history[
                        "train_f1"
                    ][i],
                    history[
                        "val_f1"
                    ][i],
                ]
            )

    save_training_history(
        history
    )

    # --------------------------------------------------------
    # Load best model.
    # --------------------------------------------------------

    checkpoint = torch.load(
        best_model_path,
        map_location=DEVICE,
    )

    model.load_state_dict(
        checkpoint[
            "model_state_dict"
        ]
    )

    # --------------------------------------------------------
    # Test evaluation.
    # --------------------------------------------------------

    (
        test_accuracy,
        test_precision,
        test_recall,
        test_f1,
        report,
        matrix,
    ) = evaluate(
        model,
        test_loader,
        class_names,
    )

    print(
        "\n"
        + "=" * 70
    )

    print(
        "FINAL TEST RESULTS"
    )

    print(
        "=" * 70
    )

    print(
        f"\nAccuracy: "
        f"{test_accuracy:.4f}"
    )

    print(
        f"Macro Precision: "
        f"{test_precision:.4f}"
    )

    print(
        f"Macro Recall: "
        f"{test_recall:.4f}"
    )

    print(
        f"Macro F1: "
        f"{test_f1:.4f}"
    )

    print(
        "\nClassification report:"
    )

    print(report)

    print(
        "Confusion matrix:"
    )

    print(matrix)

    save_confusion_matrix(
        matrix,
        class_names,
    )

    # --------------------------------------------------------
    # Save final summary.
    # --------------------------------------------------------

    summary_path = (
        OUTPUT_ROOT
        / "test_results.txt"
    )

    summary_path.write_text(
        (
            "Kabadiwala Connect "
            "MobileNetV3-Small Baseline\n\n"
            f"Accuracy: {test_accuracy:.4f}\n"
            f"Macro Precision: "
            f"{test_precision:.4f}\n"
            f"Macro Recall: "
            f"{test_recall:.4f}\n"
            f"Macro F1: "
            f"{test_f1:.4f}\n\n"
            "Classification Report\n"
            "---------------------\n"
            f"{report}\n"
            "Confusion Matrix\n"
            "----------------\n"
            f"{matrix}\n"
        ),
        encoding="utf-8",
    )

    print(
        "\n"
        + "=" * 70
    )

    print(
        "TRAINING COMPLETE"
    )

    print(
        f"\nBest model:"
        f"\n{best_model_path}"
    )

    print(
        f"\nMetrics:"
        f"\n{metrics_path}"
    )

    print(
        f"\nResults:"
        f"\n{summary_path}"
    )

    print(
        "\nDONE."
    )


if __name__ == "__main__":
    main()