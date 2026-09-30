import zipfile
import json
from pathlib import Path

zip_path = Path("data/raw/external/roboflow_ewaste_v44.coco.zip")

with zipfile.ZipFile(zip_path) as z:
    data = json.loads(
        z.read("train/_annotations.coco.json")
    )

categories = {
    category["id"]: category["name"]
    for category in data["categories"]
}

counts = {
    name: 0
    for name in categories.values()
}

for annotation in data["annotations"]:
    category_id = annotation["category_id"]

    if category_id in categories:
        name = categories[category_id]
        counts[name] += 1

print("=== ROBOFLOW E-WASTE V44 TRAIN CLASSES ===")
print(f"Images: {len(data['images'])}")
print(f"Annotations: {len(data['annotations'])}")
print(f"Classes: {len(categories)}")
print()

for category_id, name in categories.items():
    print(
        f"{category_id} - {name}: "
        f"{counts[name]} objects"
    )
