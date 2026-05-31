# 3D Models

Printable enclosure for the AgenticIoT Raspberry Pi IoT panel node.

The case mounts the Raspberry Pi board and exposes the GPIO-connected switches and LEDs through a front bezel, keeping the hardware tidy for demonstration and deployment.

## Files

| File | Format | Description |
|------|--------|-------------|
| `IoTCase.3mf` | 3MF | Full project file — preferred format; retains print settings, orientation, and part colours |
| `iot_case_whole.stl` | STL | Main enclosure body |
| `iot_case_door.stl` | STL | Removable rear access door |
| `iot_case_bezel.stl` | STL | Front bezel — routes switches and LEDs to the panel face |

## Printing

- **Recommended slicer:** PrusaSlicer or Bambu Studio (open `IoTCase.3mf` directly)
- **Material:** PLA or PETG — no heated enclosure required
- **Layer height:** 0.2 mm standard quality
- **Infill:** 15–20 % for the body; 30 %+ for the bezel if hardware is a tight fit
- **Supports:** Required for the door and bezel overhangs

## Updating This README

Update this file when new parts are added, the enclosure design changes, or print settings are revised.
