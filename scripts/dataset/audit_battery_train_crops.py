from pathlib import Path
import hashlib

root = Path("data/external/curated/battery_train")

files = list(root.glob("*.jpg"))

hashes = {}
duplicates = []

for file in files:
    file_hash = hashlib.md5(file.read_bytes()).hexdigest()

    if file_hash in hashes:
        duplicates.append(
            (hashes[file_hash], file.name)
        )
    else:
        hashes[file_hash] = file.name

print("=== BATTERY TRAIN CROP DUPLICATE AUDIT ===")
print(f"Total crops: {len(files)}")
print(f"Unique crops: {len(hashes)}")
print(f"Exact duplicates: {len(duplicates)}")

if duplicates:
    print()
    print("Duplicate pairs:")

    for original, duplicate in duplicates:
        print(f"{original}  <->  {duplicate}")
