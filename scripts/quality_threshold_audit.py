from pathlib import Path

import pandas as pd
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
IMAGE_ROOT = ROOT / "data" / "processed" / "baseline" / "images"

rows = []

for path in IMAGE_ROOT.rglob("*.jpg"):
    split = path.parts[-3]
    class_name = path.parts[-2]

    with Image.open(path) as image:
        width, height = image.size

    rows.append(
        {
            "split": split,
            "class": class_name,
            "width": width,
            "height": height,
        }
    )


df = pd.DataFrame(rows)

print("QUALITY THRESHOLD IMPACT")
print("=" * 70)

for threshold in [32, 48, 64, 80]:

    df["bad"] = (
        (df["width"] < threshold)
        | (df["height"] < threshold)
    )

    summary = (
        df.groupby("class")
        .agg(
            total=("bad", "size"),
            remove=("bad", "sum"),
        )
    )

    summary["keep"] = (
        summary["total"] - summary["remove"]
    )

    summary["keep_pct"] = (
        100 * summary["keep"] / summary["total"]
    )

    print(f"\nThreshold: {threshold} x {threshold}")
    print(summary.round(1).to_string())


print("\n")
print("Audit complete.")