from pathlib import Path
from PIL import Image, ImageDraw
import random
import math

ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "data" / "processed" / "baseline" / "images"
OUTPUT = ROOT / "data" / "processed" / "baseline" / "visual_check"

CLASSES = ["battery", "crt", "pcb"]
SPLITS = ["train", "val", "test"]

SAMPLES_PER_CLASS = 12
SEED = 42

random.seed(SEED)

OUTPUT.mkdir(parents=True, exist_ok=True)

for split in SPLITS:

    for class_name in CLASSES:

        folder = DATASET / split / class_name

        files = [
            p for p in folder.iterdir()
            if p.is_file()
        ]

        if not files:
            continue

        sample = random.sample(
            files,
            min(SAMPLES_PER_CLASS, len(files))
        )

        thumbs = []

        for path in sample:

            try:
                image = Image.open(path).convert("RGB")
                image.thumbnail((220, 220))

                canvas = Image.new(
                    "RGB",
                    (240, 260),
                    "white"
                )

                x = (240 - image.width) // 2
                y = 5

                canvas.paste(image, (x, y))

                draw = ImageDraw.Draw(canvas)

                label = path.name[:30]

                draw.text(
                    (5, 230),
                    label,
                    fill="black"
                )

                thumbs.append(canvas)

            except Exception as exc:
                print(f"Could not open {path}: {exc}")

        cols = 4
        rows = math.ceil(len(thumbs) / cols)

        sheet = Image.new(
            "RGB",
            (cols * 240, rows * 260),
            "white"
        )

        for i, image in enumerate(thumbs):

            x = (i % cols) * 240
            y = (i // cols) * 260

            sheet.paste(image, (x, y))

        output = (
            OUTPUT
            / f"{split}_{class_name}.jpg"
        )

        sheet.save(
            output,
            quality=95
        )

        print(f"Created: {output}")


print("\nVisual samples created.")