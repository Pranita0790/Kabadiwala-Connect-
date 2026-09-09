# Kabadiwala Connect — Dataset Sources

## 1. XBAT+ — WEEE Identification & Battery Detection

- Source: University of Limerick / Zenodo
- URL: https://doi.org/10.5281/zenodo.18022530
- Primary use: `battery`
- Secondary use: General WEEE visual diversity
- Dataset type: Real-world RGB + X-ray WEEE imagery
- RGB images: 330 train + 91 test
- Categories in release: 15 WEEE categories
- Our mapping: Battery-containing WEEE device categories -> supplementary battery-WEEE data; NOT directly mapped to `battery`
- License: CC BY-NC-ND 4.0 (non-commercial, no-derivatives)-NC 4.0 (Creative Commons Attribution 4.0 International)
- Strengths:
  - Real WEEE collection environments
  - RGB images suitable for our MobileNetV2 pipeline
  - Research-grade annotations and documentation
- Limitations:
  - Small RGB subset
  - Not designed specifically for our 8 material classes
  - Battery labels are associated with WEEE-device categories rather than our exact visual material taxonomy
  - X-ray images should not be mixed with RGB training data
- Decision: USE RGB subset as supplementary battery-WEEE context; do not use its device-category labels as direct `battery` labels.

## 2. E-Waste Image Dataset — Kaggle

- Source: Kaggle
- URL: https://www.kaggle.com/datasets/akshat103/e-waste-image-dataset
- Primary use: `pcb`, `battery`
- Dataset type: RGB e-waste images
- Relevant original classes: PCB, Battery, and other electronic-waste categories
- Our mapping:
  - PCB ? `pcb`
  - Battery ? `battery`
  - Other device classes ? NOT automatically mapped
- License: Apache 2.0 (dataset-level license; verify underlying image provenance before redistribution)
- Decision: USE PCB and Battery classes only, after quality, duplicate, and provenance inspection. Do NOT map device classes such as Television directly to CRT/LCD.

## 3. TACO — Trash Annotations in Context

- Source: TACO Dataset
- URL: https://tacodataset.org/
- Primary use: `mixed_plastics`
- Dataset type: Real-world RGB waste images with object annotations
- Our mapping:
  - Plastic objects ? `mixed_plastics`
  - Cable/electronic objects ? only if visually appropriate
- License: Annotations CC BY 4.0; individual images have source-specific licenses recorded in the annotations
- Decision: OPTIONAL supplementary source for `mixed_plastics`; use only images whose individual licenses permit our intended use.

## 4. WasteNet — Waste Classification Dataset

- Source: Public waste-image dataset
- Primary use: `mixed_plastics`
- Dataset type: RGB waste classification imagery
- License: MUST be verified from the original dataset repository before use
- Decision: CANDIDATE ONLY; approve after source/license/class inspection.

# 5. Initial Coverage & Collection Gap Analysis

| Our Class | Public Dataset Coverage | Self-Collection Need |
|---|---|---|
| `battery` | GOOD | YES — improve real-world diversity |
| `pcb` | GOOD | YES — especially damaged/dirty PCBs |
| `lcd_panel` | MODERATE | YES |
| `crt` | WEAK | HIGH |
| `cable` | WEAK–MODERATE | HIGH |
| `motor` | VERY WEAK | VERY HIGH |
| `magnet_bearing_assembly` | VERY WEAK | VERY HIGH |
| `mixed_plastics` | GOOD | YES — especially e-waste plastics |

## Priority for Self-Collection

1. `magnet_bearing_assembly`
2. `motor`
3. `crt`
4. `cable`
5. `lcd_panel`
6. `pcb`
7. `battery`
8. `mixed_plastics`

## Collection Principle

Public datasets will provide initial visual diversity, while self-collected images will specifically fill:
- Indian scrap-yard/kabadi environments
- Different lighting conditions
- Dirty, damaged and partially dismantled materials
- Different camera distances and orientations
- Realistic backgrounds
- Visually confusing examples between classes

## 5. Laptop Components Dataset — Mendeley Data

- Source: East West University / Mendeley Data
- URL: https://data.mendeley.com/datasets/pwctygncrj/4
- Dataset type: RGB laptop-component images
- Total images: 29,120
- Classes: 26
- Relevant original classes:
  - Battery
  - DCCable
  - LCDScreen
  - LVDSCable
- Our mapping:
  - Battery -> `battery`
  - LCDScreen -> `lcd_panel`
  - DCCable -> `cable`
  - LVDSCable -> `cable`
- License: CC BY-NC-ND 4.0 (non-commercial, no-derivatives)-NC 4.0
- Strengths:
  - Direct component-level imagery
  - 140 raw images per class; 3,640 raw images total
  - Useful for our `battery`, `lcd_panel`, and `cable` classes
- Limitations:
  - Components are from laptop hardware, not general scrap
  - Dataset has strong domain bias toward HP laptop components
  - Augmented images should NOT be counted as independent real samples
- Decision: HIGH-VALUE supplementary dataset; prioritize raw images.


## 6. RecyBat24 — Lithium-Ion Battery Dataset

- Source: University of Calabria / Zenodo
- URL: https://doi.org/10.5281/zenodo.15226091
- Dataset type: RGB battery images with detection annotations
- Original battery types:
  - Cylindrical
  - Pouch
  - Prismatic
- Non-augmented images: 2,828
- Our mapping:
  - All three battery types -> `battery`
- License: CC BY-NC-ND 4.0 (non-commercial, no-derivatives)
- Strengths:
  - Dedicated battery dataset
  - Real-world acquisition conditions
  - Much stronger direct match for `battery` than XBAT+
- Limitations:
  - Focused on lithium-ion batteries
  - Does not represent every battery type found in Indian scrap
  - Augmented release is much larger but should not be treated as independent real-world samples
- Decision: HIGH-VALUE core supplementary source for `battery`.


## 7. University of Birmingham — Electric Vehicle Motor Disassembly

- Source: University of Birmingham eData
- URL: https://edata.bham.ac.uk/605/
- Dataset type: RGB image
- Topic: Electric vehicle motor disassembly, magnets and recycling
- Publicly visible images: 1
- Our mapping:
  - Motor imagery -> `motor` (supplementary only)
  - Magnet/disassembly imagery -> NOT automatically mapped to `magnet_bearing_assembly`
- License: CC BY 4.0
- Strengths:
  - Directly related to motor recycling
  - Openly accessible
  - Relevant to magnet recovery
- Limitations:
  - Extremely small public image count
  - Not sufficient for model training
  - Does not represent our exact `motor` class definition
- Decision: REFERENCE/SUPPLEMENTARY ONLY; self-collected motor images remain essential.


## 8. E-Waste Object Detection Dataset — Roboflow

- Source: Roboflow Universe / Electronic Waste Detection
- URL: https://universe.roboflow.com/electronic-waste-detection/e-waste-dataset-r0ojc
- Dataset type: RGB object-detection dataset
- Total images: 19,613
- Total classes: 77
- Relevant classes:
  - CRT-Monitor
  - CRT-TV
  - Flat-Panel-Monitor
  - Flat-Panel-TV
  - Battery
  - Printed Circuit Board
- Our mapping:
  - CRT-Monitor / CRT-TV -> `crt`
  - Flat-Panel-Monitor / Flat-Panel-TV -> `lcd_panel` (supplementary; not guaranteed LCD-only)
  - Battery -> `battery` (only if class inspection confirms suitable imagery)
  - Printed Circuit Board -> `pcb` (only if class inspection confirms suitable imagery)
- License: CC BY 4.0
- Strengths:
  - Large e-waste-specific dataset
  - Explicit CRT vs flat-panel distinction
  - Object annotations
  - Broad device diversity
- Limitations:
  - Flat-panel classes may include LED/LCD displays
  - Device-level classes are not identical to our material taxonomy
  - Source/provenance and duplicate inspection are required
- Decision: HIGH-VALUE candidate for `crt` and `lcd_panel`; inspect before training.


## 9. Custom Bangladeshi E-Waste Image Dataset

- Source: Mendeley Data / East West University
- URL: https://data.mendeley.com/datasets/77383kmdnw/1
- Dataset type: RGB e-waste images
- Total images: 2,157
- Classes: 12
- Relevant classes:
  - Battery Waste
  - PCB
  - Plastic Waste
- Our mapping:
  - Battery Waste -> `battery`
  - PCB -> `pcb`
  - Plastic Waste -> `mixed_plastics` (supplementary)
- License: CC BY 4.0
- Strengths:
  - Real-world smartphone/handheld image capture
  - Varied lighting and backgrounds
  - Directly relevant e-waste classes
  - Similar South Asian environmental context
- Limitations:
  - Bangladesh collection environment is not identical to India
  - Only three classes directly help our taxonomy
  - Plastic Waste is broader than our mixed e-waste plastics definition
- Decision: HIGH-VALUE supplementary source for `battery`, `pcb`, and `mixed_plastics`.


# 10. Final Public Dataset Coverage Matrix

| Our Class | Best Public Sources | Coverage | Self-Collection |
|---|---|---|---|
| `crt` | E-Waste Object Detection | GOOD | YES |
| `lcd_panel` | Laptop Components + E-Waste Object Detection | GOOD | YES |
| `pcb` | Kaggle E-Waste + Bangladeshi E-Waste + E-Waste Object Detection | GOOD | YES |
| `battery` | RecyBat24 + Kaggle E-Waste + Bangladeshi E-Waste | GOOD | YES |
| `cable` | Laptop Components | MODERATE | HIGH |
| `motor` | Birmingham motor dataset | VERY WEAK | VERY HIGH |
| `magnet_bearing_assembly` | No strong public match identified | VERY WEAK | VERY HIGH |
| `mixed_plastics` | TACO + Bangladeshi E-Waste | MODERATE | HIGH |

## Dataset Strategy

Public datasets will be used only where the original class semantics are sufficiently compatible with our taxonomy.

We will NOT relabel a broad device category into a material class without visual/class inspection.

Self-collected imagery is mandatory for specialized classes and will provide:
- Indian kabadi/scrap-yard conditions
- Damaged and dirty materials
- Multiple viewpoints
- Different lighting and backgrounds
- Partially dismantled components
- Hard negative/confusing examples

The final training dataset will maintain source attribution and license information for every imported public dataset.

