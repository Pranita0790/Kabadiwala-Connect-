from pathlib import Path
import hashlib

root = Path("data/external/curated/motor_train")

files = list(root.glob("*.jpg"))
hashes = {}
duplicates = []

for file in files:
    h = hashlib.md5(file.read_bytes()).hexdigest()

    if h in hashes:
        duplicates.append((hashes[h], file.name))
    else:
        hashes[h] = file.name

print("=== MOTOR TRAIN CROP DUPLICATE AUDIT ===")
print(f"Total crops: {len(files)}")
print(f"Unique crops: {len(hashes)}")
print(f"Exact duplicates: {len(duplicates)}")

if duplicates:
    print()
    print("Duplicate pairs:")
    for original, duplicate in duplicates:
        print(f"{original}  <->  {duplicate}")
