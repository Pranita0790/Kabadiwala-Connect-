from pathlib import Path
import shutil

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]

SOURCE = ROOT / "data" / "processed" / "baseline"
OUTPUT = ROOT / "data" / "processed" / "baseline_clean"

MIN_WIDTH = 32
MIN_HEIGHT = 32


def main():
    if OUTPUT.exists():
        raise RuntimeError(
            f"Output already exists:\n{OUTPUT}\n\n"
            "Refusing to overwrite it."
        )

    metadata_path = SOURCE / "metadata.csv"

    if not metadata_path.exists():
        raise FileNotFoundError(
            f"Missing metadata file: {metadata_path}"
        )

    metadata = pd.read_csv(metadata_path)

    print("=" * 70)
    print("Creating clean baseline dataset")
    print("=" * 70)

    print(f"\nSource samples: {len(metadata)}")
    print(
        f"Minimum image size: "
        f"{MIN_WIDTH}x{MIN_HEIGHT}"
    )

    kept_rows = []
    removed_rows = []

    for _, row in metadata.iterrows():

        source_path = (
            SOURCE
            / "images"
            / row["split"]
            / row["target_class"]
            / row["filename"]
        )

        if not source_path.exists():
            print(
                f"[WARNING] Missing: {source_path}"
            )
            removed_rows.append(row)
            continue

        from PIL import Image

        try:
            with Image.open(source_path) as image:
                width, height = image.size
        except Exception as exc:
            print(
                f"[WARNING] Invalid image: "
                f"{source_path}: {exc}"
            )
            removed_rows.append(row)
            continue

        if (
            width < MIN_WIDTH
            or height < MIN_HEIGHT
        ):
            removed_rows.append(row)
            continue

        kept_rows.append(row)

    kept = pd.DataFrame(kept_rows)
    removed = pd.DataFrame(removed_rows)

    # ------------------------------------------------------------
    # Create output directories.
    # ------------------------------------------------------------

    for split in ["train", "val", "test"]:
        for class_name in sorted(
            metadata["target_class"].unique()
        ):
            (
                OUTPUT
                / "images"
                / split
                / class_name
            ).mkdir(
                parents=True,
                exist_ok=True,
            )

    # ------------------------------------------------------------
    # Copy kept images.
    # ------------------------------------------------------------

    print("\nCopying kept images...")

    for index, row in kept.iterrows():

        source_path = (
            SOURCE
            / "images"
            / row["split"]
            / row["target_class"]
            / row["filename"]
        )

        destination = (
            OUTPUT
            / "images"
            / row["split"]
            / row["target_class"]
            / row["filename"]
        )

        shutil.copy2(
            source_path,
            destination,
        )

        if (index + 1) % 500 == 0:
            print(
                f"  Processed "
                f"{index + 1}/{len(metadata)}"
            )

    # ------------------------------------------------------------
    # Save metadata.
    # ------------------------------------------------------------

    kept.to_csv(
        OUTPUT / "metadata.csv",
        index=False,
    )

    if len(removed) > 0:
        removed.to_csv(
            OUTPUT / "removed.csv",
            index=False,
        )

    # ------------------------------------------------------------
    # Summary.
    # ------------------------------------------------------------

    print("\n" + "=" * 70)
    print("CLEAN BASELINE SUMMARY")
    print("=" * 70)

    for class_name in sorted(
        metadata["target_class"].unique()
    ):

        original_count = (
            metadata["target_class"]
            .eq(class_name)
            .sum()
        )

        kept_count = (
            kept["target_class"]
            .eq(class_name)
            .sum()
        )

        removed_count = (
            original_count
            - kept_count
        )

        print(
            f"{class_name:10s} | "
            f"original={original_count:4d} | "
            f"removed={removed_count:4d} | "
            f"kept={kept_count:4d}"
        )

    print("-" * 70)

    print(
        f"Total original: {len(metadata)}"
    )

    print(
        f"Total removed:  {len(removed)}"
    )

    print(
        f"Total kept:     {len(kept)}"
    )

    print(
        f"\nOutput:"
        f"\n{OUTPUT}"
    )

    print("\nDONE.")


if __name__ == "__main__":
    main()