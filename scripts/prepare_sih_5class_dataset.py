"""
Prepare the approved 5-class SIH dataset.

Target classes:
    crt
    lcd_panel
    pcb
    cable
    battery

Sources:
    - Mendeley Laptop Components
    - Kaggle E-Waste
    - Roboflow E-Waste v44 approved object crops

Important:
    Roboflow crops are grouped by original source image ID so that
    crops from the same source image never cross train/val/test splits.

The existing 3-class baseline pipeline is not modified.
"""

from __future__ import annotations

import hashlib
import json
import random
import shutil
from collections import defaultdict
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

RAW = ROOT / "data" / "raw"
EXTERNAL = RAW / "external"

OUTPUT = ROOT / "data" / "processed" / "sih_5class"

IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".webp",
}

TARGET_CLASSES = [
    "crt",
    "lcd_panel",
    "pcb",
    "cable",
    "battery",
]

SEED = 42

TRAIN_RATIO = 0.70
VAL_RATIO = 0.15
TEST_RATIO = 0.15


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def is_image(path: Path) -> bool:
    return (
        path.is_file()
        and path.suffix.lower() in IMAGE_EXTENSIONS
    )


def validate_image(path: Path) -> bool:
    try:
        with Image.open(path) as image:
            image.verify()

        return True

    except Exception:
        return False


def collect_folder_images(
    folder: Path,
) -> list[Path]:

    if not folder.exists():
        return []

    return sorted(
        path
        for path in folder.rglob("*")
        if is_image(path)
    )


def add_source(
    sources: dict[str, list[tuple[Path, str]]],
    target_class: str,
    paths: list[Path],
    source_name: str,
) -> None:

    for path in paths:
        sources[target_class].append(
            (path, source_name)
        )


def collect_sources() -> dict[str, list[tuple[Path, str]]]:

    sources = {
        class_name: []
        for class_name in TARGET_CLASSES
    }

    # ==============================================================
    # Mendeley Laptop Components
    # ==============================================================

    mendeley_root = (
        RAW
        / "mendeley_laptop"
        / "Laptop Components Image Dataset to Classify Different Components"
        / "Raw Data"
        / "Raw Data"
    )

    mendeley_mapping = {
        "16. LCDScreen": "lcd_panel",
        "5. Motherboard": "pcb",
        "6. DCCable": "cable",
        "26. LVDSCable": "cable",
        "1. Battery": "battery",
    }

    for folder_name, target_class in mendeley_mapping.items():

        folder = mendeley_root / folder_name

        paths = collect_folder_images(folder)

        add_source(
            sources,
            target_class,
            paths,
            f"mendeley:{folder_name}",
        )

    # ==============================================================
    # Kaggle E-Waste
    # ==============================================================

    kaggle_root = (
        EXTERNAL
        / "kaggle_ewaste"
        / "dataset"
        / "modified-dataset"
        / "train"
    )

    kaggle_mapping = {
        "PCB": "pcb",
        "Battery": "battery",
    }

    for folder_name, target_class in kaggle_mapping.items():

        folder = kaggle_root / folder_name

        paths = collect_folder_images(folder)

        add_source(
            sources,
            target_class,
            paths,
            f"kaggle:{folder_name}",
        )

    # ==============================================================
    # Roboflow approved crops
    # ==============================================================

    roboflow_crops = RAW / "roboflow_approved_crops"

    roboflow_mapping = {
        "crt": "roboflow",
        "pcb": "roboflow",
        "battery": "roboflow",
    }

    for target_class, source_name in roboflow_mapping.items():

        folder = roboflow_crops / target_class

        paths = collect_folder_images(folder)

        add_source(
            sources,
            target_class,
            paths,
            source_name,
        )

    return sources


def roboflow_group_key(path: Path) -> str:

    """
    Filenames created by the Roboflow extraction script have:

        split__image_id__annotation_id.jpg

    Therefore image_id is the second field.
    """

    parts = path.stem.split("__")

    if len(parts) >= 3:
        split = parts[0]
        image_id = parts[1]

        return f"roboflow:{split}:{image_id}"

    # Fallback. This should not normally happen.
    return f"roboflow:file:{path.name}"


def build_groups(
    items: list[tuple[Path, str]],
) -> dict[str, list[tuple[Path, str]]]:

    groups = defaultdict(list)

    for path, source_name in items:

        if source_name == "roboflow":

            group_key = roboflow_group_key(path)

        else:

            # Each classification image is its own source image.
            group_key = f"{source_name}:{path.name}"

        groups[group_key].append(
            (path, source_name)
        )

    return dict(groups)


def split_groups(
    groups: dict[str, list[tuple[Path, str]]],
) -> dict[str, list[tuple[Path, str]]]:

    group_keys = sorted(groups)

    rng = random.Random(SEED)
    rng.shuffle(group_keys)

    total_images = sum(
        len(groups[key])
        for key in group_keys
    )

    target_train = total_images * TRAIN_RATIO
    target_val = total_images * VAL_RATIO

    splits = {
        "train": [],
        "val": [],
        "test": [],
    }

    train_count = 0
    val_count = 0

    for key in group_keys:

        group_items = groups[key]
        group_size = len(group_items)

        if train_count + group_size <= target_train:

            split = "train"
            train_count += group_size

        elif val_count + group_size <= target_val:

            split = "val"
            val_count += group_size

        else:

            split = "test"

        splits[split].extend(group_items)

    return splits


def process_class(
    class_name: str,
    items: list[tuple[Path, str]],
    manifest: list[dict],
) -> None:

    print(f"\nProcessing class: {class_name}")

    valid_items = []
    invalid_count = 0

    # --------------------------------------------------------------
    # Validate images
    # --------------------------------------------------------------

    for path, source_name in items:

        if not validate_image(path):

            invalid_count += 1

            continue

        valid_items.append(
            (path, source_name)
        )

    print(f"  Valid images: {len(valid_items)}")

    if invalid_count:
        print(f"  Invalid images skipped: {invalid_count}")

    # --------------------------------------------------------------
    # Exact duplicate detection
    # --------------------------------------------------------------

    hash_groups = defaultdict(list)

    for path, source_name in valid_items:

        file_hash = sha256_file(path)

        hash_groups[file_hash].append(
            (path, source_name)
        )

    unique_items = []

    duplicate_count = 0

    for file_hash, duplicate_items in hash_groups.items():

        unique_items.append(
            duplicate_items[0]
        )

        duplicate_count += (
            len(duplicate_items) - 1
        )

    print(f"  Exact duplicates removed: {duplicate_count}")
    print(f"  Unique images: {len(unique_items)}")

    # --------------------------------------------------------------
    # Group by source image
    # --------------------------------------------------------------

    groups = build_groups(unique_items)

    print(f"  Source groups: {len(groups)}")

    # --------------------------------------------------------------
    # Split
    # --------------------------------------------------------------

    splits = split_groups(groups)

    # --------------------------------------------------------------
    # Copy images
    # --------------------------------------------------------------

    for split_name, split_items in splits.items():

        output_dir = (
            OUTPUT
            / "images"
            / split_name
            / class_name
        )

        output_dir.mkdir(
            parents=True,
            exist_ok=True,
        )

        for index, (source_path, source_name) in enumerate(
            split_items
        ):

            destination = (
                output_dir
                / f"{index:05d}_{source_path.name}"
            )

            shutil.copy2(
                source_path,
                destination,
            )

            manifest.append(
                {
                    "class": class_name,
                    "split": split_name,
                    "source": source_name,
                    "source_file": str(source_path),
                    "output_file": str(destination),
                    "sha256": sha256_file(source_path),
                }
            )

    print(
        f"  Split counts: "
        f"train={len(splits['train'])}, "
        f"val={len(splits['val'])}, "
        f"test={len(splits['test'])}"
    )


def main() -> None:

    print("=" * 70)
    print("Kabadiwala Connect — SIH 5-Class Dataset Preparation")
    print("=" * 70)

    print("\nTarget classes:")

    for class_name in TARGET_CLASSES:
        print(f"  - {class_name}")

    # --------------------------------------------------------------
    # Safety check
    # --------------------------------------------------------------

    if OUTPUT.exists():

        raise RuntimeError(
            f"\nOutput already exists:\n{OUTPUT}\n\n"
            "Delete it manually only if you intentionally want "
            "to rebuild the dataset."
        )

    # --------------------------------------------------------------
    # Collect
    # --------------------------------------------------------------

    print("\nCollecting approved sources...")

    sources = collect_sources()

    for class_name in TARGET_CLASSES:

        print(
            f"{class_name:12s}: "
            f"{len(sources[class_name])} images"
        )

    # --------------------------------------------------------------
    # Prepare output
    # --------------------------------------------------------------

    OUTPUT.mkdir(
        parents=True,
        exist_ok=True,
    )

    manifest = []

    # --------------------------------------------------------------
    # Process each class
    # --------------------------------------------------------------

    for class_name in TARGET_CLASSES:

        process_class(
            class_name,
            sources[class_name],
            manifest,
        )

    # --------------------------------------------------------------
    # Save manifest
    # --------------------------------------------------------------

    manifest_path = OUTPUT / "manifest.json"

    with manifest_path.open(
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            manifest,
            file,
            indent=2,
        )

    # --------------------------------------------------------------
    # Save dataset metadata
    # --------------------------------------------------------------

    metadata = {
        "dataset_name": "Kabadiwala Connect SIH 5-Class",
        "version": "0.1.0",
        "classes": TARGET_CLASSES,
        "seed": SEED,
        "split_ratio": {
            "train": TRAIN_RATIO,
            "val": VAL_RATIO,
            "test": TEST_RATIO,
        },
        "total_images": len(manifest),
    }

    metadata_path = OUTPUT / "dataset_metadata.json"

    with metadata_path.open(
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            metadata,
            file,
            indent=2,
        )

    # --------------------------------------------------------------
    # Final summary
    # --------------------------------------------------------------

    print("\n" + "=" * 70)
    print("DATASET PREPARATION COMPLETE")
    print("=" * 70)

    print(f"\nTotal processed images: {len(manifest)}")

    print(f"Output: {OUTPUT}")

    print(f"Manifest: {manifest_path}")

    print(f"Metadata: {metadata_path}")

    print("\nDataset structure:")

    for split in ["train", "val", "test"]:

        print(f"\n{split}/")

        for class_name in TARGET_CLASSES:

            folder = (
                OUTPUT
                / "images"
                / split
                / class_name
            )

            count = (
                len(
                    [
                        p
                        for p in folder.glob("*")
                        if is_image(p)
                    ]
                )
                if folder.exists()
                else 0
            )

            print(
                f"  {class_name:12s}: {count}"
            )


if __name__ == "__main__":
    main()