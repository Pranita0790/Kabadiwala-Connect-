from pathlib import Path
from PIL import Image
import hashlib

root = Path("data/external/electronic-component-detection")

images_dir = root / "train" / "images"
labels_dir = root / "train" / "labels"

print("=== MOTOR DATASET AUDIT ===")
print()

image_files = list(images_dir.glob("*"))
label_files = list(labels_dir.glob("*.txt"))

print(f"Train images: {len(image_files)}")
print(f"Train labels: {len(label_files)}")

# --------------------------------------------------
# 1. Duplicate image check
# --------------------------------------------------

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

# --------------------------------------------------
# 2. Image / label pairing
# --------------------------------------------------

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

# --------------------------------------------------
# 3. Motor annotation audit
# --------------------------------------------------

motor_objects = 0
motor_images = 0

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

    has_motor = False

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

        if class_id == 4:
            motor_objects += 1
            has_motor = True

        # YOLO normalized coordinates must stay in [0, 1]
        if not (
            0 <= x <= 1
            and 0 <= y <= 1
            and 0 < w <= 1
            and 0 < h <= 1
        ):
            out_of_bounds.append(
                f"{label_file.name}: line {line_number}"
            )

    if has_motor:
        motor_images += 1

print(f"Motor objects: {motor_objects}")
print(f"Images containing Motor: {motor_images}")
print(f"Invalid label lines: {len(invalid_labels)}")
print(f"Out-of-bounds boxes: {len(out_of_bounds)}")

# --------------------------------------------------
# 4. Image resolution audit
# --------------------------------------------------

resolutions = {}

for image_file in image_files:

    try:
        with Image.open(image_file) as img:
            size = img.size

        resolutions[size] = resolutions.get(size, 0) + 1

    except Exception:
        pass

print()
print("=== IMAGE RESOLUTIONS ===")

for resolution, count in sorted(
    resolutions.items(),
    key=lambda item: item[1],
    reverse=True
):
    print(f"{resolution}: {count}")

# --------------------------------------------------
# 5. Summary
# --------------------------------------------------

print()
print("=== AUDIT SUMMARY ===")

if not duplicates:
    print("Duplicate images: PASS")
else:
    print(f"Duplicate images: REVIEW ({len(duplicates)})")

if not missing_images and not missing_labels:
    print("Image/label pairing: PASS")
else:
    print("Image/label pairing: REVIEW")

if not invalid_labels:
    print("YOLO label format: PASS")
else:
    print(f"YOLO label format: REVIEW ({len(invalid_labels)})")

if not out_of_bounds:
    print("Bounding-box coordinates: PASS")
else:
    print(f"Bounding-box coordinates: REVIEW ({len(out_of_bounds)})")

print()
print("Motor audit completed.")
