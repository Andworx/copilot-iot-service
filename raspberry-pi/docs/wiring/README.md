# GPIO Wiring Reference — AgenticIoT Digital Logic Panel

This document describes the physical wiring for the AgenticIoT demo panel connected to the Raspberry Pi.

## Pin Assignment (BCM numbering)

| Index | Role   | BCM Pin | Physical Pin | Notes                        |
|-------|--------|---------|--------------|------------------------------|
| 0     | Switch | GPIO 5  | Pin 29       | Pull-up, LOW when pressed    |
| 1     | Switch | GPIO 6  | Pin 31       | Pull-up, LOW when pressed    |
| 2     | Switch | GPIO 13 | Pin 33       | Pull-up, LOW when pressed    |
| 3     | Switch | GPIO 19 | Pin 35       | Pull-up, LOW when pressed    |
| 0     | LED    | GPIO 18 | Pin 12       | Active HIGH (3.3 V via 330 Ω)|
| 1     | LED    | GPIO 24 | Pin 18       | Active HIGH (3.3 V via 330 Ω)|
| 2     | LED    | GPIO 25 | Pin 22       | Active HIGH (3.3 V via 330 Ω)|
| 3     | LED    | GPIO 12 | Pin 32       | Active HIGH (3.3 V via 330 Ω)|

> **Ground**: Use any GND pin (e.g. Pin 6, 9, 14, 20, 25, 30, 34, or 39).

## Schematic Summary

```
3.3V ──────────────────────────────────── PUD_UP (internal)
                                           │
                ┌──────────────────────────┤
                │  GPIO 5  (BCM) ──────────┤─── SW0 ─── GND
                │  GPIO 6  (BCM) ──────────┤─── SW1 ─── GND
                │  GPIO 13 (BCM) ──────────┤─── SW2 ─── GND
                │  GPIO 19 (BCM) ──────────┤─── SW3 ─── GND
                └──────────────────────────┘

GPIO 18 (BCM) ──[ 330Ω ]──[ LED0 ]── GND
GPIO 24 (BCM) ──[ 330Ω ]──[ LED1 ]── GND
GPIO 25 (BCM) ──[ 330Ω ]──[ LED2 ]── GND
GPIO 12 (BCM) ──[ 330Ω ]──[ LED3 ]── GND
```

## Component Values

| Component | Value | Purpose |
|-----------|-------|---------|
| LED series resistor | 330 Ω | Limits LED current to ~10 mA at 3.3 V |
| Switch pull-up | Internal PUD_UP | ~50 kΩ internal pull-up via `GPIO.PUD_UP` |

> **LED current calculation**: (3.3 V − 2.0 V forward voltage) / 330 Ω ≈ 4 mA (safe for all standard 5 mm LEDs).  
> Use 220 Ω for brighter output if needed.

## Logic Map

The `logic_map.json` file defines the switch → LED rules:

| Rule ID           | Switches active | LEDs on         | Description                        |
|-------------------|-----------------|-----------------|------------------------------------|
| `all_lights_on`   | SW1 + SW3       | All 4 LEDs      | Target healthy state               |
| `single_light`    | SW2             | LED2 (GPIO 25)  | Green LED                          |
| `pattern_lights`  | SW1 + SW2       | LED0 + LED2     | Blue + green                       |
| `diagnostic_mode` | SW1 + SW2 + SW3 | LED1 + LED3     | Orange + yellow                    |
| `shutdown_sequence`| SW1 + SW2 + SW4| None            | All LEDs off                       |
| `switch_4_only`   | SW4             | LED3 (GPIO 12)  | Yellow LED                         |
| `fallback`        | (no match)      | LED0 (GPIO 18)  | Default: blue LED only             |

> Switch indices in `logic_map.json` are **1-based** (SW1 = GPIO 5, SW4 = GPIO 19).  
> LED indices are **0-based** (LED0 = GPIO 18, LED3 = GPIO 12).

## Updating This Document

Update this file whenever:
- GPIO pin assignments change in `panel_controller.py` (`SWITCH_PINS` / `LED_PINS`)
- Logic rules change in `logic_map.json`
- Hardware components are replaced with different values
