# IoT Panel Troubleshooting Guide

## Overview

The AgenticIoT demo panel is a physical hardware panel connected to a Raspberry Pi. It consists of four switches and four LEDs wired to GPIO pins. The panel streams telemetry to Azure IoT Hub, which flows through Event Hub to an Azure Function, SignalR Service, and Power Pages dashboard in real time.

The Copilot Studio agent monitors incoming telemetry and assists users in diagnosing and resolving panel state mismatches.

---

## Panel Hardware

### Switches

| Switch | Label | Physical Type | How to Operate |
|--------|-------|---------------|----------------|
| SW1 | Switch 1 | Military-style red toggle switch | Flip the toggle up or down to activate/deactivate |
| SW2 | Switch 2 | Military-style red toggle switch | Flip the toggle up or down to activate/deactivate |
| SW3 | Switch 3 | Keyed switch | Insert the physical key and turn to activate |
| SW4 | Switch 4 | Keyed switch | Insert the physical key and turn to activate |

SW1 and SW2 are military-style red toggle switches used for standard on/off control. SW3 and SW4 are keyed switches that require a physical key to operate, providing an additional layer of access control.

### LEDs

| LED | GPIO (BCM) | Physical Pin | Colour |
|-----|-----------|--------------|--------|
| LED0 | GPIO 18 | Pin 12 | Blue |
| LED1 | GPIO 24 | Pin 18 | Orange |
| LED2 | GPIO 25 | Pin 22 | Green |
| LED3 | GPIO 12 | Pin 32 | Yellow |

All LEDs are active-HIGH and wired with a 330-ohm series resistor (approximately 4 mA at 3.3 V).

### GPIO Switch Wiring

| Switch | GPIO (BCM) | Physical Pin | Logic |
|--------|-----------|--------------|-------|
| SW1 | GPIO 5 | Pin 29 | Pull-up, LOW when active |
| SW2 | GPIO 6 | Pin 31 | Pull-up, LOW when active |
| SW3 | GPIO 13 | Pin 33 | Pull-up, LOW when active |
| SW4 | GPIO 19 | Pin 35 | Pull-up, LOW when active |

---

## Logic Map

The panel applies switch-to-LED rules defined in `logic_map.json`. Rules are evaluated in order; the first match wins. If no rule matches, the fallback applies.

| Rule ID | Switches Active | LEDs On | Description |
|---------|----------------|---------|-------------|
| `all_lights_on` | SW1 + SW3 | LED0, LED1, LED2, LED3 | Target healthy state — all 4 LEDs on |
| `single_light` | SW2 only | LED2 | Green LED only |
| `pattern_lights` | SW1 + SW2 | LED0, LED2 | Blue + green |
| `diagnostic_mode` | SW1 + SW2 + SW3 | LED1, LED3 | Orange + yellow |
| `shutdown_sequence` | SW1 + SW2 + SW4 | None | All LEDs off |
| `switch_4_only` | SW4 only | LED3 | Yellow LED only |
| fallback | (no rule matched) | LED0 | Default: blue LED only |

---

## Healthy State Definition

A panel is considered healthy when **all four LEDs (LED0, LED1, LED2, LED3) are ON simultaneously**.

The only switch combination that produces this state is **SW1 + SW3 active** (rule: `all_lights_on`).

This is always the target state regardless of the current mismatch, active rule, or fault flag present in telemetry.

---

## How to Fix a Broken Panel

This section provides step-by-step instructions to restore the panel to its healthy state (all 4 LEDs on).

### Goal

Get all four LEDs on at the same time. The only way to achieve this is to have SW1 and SW3 active simultaneously, with SW2 and SW4 inactive.

### Step-by-Step Fix

1. **Locate SW3 (keyed switch)** — this is a keyed switch. You will need the physical key.
2. **Insert the key into SW3** and turn it to the active position.
3. **Locate SW1 (red toggle switch)** — flip the toggle to the active (up) position.
4. **Verify SW2 is inactive** — SW2 should be in the off/down position.
5. **Verify SW4 is inactive** — SW4 key should be turned to the off position (or key removed).
6. **Confirm the result** — all four LEDs (blue, orange, green, yellow) should now be lit. If not, check the telemetry on the dashboard and repeat from step 1.

### Common Mismatch Scenarios

| Observed State | Likely Cause | Fix |
|----------------|-------------|-----|
| Only LED0 (blue) on | No rule matched — SW combination not recognised | Activate SW1 + SW3, deactivate SW2 and SW4 |
| Only LED2 (green) on | SW2 only active (rule: `single_light`) | Activate SW1 and SW3; deactivate SW2 |
| LED0 + LED2 on | SW1 + SW2 active (rule: `pattern_lights`) | Activate SW3; deactivate SW2 |
| LED1 + LED3 on | SW1 + SW2 + SW3 active (rule: `diagnostic_mode`) | Deactivate SW2; keep SW1 + SW3 active |
| All LEDs off | SW1 + SW2 + SW4 active (rule: `shutdown_sequence`) | Deactivate SW2 and SW4; keep SW1; activate SW3 |
| Only LED3 (yellow) on | SW4 only active (rule: `switch_4_only`) | Deactivate SW4; activate SW1 + SW3 |

### Quick-Fix Summary (plain steps)

When a user reports the panel is broken or requests a quick fix, provide only these steps:

1. Turn SW3 key to the active position.
2. Flip SW1 toggle to the active (up) position.
3. Ensure SW2 toggle is in the off (down) position.
4. Ensure SW4 key is in the off position.
5. Confirm all four LEDs are now lit.

---

## Telemetry and `needs_help` Flag

When the panel detects a mismatch between expected and actual state, it sets `needs_help: true` in the telemetry payload sent to Azure IoT Hub. This flag triggers the Copilot agent to start a diagnostic session.

The telemetry payload also includes:
- `switches`: array of active switch indices (1-based)
- `leds`: array of active LED indices (0-based)
- `active_rule`: the rule ID currently matched, or `null` if no rule matched
- `needs_help`: boolean mismatch flag

---

## Azure Resource Names

| Resource | Name |
|----------|------|
| IoT Hub | `iothub-aw-iot-copilot` |
| Event Hub Namespace | `evhns-aw-iot-copilot` |
| Event Hub | `iot-telemetry` |
| Azure Function App | `func-aw-iot-copilot` |
| SignalR Service | (configured in Function App settings) |
| Resource Group | `rg-aw-azcom-iot-copilot` |
| IoT Device ID | `raspberry-pi-iotpanel` |

---

## Troubleshooting Common Issues

### Panel not streaming telemetry

1. Verify the Raspberry Pi is powered on and the `iot-monitor` service is running:  
   `sudo systemctl status iot-monitor`
2. Check the IoT Hub connection string is set in `/opt/iot-monitor/.env`.
3. Verify network connectivity from the Pi to Azure.
4. Check IoT Hub routing in the Azure Portal — confirm the route to the `iot-telemetry` Event Hub is enabled.

### Dashboard not updating in real time

1. Confirm the Azure Function App (`func-aw-iot-copilot`) is running.
2. Check the `IoTHubEventHubConnectionString` app setting is populated in the Function App.
3. Verify the SignalR Service connection in the Function App configuration.
4. Reload the Power Pages dashboard and check browser console for SignalR connection errors.

### LED does not respond to switch

1. Check the GPIO wiring against the pin table in the Panel Hardware section above.
2. Verify the switch pull-up is working — measure pin voltage when switch is open (should be ~3.3 V) and when closed (should be ~0 V).
3. Check `panel_controller.py` for the correct BCM pin numbers.
4. Restart the `iot-monitor` service on the Pi.
