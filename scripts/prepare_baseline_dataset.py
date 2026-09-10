"""
Kabadiwala Connect
Leakage-safe baseline dataset preparation.

Approved public-data classes:
    crt
    pcb
    battery

Roboflow:
    COCO object annotations -> object crops

Kaggle:
    Image classification folders -> full images

Important:
    - data/raw is NEVER modified.
    - Exact duplicate source images are grouped together.
    - Train/val/test splitting happens at source-image level.
    - Roboflow objects are cropped using their COCO bounding boxes.
    - No automatic mapping is performed for LCD, cable, motor,
      magnet_bearing_assembly, or mixed_plastic.
"""

from __future__ import annotations

import csv
import hashlib
import random
import shutil
from collections import defaultdict
from pathlib import Path

from PIL import Image


# ============================================================
# PATHS
# ============================================================

ROOT = Path(__file__).resolve().parents[1]

RAW = ROOT / "data" / "raw" / "external"

ROBOFLOW = RAW / "roboflow_ewaste_v44"
KAGGLE = RAW / "kaggle_ewaste" / "dataset" / "modified-dataset"

OUT = ROOT / "data" / "processed" / "baseline"

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

SEED = 42


# ============================================================
# APPROVED MAPPINGS
# ============================================================

ROBOFLOW_MAPPING = {
    "CRT-Monitor": "crt",
    "CRT-TV": "crt",
    "PCB": "pcb",
    "Battery": "battery",
}

KAGGLE_MAPPING = {
    "Battery": "battery",
    "PCB": "pcb",
}


# ============================================================
# HELPERS
# ============================================================

def sha256_file(path: Path) -> str:
    """Calculate SHA-256 hash of a file."""

    digest = hashlib.sha256()

    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def sha256_bytes(data: bytes) -> str:
    """Calculate SHA-256 hash of bytes."""

    return hashlib.sha256(data).hexdigest()


def find_image_by_name(root: Path, filename: str) -> Path | None:
    """
    Find an image referenced by a COCO annotation file.
    """

    direct = root / filename

    if direct.exists():
        return direct

    matches = list(root.rglob(filename))

    if matches:
        return matches[0]

    return None


def load_coco(path: Path) -> dict:
    """Load COCO JSON."""

    import json

    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


# ============================================================
# ROBOFLOW
# ============================================================

def collect_roboflow():
    """
    Read Roboflow COCO annotations and generate object crops.

    Each approved annotation becomes one crop.
    """

    records = []

    split_map = {
        "train": ROBOFLOW / "train",
        "valid": ROBOFLOW / "valid",
        "test": ROBOFLOW / "test",
    }

    for original_split, split_dir in split_map.items():

        annotation_file = split_dir / "_annotations.coco.json"

        if not annotation_file.exists():
            print(f"[WARNING] Missing: {annotation_file}")
            continue

        print(f"\nReading Roboflow {original_split}...")

        coco = load_coco(annotation_file)

        categories = {
            category["id"]: category["name"]
            for category in coco.get("categories", [])
        }

        images = {
            image["id"]: image
            for image in coco.get("images", [])
        }

        annotations = coco.get("annotations", [])

        approved_count = 0

        for annotation in annotations:

            category_id = annotation.get("category_id")

            source_class = categories.get(category_id)

            if source_class not in ROBOFLOW_MAPPING:
                continue

            image_info = images.get(annotation.get("image_id"))

            if image_info is None:
                continue

            filename = image_info.get("file_name")

            if not filename:
                continue

            image_path = find_image_by_name(split_dir, filename)

            if image_path is None:
                print(
                    f"[WARNING] Image not found: "
                    f"{split_dir / filename}"
                )
                continue

            target_class = ROBOFLOW_MAPPING[source_class]

            bbox = annotation.get("bbox")

            if not bbox or len(bbox) != 4:
                continue

            try:
                x, y, width, height = map(float, bbox)
            except (TypeError, ValueError):
                continue

            # ----------------------------------------------------
            # Clamp bounding box to image dimensions.
            # ----------------------------------------------------

            try:
                with Image.open(image_path) as image:
                    image = image.convert("RGB")

                    img_width, img_height = image.size

                    left = max(0, int(x))
                    top = max(0, int(y))
                    right = min(
                        img_width,
                        int(x + width),
                    )
                    bottom = min(
                        img_height,
                        int(y + height),
                    )

                    if right <= left or bottom <= top:
                        continue

                    crop = image.crop(
                        (left, top, right, bottom)
                    )

                    crop_bytes = crop.tobytes()

                    crop_hash = sha256_bytes(crop_bytes)

            except Exception as exc:
                print(
                    f"[WARNING] Could not process "
                    f"{image_path}: {exc}"
                )
                continue

            source_image_hash = sha256_file(image_path)

            records.append(
                {
                    "dataset": "Roboflow E-Waste Dataset v44",
                    "source_class": source_class,
                    "target_class": target_class,
                    "original_split": original_split,
                    "supervision": "object_annotation",
                    "source_path": image_path,
                    "source_image_hash": source_image_hash,
                    "crop_hash": crop_hash,
                    "crop": crop,
                    "annotation_id": annotation.get("id"),
                    "source_filename": filename,
                }
            )

            approved_count += 1

        print(
            f"  Approved object annotations: "
            f"{approved_count}"
        )

    return records


# ============================================================
# KAGGLE
# ============================================================

def collect_kaggle():
    """
    Collect approved Kaggle classification images.
    """

    records = []

    split_map = {
        "train": KAGGLE / "train",
        "val": KAGGLE / "val",
        "test": KAGGLE / "test",
    }

    for original_split, split_dir in split_map.items():

        print(f"\nReading Kaggle {original_split}...")

        for source_class, target_class in KAGGLE_MAPPING.items():

            class_dir = split_dir / source_class

            if not class_dir.exists():
                print(
                    f"[WARNING] Missing directory: "
                    f"{class_dir}"
                )
                continue

            images = list(find_images(class_dir))

            print(
                f"  {source_class}: "
                f"{len(images)} images"
            )

            for image_path in images:

                try:
                    file_hash = sha256_file(image_path)

                    with Image.open(image_path) as image:
                        image.verify()

                except Exception as exc:
                    print(
                        f"[WARNING] Invalid image "
                        f"{image_path}: {exc}"
                    )
                    continue

                records.append(
                    {
                        "dataset": (
                            "Kaggle E-Waste "
                            "Image Dataset"
                        ),
                        "source_class": source_class,
                        "target_class": target_class,
                        "original_split": original_split,
                        "supervision": "image_class",
                        "source_path": image_path,
                        "source_image_hash": file_hash,
                        "crop_hash": file_hash,
                        "crop": None,
                        "annotation_id": "",
                        "source_filename": image_path.name,
                    }
                )

    return records


def find_images(folder: Path):
    """Yield supported image files."""

    if not folder.exists():
        return

    for path in folder.rglob("*"):
        if (
            path.is_file()
            and path.suffix.lower() in IMAGE_EXTENSIONS
        ):
            yield path


# ============================================================
# SOURCE-IMAGE DEDUPLICATION
# ============================================================

def deduplicate_source_images(records):
    """
    Group records by source image SHA-256.

    This is critical for leakage prevention.

    If the same source image occurs:
        - in multiple splits
        - multiple times in one split
        - across datasets

    it belongs to one source-image group.
    """

    groups = defaultdict(list)

    for record in records:
        groups[record["source_image_hash"]].append(record)

    print("\nSource-image groups:")
    print(f"  Total records: {len(records)}")
    print(f"  Unique source images: {len(groups)}")

    duplicate_groups = 0
    duplicate_records = 0

    for file_hash, group in groups.items():

        if len(group) > 1:
            duplicate_groups += 1
            duplicate_records += len(group) - 1

    print(
        f"  Duplicate source-image groups: "
        f"{duplicate_groups}"
    )

    print(
        f"  Duplicate records involved: "
        f"{duplicate_records}"
    )

    return groups


# ============================================================
# REMOVE AMBIGUOUS SOURCE GROUPS
# ============================================================

def remove_ambiguous_groups(groups):
    """
    If identical source content is assigned to different target
    classes, conservatively remove the entire group.

    We never invent a label.
    """

    clean_records = []

    ambiguous = 0

    for file_hash, group in groups.items():

        classes = {
            record["target_class"]
            for record in group
        }

        if len(classes) > 1:
            ambiguous += 1

            print(
                "\n[WARNING] Ambiguous duplicate source image:"
            )

            print(f"  SHA256: {file_hash}")

            print(
                f"  Classes: "
                f"{sorted(classes)}"
            )

            continue

        # ----------------------------------------------------
        # Keep all object crops from a source image.
        # For exact duplicate records, prefer Roboflow
        # and deterministic ordering.
        # ----------------------------------------------------

        group_sorted = sorted(
            group,
            key=lambda r: (
                0
                if r["dataset"].startswith("Roboflow")
                else 1,
                r["dataset"],
                r["original_split"],
                str(r["source_path"]),
                str(r["annotation_id"]),
            ),
        )

        # Remove exact duplicate crop hashes.
        seen_crops = set()

        for record in group_sorted:

            crop_hash = record["crop_hash"]

            if crop_hash in seen_crops:
                continue

            seen_crops.add(crop_hash)
            clean_records.append(record)

    print(
        f"\nAmbiguous source-image groups removed: "
        f"{ambiguous}"
    )

    print(
        f"Records after source/crop deduplication: "
        f"{len(clean_records)}"
    )

    return clean_records


# ============================================================
# SPLITTING
# ============================================================

def create_leakage_safe_splits(records):
    """
    Create a new 80/10/10 split.

    IMPORTANT:
    Split is assigned by source-image group, not individual crop.
    """

    rng = random.Random(SEED)

    by_class = defaultdict(list)

    # --------------------------------------------------------
    # Group records by source image.
    # --------------------------------------------------------

    source_groups = defaultdict(list)

    for record in records:
        source_groups[
            record["source_image_hash"]
        ].append(record)

    for source_hash, group in source_groups.items():

        target_class = group[0]["target_class"]

        by_class[target_class].append(
            (source_hash, group)
        )

    final_records = []

    for target_class in sorted(by_class):

        groups = by_class[target_class]

        rng.shuffle(groups)

        n = len(groups)

        if n == 1:

            train_groups = groups
            val_groups = []
            test_groups = []

        elif n == 2:

            train_groups = groups[:1]
            val_groups = groups[1:]
            test_groups = []

        else:

            train_end = max(
                1,
                int(n * 0.80),
            )

            val_end = max(
                train_end + 1,
                int(n * 0.90),
            )

            if val_end >= n:
                val_end = n - 1

            train_groups = groups[:train_end]
            val_groups = groups[
                train_end:val_end
            ]
            test_groups = groups[val_end:]

        for split_name, selected_groups in [
            ("train", train_groups),
            ("val", val_groups),
            ("test", test_groups),
        ]:

            for source_hash, group in selected_groups:

                for record in group:

                    item = dict(record)
                    item["split"] = split_name

                    final_records.append(item)

    return final_records


# ============================================================
# OUTPUT
# ============================================================

def prepare_output_directory():
    """
    Refuse to overwrite an existing processed baseline.
    """

    if OUT.exists():

        existing = list(OUT.rglob("*"))

        if existing:

            raise RuntimeError(
                f"\nOutput already exists:\n"
                f"  {OUT}\n\n"
                f"Refusing to overwrite it.\n"
                f"Delete it manually only if you "
                f"intentionally want a fresh run."
            )

    OUT.mkdir(
        parents=True,
        exist_ok=True,
    )


def write_dataset(records):
    """
    Write processed images and metadata.
    """

    prepare_output_directory()

    for target_class in sorted(
        set(r["target_class"] for r in records)
    ):

        for split in (
            "train",
            "val",
            "test",
        ):

            (
                OUT
                / "images"
                / split
                / target_class
            ).mkdir(
                parents=True,
                exist_ok=True,
            )

    metadata_path = OUT / "metadata.csv"

    fields = [
        "filename",
        "target_class",
        "split",
        "dataset",
        "source_class",
        "original_split",
        "supervision",
        "source_image_hash",
        "crop_hash",
        "annotation_id",
        "source_filename",
    ]

    rows = []

    for index, record in enumerate(
        records,
        start=1,
    ):

        target_class = record["target_class"]
        split = record["split"]

        filename = (
            f"{target_class}__"
            f"{record['crop_hash'][:12]}__"
            f"{Path(record['source_filename']).stem}"
            f".jpg"
        )

        destination = (
            OUT
            / "images"
            / split
            / target_class
            / filename
        )

        # ----------------------------------------------------
        # Roboflow: save object crop.
        # Kaggle: copy full image.
        # ----------------------------------------------------

        if record["crop"] is not None:

            record["crop"].save(
                destination,
                format="JPEG",
                quality=95,
            )

        else:

            shutil.copy2(
                record["source_path"],
                destination,
            )

        rows.append(
            {
                "filename": filename,
                "target_class": target_class,
                "split": split,
                "dataset": record["dataset"],
                "source_class": record["source_class"],
                "original_split": record[
                    "original_split"
                ],
                "supervision": record[
                    "supervision"
                ],
                "source_image_hash": record[
                    "source_image_hash"
                ],
                "crop_hash": record[
                    "crop_hash"
                ],
                "annotation_id": record[
                    "annotation_id"
                ],
                "source_filename": record[
                    "source_filename"
                ],
            }
        )

        if index % 500 == 0:

            print(
                f"  Wrote "
                f"{index}/{len(records)}"
            )

    with metadata_path.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as f:

        writer = csv.DictWriter(
            f,
            fieldnames=fields,
        )

        writer.writeheader()
        writer.writerows(rows)

    return metadata_path


# ============================================================
# SUMMARY
# ============================================================

def print_summary(records):
    """
    Print final dataset statistics.
    """

    counts = defaultdict(
        lambda: defaultdict(int)
    )

    source_counts = defaultdict(
        lambda: defaultdict(int)
    )

    for record in records:

        counts[
            record["target_class"]
        ][record["split"]] += 1

        source_counts[
            record["target_class"]
        ][record["dataset"]] += 1

    print("\n")
    print("=" * 72)
    print("KABADIWALA CONNECT — BASELINE DATASET")
    print("=" * 72)

    total = 0

    for target_class in sorted(counts):

        train = counts[
            target_class
        ]["train"]

        val = counts[
            target_class
        ]["val"]

        test = counts[
            target_class
        ]["test"]

        class_total = (
            train + val + test
        )

        total += class_total

        print(
            f"\n{target_class}"
        )

        print(
            f"  train: {train}"
        )

        print(
            f"  val:   {val}"
        )

        print(
            f"  test:  {test}"
        )

        print(
            f"  total: {class_total}"
        )

        for dataset, count in sorted(
            source_counts[
                target_class
            ].items()
        ):

            print(
                f"    {dataset}: {count}"
            )

    print("\n" + "-" * 72)

    print(
        f"TOTAL PROCESSED SAMPLES: {total}"
    )

    print("=" * 72)


# ============================================================
# LEAKAGE CHECK
# ============================================================

def verify_no_source_hash_leakage(records):
    """
    Confirm that one source image hash appears in only one split.
    """

    split_by_hash = defaultdict(set)

    for record in records:

        split_by_hash[
            record["source_image_hash"]
        ].add(record["split"])

    leaked = {
        file_hash: splits
        for file_hash, splits in split_by_hash.items()
        if len(splits) > 1
    }

    if leaked:

        print(
            "\n[ERROR] SOURCE-IMAGE LEAKAGE DETECTED!"
        )

        for file_hash, splits in list(
            leaked.items()
        )[:10]:

            print(
                f"  {file_hash}: "
                f"{sorted(splits)}"
            )

        raise RuntimeError(
            "Dataset split contains source-image leakage."
        )

    print(
        "\nLeakage check: PASSED"
    )

    print(
        "No source image appears in multiple splits."
    )


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 72)
    print(
        "Kabadiwala Connect — "
        "Baseline Dataset Preparation"
    )
    print("=" * 72)

    print("\nApproved classes:")

    for target_class in (
        "crt",
        "pcb",
        "battery",
    ):

        print(
            f"  ✓ {target_class}"
        )

    print(
        "\nExcluded classes remain excluded:"
    )

    for target_class in (
        "lcd_panel",
        "cable",
        "motor",
        "magnet_bearing_assembly",
        "mixed_plastic",
    ):

        print(
            f"  - {target_class}"
        )

    # --------------------------------------------------------
    # Collect
    # --------------------------------------------------------

    roboflow_records = collect_roboflow()

    print(
        f"\nRoboflow approved records: "
        f"{len(roboflow_records)}"
    )

    kaggle_records = collect_kaggle()

    print(
        f"\nKaggle approved records: "
        f"{len(kaggle_records)}"
    )

    all_records = (
        roboflow_records
        + kaggle_records
    )

    if not all_records:

        raise RuntimeError(
            "No approved records found."
        )

    print(
        f"\nTotal candidate records: "
        f"{len(all_records)}"
    )

    # --------------------------------------------------------
    # Deduplicate
    # --------------------------------------------------------

    groups = deduplicate_source_images(
        all_records
    )

    clean_records = remove_ambiguous_groups(
        groups
    )

    # --------------------------------------------------------
    # Split
    # --------------------------------------------------------

    split_records = create_leakage_safe_splits(
        clean_records
    )

    verify_no_source_hash_leakage(
        split_records
    )

    # --------------------------------------------------------
    # Write
    # --------------------------------------------------------

    metadata_path = write_dataset(
        split_records
    )

    # --------------------------------------------------------
    # Summary
    # --------------------------------------------------------

    print_summary(
        split_records
    )

    print(
        f"\nMetadata:"
        f"\n  {metadata_path}"
    )

    print(
        f"\nDataset:"
        f"\n  {OUT}"
    )

    print(
        "\nDONE."
    )


if __name__ == "__main__":
    main()