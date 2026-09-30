from pathlib import Path
from PIL import Image
import zipfile
import json
import io

ZIP_PATH = Path("data/raw/external/roboflow_ewaste_v44.coco.zip")
OUTPUT = Path("data/external/curated/pcb_train")

OUTPUT.mkdir(parents=True, exist_ok=True)

with zipfile.ZipFile(ZIP_PATH) as z:
    data = json.loads(
        z.read("train/_annotations.coco.json")
    )

    categories = {
        category["id"]: category["name"]
        for category in data["categories"]
    }

    pcb_ids = {
        category_id
        for category_id, name in categories.items()
        if name == "PCB"
    }

    images = {
        image["id"]: image
        for image in data["images"]
    }

    zip_files = set(z.namelist())

    crop_count = 0
    image_count = set()

    for annotation in data["annotations"]:

        if annotation["category_id"] not in pcb_ids:
            continue

        image_info = images[annotation["image_id"]]
        image_name = image_info["file_name"]

        possible_paths = [
            image_name,
            f"train/{image_name}",
        ]

        actual_path = next(
            (
                path
                for path in possible_paths
                if path in zip_files
            ),
            None
        )

        if actual_path is None:
            print(f"WARNING: image not found: {image_name}")
            continue

        image_bytes = z.read(actual_path)
        image = Image.open(
            io.BytesIO(image_bytes)
        ).convert("RGB")

        image_width, image_height = image.size

        x, y, width, height = annotation["bbox"]

        x1 = max(0, int(x))
        y1 = max(0, int(y))
        x2 = min(image_width, int(x + width))
        y2 = min(image_height, int(y + height))

        if x2 <= x1 or y2 <= y1:
            continue

        crop = image.crop(
            (x1, y1, x2, y2)
        )

        filename = (
            f"pcb_{annotation['image_id']}"
            f"_{annotation['id']}.jpg"
        )

        crop.save(
            OUTPUT / filename,
            quality=95
        )

        crop_count += 1
        image_count.add(annotation["image_id"])

print()
print("=== TRAIN-ONLY PCB CROP CREATION ===")
print(
    f"Source train images containing PCB: "
    f"{len(image_count)}"
)
print(f"PCB training crops created: {crop_count}")
print(f"Output folder: {OUTPUT}")
print()
print("Validation and test data were NOT included.")
print("Original Roboflow ZIP was NOT modified.")
