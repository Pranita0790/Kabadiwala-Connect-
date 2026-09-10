from pathlib import Path
import csv
from datetime import datetime

ROOT = Path("data/raw/images")

classes = [
    "crt",
    "lcd_panel",
    "pcb",
    "cable",
    "battery",
    "motor",
    "magnet_bearing_assembly",
    "mixed_plastics",
]

extensions = {".jpg", ".jpeg", ".png", ".webp"}

rows = []

for class_name in classes:
    class_dir = ROOT / class_name

    for image in sorted(class_dir.rglob("*")):
        if image.is_file() and image.suffix.lower() in extensions:
            rows.append({
                "image_id": image.stem,
                "class": class_name,
                "source": "field",
                "collector_id": "",
                "location": "",
                "date": datetime.now().strftime("%Y-%m-%d"),
                "notes": "",
            })

manifest = ROOT / "collection_manifest.csv"

with manifest.open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=[
            "image_id",
            "class",
            "source",
            "collector_id",
            "location",
            "date",
            "notes",
        ],
    )
    writer.writeheader()
    writer.writerows(rows)

print(f"Manifest created: {manifest}")
print(f"Images found: {len(rows)}")
