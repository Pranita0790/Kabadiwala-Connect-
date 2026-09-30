import zipfile
import json

zip_path = "data/raw/external/roboflow_ewaste_v44.coco.zip"

with zipfile.ZipFile(zip_path) as z:
    data = json.loads(
        z.read("train/_annotations.coco.json")
    )

categories = {
    category["id"]: category["name"]
    for category in data["categories"]
}

target_names = {
    "CRT-Monitor",
    "CRT-TV",
}

target_ids = {
    category_id
    for category_id, name in categories.items()
    if name in target_names
}

target_annotations = [
    annotation
    for annotation in data["annotations"]
    if annotation["category_id"] in target_ids
]

image_ids = {
    annotation["image_id"]
    for annotation in target_annotations
}

print("=== CRT SOURCE AUDIT ===")
print(f"CRT source objects: {len(target_annotations)}")
print(f"Train images containing CRT: {len(image_ids)}")
print()
print("Classes included:")

for name in target_names:
    category_id = next(
        cid for cid, cname in categories.items()
        if cname == name
    )

    count = sum(
        1
        for annotation in data["annotations"]
        if annotation["category_id"] == category_id
    )

    print(f"- {name}: {count} objects")
