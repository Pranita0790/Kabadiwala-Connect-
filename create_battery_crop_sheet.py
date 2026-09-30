from pathlib import Path
from PIL import Image, ImageOps, ImageDraw
import math

root = Path("data/external/curated/battery_train")
output = Path("data/external/curated/battery_train_contact_sheet.jpg")

files = list(root.glob("*.jpg"))[:30]

thumb_w = 220
thumb_h = 180
cols = 5
rows = math.ceil(len(files) / cols)

canvas = Image.new(
    "RGB",
    (cols * thumb_w, rows * thumb_h),
    "white"
)

draw = ImageDraw.Draw(canvas)

for i, file in enumerate(files):

    try:
        image = Image.open(file).convert("RGB")
        image = ImageOps.contain(
            image,
            (thumb_w - 10, thumb_h - 30)
        )

        x = (i % cols) * thumb_w
        y = (i // cols) * thumb_h

        image_x = x + (thumb_w - image.width) // 2
        image_y = y + 5

        canvas.paste(image, (image_x, image_y))

        draw.text(
            (x + 5, y + thumb_h - 20),
            str(i + 1),
            fill="black"
        )

    except Exception as e:
        print(f"Could not process {file}: {e}")

canvas.save(output, quality=95)

print(f"Created contact sheet with {len(files)} Battery crops.")
print(f"Output: {output}")
