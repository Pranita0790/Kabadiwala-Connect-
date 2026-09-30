from pathlib import Path
from PIL import Image

source = Path("data/external/electronic-component-detection")
output = Path("data/external/curated/display_train")

output.mkdir(parents=True, exist_ok=True)

image_dir = source / "train" / "images"
label_dir = source / "train" / "labels"

display_class_id = 2

crop_count = 0
image_count = 0

for label_file in label_dir.glob("*.txt"):

    image_file = image_dir / f"{label_file.stem}.jpg"

    if not image_file.exists():
        continue

    try:
        image = Image.open(image_file).convert("RGB")
        image_width, image_height = image.size
    except Exception:
        continue

    display_found = False
    display_index = 0

    for line in label_file.read_text().splitlines():

        parts = line.split()

        if len(parts) != 5:
            continue

        try:
            class_id = int(parts[0])
            x_center = float(parts[1])
            y_center = float(parts[2])
            box_width = float(parts[3])
            box_height = float(parts[4])
        except ValueError:
            continue

        if class_id != display_class_id:
            continue

        display_found = True

        x1 = int(
            (x_center - box_width / 2) * image_width
        )
        y1 = int(
            (y_center - box_height / 2) * image_height
        )
        x2 = int(
            (x_center + box_width / 2) * image_width
        )
        y2 = int(
            (y_center + box_height / 2) * image_height
        )

        x1 = max(0, min(x1, image_width - 1))
        y1 = max(0, min(y1, image_height - 1))
        x2 = max(x1 + 1, min(x2, image_width))
        y2 = max(y1 + 1, min(y2, image_height))

        crop = image.crop((x1, y1, x2, y2))

        filename = (
            f"train_{label_file.stem}_display_{display_index}.jpg"
        )

        crop.save(
            output / filename,
            quality=95
        )

        crop_count += 1
        display_index += 1

    if display_found:
        image_count += 1

print()
print("=== TRAIN-ONLY DISPLAY CROP CREATION ===")
print(f"Source train images containing Display: {image_count}")
print(f"Display training crops created: {crop_count}")
print(f"Output folder: {output}")
print()
print("Validation and test data were NOT included.")
print("Original teammate dataset was NOT modified.")
