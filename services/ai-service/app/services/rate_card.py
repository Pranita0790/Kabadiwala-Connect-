from app.models.material_rate import MaterialRate


RATE_CARD: dict[str, MaterialRate] = {}


def get_material_rate(material: str) -> MaterialRate | None:
    return RATE_CARD.get(material)