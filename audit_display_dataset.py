from pathlib import Path
from PIL import Image
import hashlib

root = Path("data/external/electronic-component-detection")

images_dir = root / "train" / "images"
labels_dir = root / "train" / "labels"

print("=== DISPLAY DATASET AUDIT ===")
print()

image_files = list(images_dir.glob("*"))
label_files = list(labels_dir.glob("*.txt"))

print(f"Train images: {len(image_files)}")
print(f"Train labels: {len(label_files)}")

# Duplicate images
hashes = {}
duplicates = []

for image_file in image_files:
    try:
        file_hash = hashlib.md5(image_file.read_bytes()).hexdigest()

        if file_hash in hashes:
            duplicates.append(
                (hashes[file_hash], str(image_file))
            )
        else:
            hashes[file_hash] = str(image_file)

    except Exception:
        pass

print(f"Duplicate images: {len(duplicates)}")

# Image / label pairing
missing_images = []
missing_labels = []

for label_file in label_files:
    image_file = images_dir / f"{label_file.stem}.jpg"

    if not image_file.exists():
        missing_images.append(label_file.name)

for image_file in image_files:
    label_file = labels_dir / f"{image_file.stem}.txt"

    if not label_file.exists():
        missing_labels.append(image_file.name)

print(f"Labels without images: {len(missing_images)}")
print(f"Images without labels: {len(missing_labels)}")

# Display annotation audit
display_objects = 0
display_images = 0

invalid_labels = []
out_of_bounds = []

for label_file in label_files:

    image_file = images_dir / f"{label_file.stem}.jpg"

    if not image_file.exists():
        continue

    try:
        with Image.open(image_file) as img:
            width, height = img.size
    except Exception:
        continue

    has_display = False

    for line_number, line in enumerate(
        label_file.read_text().splitlines(),
        start=1
    ):

        parts = line.split()

        if len(parts) != 5:
            invalid_labels.append(
                f"{label_file.name}: line {line_number}"
            )
            continue

        try:
            class_id = int(parts[0])
            x, y, w, h = map(float, parts[1:])
        except ValueError:
            invalid_labels.append(
                f"{label_file.name}: line {line_number}"
            )
            continue

        # Display = class ID 2
        if class_id == 2:
            display_objects += 1
            has_display = True

        if not (
            0 <= x <= 1
            and 0 <= y <= 1
            and 0 < w <= 1
            and 0 < h <= 1
        ):
            out_of_bounds.append(
                f"{label_file.name}: line {line_number}"
            )

    if has_display:
        display_images += 1

print(f"Display objects: {display_objects}")
print(f"Images containing Display: {display_images}")
print(f"Invalid label lines: {len(invalid_labels)}")
print(f"Out-of-bounds boxes: {len(out_of_bounds)}")

print()
print("=== AUDIT SUMMARY ===")

print(
    "Duplicate images: "
    + ("PASS" if not duplicates else f"REVIEW ({len(duplicates)})")
)

print(
    "Image/label pairing: "
    + (
        "PASS"
        if not missing_images and not missing_labels
        else "REVIEW"
    )
)

print(
    "YOLO label format: "
    + (
        "PASS"
        if not invalid_labels
        else f"REVIEW ({len(invalid_labels)})"
    )
)

print(
    "Bounding-box coordinates: "
    + (
        "PASS"
        if not out_of_bounds
        else f"REVIEW ({len(out_of_bounds)})"
    )
)

print()
print("Display audit completed.")
