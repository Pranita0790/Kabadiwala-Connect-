from pathlib import Path
from PIL import Image, ImageDraw
import math

root = Path("data/external/electronic-component-detection")
out = Path("data/external/candidate-review/annotated")
out.mkdir(parents=True, exist_ok=True)

classes = {
    1: "Battery",
    2: "Display",
    4: "Motor"
}

for target_id, class_name in classes.items():

    label_dir = root / "train" / "labels"
    image_dir = root / "train" / "images"

    selected = []

    for label_file in label_dir.glob("*.txt"):
        lines = label_file.read_text().splitlines()

        if any(line.strip().startswith(f"{target_id} ") for line in lines):
            image_file = image_dir / f"{label_file.stem}.jpg"

            if image_file.exists():
                selected.append((image_file, label_file))

        if len(selected) >= 20:
            break

    thumb_w = 320
    thumb_h = 240
    cols = 4
    rows = math.ceil(len(selected) / cols)

    canvas = Image.new(
        "RGB",
        (cols * thumb_w, rows * thumb_h),
        "white"
    )

    for i, (image_file, label_file) in enumerate(selected):

        img = Image.open(image_file).convert("RGB")
        draw = ImageDraw.Draw(img)

        width, height = img.size

        for line in label_file.read_text().splitlines():

            parts = line.split()

            if len(parts) != 5:
                continue

            cls = int(parts[0])

            if cls != target_id:
                continue

            x, y, w, h = map(float, parts[1:])

            x1 = int((x - w / 2) * width)
            y1 = int((y - h / 2) * height)
            x2 = int((x + w / 2) * width)
            y2 = int((y + h / 2) * height)

            draw.rectangle(
                [x1, y1, x2, y2],
                outline="red",
                width=4
            )

        img.thumbnail((thumb_w, thumb_h))

        x = (i % cols) * thumb_w
        y = (i // cols) * thumb_h

        canvas.paste(img, (x, y))

    output = out / f"{class_name.lower()}.jpg"
    canvas.save(output, quality=95)

    print(f"{class_name}: {len(selected)} annotated images -> {output}")

print("Annotated contact sheets created.")
