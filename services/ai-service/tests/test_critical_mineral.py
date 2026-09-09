from app.services.critical_mineral import check_critical_mineral


def test_electronic_waste_is_potentially_critical():
    result = check_critical_mineral("electronic_waste")

    assert result.critical_mineral is True
    assert result.material == "electronic_waste"
    assert result.critical_mineral_reason is not None


def test_lithium_battery_is_potentially_critical():
    result = check_critical_mineral("lithium battery")

    assert result.critical_mineral is True
    assert result.material == "lithium_battery"


def test_aluminium_is_not_flagged():
    result = check_critical_mineral("aluminium")

    assert result.critical_mineral is False
    assert result.critical_mineral_reason is None


def test_material_normalization():
    result = check_critical_mineral("  Electronic Waste  ")

    assert result.material == "electronic_waste"
    assert result.critical_mineral is True
