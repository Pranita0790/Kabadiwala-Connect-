from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

ROBOFLOW_ROOT = ROOT / "data" / "raw" / "external" / "roboflow_ewaste_v44"
OUTPUT_ROOT = ROOT / "data" / "raw" / "roboflow_approved_crops"

CLASS_MAPPING = {
    "CRT-Monitor": "crt",
    "CRT-TV": "crt",
    "PCB": "pcb",
    "Battery": "battery",
}


def extract_crops(annotation_file: Path) -> int:
    split = annotation_file.parent.name

    with annotation_file.open("r", encoding="utf-8") as file:
        data = json.load(file)

    categories = {
        category["id"]: category["name"]
        for category in data.get("categories", [])
    }

    images = {
        image["id"]: image
        for image in data.get("images", [])
    }

    count = 0

    for annotation in data.get("annotations", []):
        category_name = categories.get(annotation.get("category_id"))

        if category_name not in CLASS_MAPPING:
            continue

        image_info = images.get(annotation.get("image_id"))

        if image_info is None:
            continue

        image_path = annotation_file.parent / image_info["file_name"]

        if not image_path.exists():
            print(f"WARNING: Missing image: {image_path}")
            continue

        target_class = CLASS_MAPPING[category_name]

        try:
            with Image.open(image_path) as image:
                image = image.convert("RGB")

                x, y, width, height = annotation["bbox"]

                left = max(0, int(x))
                top = max(0, int(y))
                right = min(image.width, int(x + width))
                bottom = min(image.height, int(y + height))

                if right <= left or bottom <= top:
                    continue

                crop = image.crop((left, top, right, bottom))

                output_dir = OUTPUT_ROOT / target_class
                output_dir.mkdir(parents=True, exist_ok=True)

                output_name = (
                    f"{split}__"
                    f"{annotation['image_id']}__"
                    f"{annotation['id']}.jpg"
                )

                crop.save(output_dir / output_name, quality=95)

                count += 1

        except Exception as exc:
            print(f"WARNING: Failed {image_path}: {exc}")

    return count


def main() -> None:
    print("=" * 70)
    print("Kabadiwala Connect — Roboflow Approved Crop Extraction")
    print("=" * 70)

    if OUTPUT_ROOT.exists():
        print(f"\nRemoving previous output: {OUTPUT_ROOT}")
        import shutil
        shutil.rmtree(OUTPUT_ROOT)

    total = 0

    for split in ["train", "valid", "test"]:
        annotation_file = ROBOFLOW_ROOT / split / "_annotations.coco.json"

        if not annotation_file.exists():
            print(f"WARNING: Missing annotation file: {annotation_file}")
            continue

        count = extract_crops(annotation_file)

        print(f"{split:8s}: {count} approved crops")
        total += count

    print("-" * 70)
    print(f"TOTAL   : {total} approved crops")
    print(f"OUTPUT  : {OUTPUT_ROOT}")
    print("=" * 70)


if __name__ == "__main__":
    main()