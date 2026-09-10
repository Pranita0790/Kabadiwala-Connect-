from typing import Final


SUPPORTED_MATERIALS: Final[tuple[str, ...]] = (
    "crt",
    "lcd_panel",
    "pcb",
    "cable",
    "battery",
    "motor",
    "magnet_bearing_assembly",
    "mixed_plastics",
)

MODEL_SUPPORTED_MATERIALS: Final[tuple[str, ...]] = (
    "crt",
    "pcb",
    "battery",
)
