from pathlib import Path
from PIL import Image, ImageOps, ImageDraw
import math

root = Path("data/external/candidate-review")
out = root / "contact-sheets"
out.mkdir(exist_ok=True)

for cls in ["battery", "display", "motor"]:
    files = list((root / cls).glob("*.jpg"))[:20]

    if not files:
        print(f"No images found for {cls}")
        continue

    thumb_w = 220
    thumb_h = 180
    cols = 4
    rows = math.ceil(len(files) / cols)

    canvas = Image.new(
        "RGB",
        (cols * thumb_w, rows * thumb_h),
        "white"
    )

    for i, file in enumerate(files):
        try:
            img = Image.open(file).convert("RGB")
            img = ImageOps.fit(img, (thumb_w, thumb_h))

            x = (i % cols) * thumb_w
            y = (i // cols) * thumb_h

            canvas.paste(img, (x, y))

        except Exception as e:
            print(f"Could not process {file}: {e}")

    output = out / f"{cls}.jpg"
    canvas.save(output, quality=95)
    print(f"{cls}: {len(files)} images -> {output}")

print("Contact sheets created successfully.")
