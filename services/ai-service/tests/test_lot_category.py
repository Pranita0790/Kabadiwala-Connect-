from app.services.lot_category import lot_fields_for_material


def test_maps_model_labels_to_collector_categories():
    pcb = lot_fields_for_material("pcb")
    assert pcb["category_id"] == "pcb_motherboard"
    assert pcb["category"] == "Motherboard / PCB"
    assert pcb["electronic_device"]
    assert "Motherboard / PCB" in pcb["short_description"]

    assert lot_fields_for_material("cable")["category_id"] == "copper_wire"
    assert lot_fields_for_material("battery")["category"] == "Batteries"
    assert lot_fields_for_material("lcd_panel")["category"] == "Monitors & Displays"
    assert lot_fields_for_material("crt")["category_id"] == "display_monitor"
    assert lot_fields_for_material("motor")["category"] == "Heavy Electricals"
    assert lot_fields_for_material("mixed_plastics")["category"] == "Plastic"
    assert lot_fields_for_material("paper")["category"] == "Paper"
    assert lot_fields_for_material("book")["category"] == "Books"
    assert lot_fields_for_material("unknown")["category"] == "Mixed E-Waste"
