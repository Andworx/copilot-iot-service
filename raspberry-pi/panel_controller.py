"""
AgenticIoT — Panel Controller
Manages GPIO operations and switch-to-LED logic mapping for the IoT demo panel.

Hardware layout:
  Switches  GPIO 5, 6, 13, 19  (BCM, pulled-up — LOW when pressed)
  LEDs      GPIO 18, 24, 25, 12 (BCM)

Falls back to a software simulation when RPi.GPIO is unavailable so the
service can be developed and tested off-hardware.
"""

import json
import os
import logging
import random
import time

logger = logging.getLogger(__name__)

# ─── GPIO abstraction ─────────────────────────────────────────────────────────
try:
    import RPi.GPIO as GPIO
    SIMULATION_MODE = False
    logger.info("Using real GPIO hardware")
except ImportError:
    logger.warning("RPi.GPIO not available — running in simulation mode")
    SIMULATION_MODE = True

    class MockGPIO:
        """Minimal GPIO stub for off-Pi development."""
        BCM = "BCM"
        IN = "IN"
        OUT = "OUT"
        PUD_UP = "PUD_UP"
        HIGH = 1
        LOW = 0

        @staticmethod
        def setmode(mode): pass

        @staticmethod
        def setup(pin, mode, pull_up_down=None): pass

        @staticmethod
        def input(pin):
            return random.choice([0, 1])

        @staticmethod
        def output(pin, state): pass

        @staticmethod
        def cleanup(): pass

    GPIO = MockGPIO()


class PanelController:
    """Controls 4 digital switches and 4 LEDs with configurable logic mapping."""

    SWITCH_PINS = [5, 6, 13, 19]    # BCM pin numbers for switch inputs
    LED_PINS    = [18, 24, 25, 12]  # BCM pin numbers for LED outputs

    def __init__(self, logic_map_path=None):
        logger.info("Initialising Panel Controller…")

        if not SIMULATION_MODE:
            GPIO.setmode(GPIO.BCM)
            for pin in self.SWITCH_PINS:
                GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)
            for pin in self.LED_PINS:
                GPIO.setup(pin, GPIO.OUT)
                GPIO.output(pin, GPIO.LOW)

        if logic_map_path is None:
            logic_map_path = os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "logic_map.json"
            )

        self.logic_map = self.load_logic_mapping(logic_map_path)
        self.current_led_states = [False] * 4

        if SIMULATION_MODE:
            self.sim_switch_states = [False] * 4
            self.sim_led_states = [False] * 4

        logger.info(
            "Controller ready — switches: %s  LEDs: %s",
            self.SWITCH_PINS,
            self.LED_PINS,
        )

    # ─── Config ───────────────────────────────────────────────────────────────

    def load_logic_mapping(self, path):
        try:
            with open(path) as f:
                mapping = json.load(f)
            logger.info("Logic mapping loaded: %d rules", len(mapping["rules"]))
            return mapping
        except Exception as e:
            logger.error("Failed to load logic mapping from %s: %s", path, e)
            return {
                "rules": [],
                "fallback": {"leds": [0], "description": "Default: LED 1 only"},
            }

    # ─── GPIO operations ──────────────────────────────────────────────────────

    def poll_switches(self):
        """Read the current state of all 4 switches. Returns list of bools."""
        if SIMULATION_MODE:
            # Cycle through all 16 switch combinations so tests see varied states
            cycle = int(time.time()) % 16
            states = [bool(cycle & (1 << i)) for i in range(4)]
            self.sim_switch_states = states
            return states

        # Pull-up: GPIO.LOW (0) means switch is pressed → True
        return [not GPIO.input(pin) for pin in self.SWITCH_PINS]

    def apply_logic_rules(self, switch_states):
        """
        Match active switches against logic_map rules.
        Returns (led_indices, rule_id).
        """
        active = {i + 1 for i, s in enumerate(switch_states) if s}

        for rule in self.logic_map["rules"]:
            if set(rule["switches"]) == active:
                logger.debug("Rule matched: %s — %s", rule["id"], rule.get("description", ""))
                return rule["leds"], rule["id"]

        fallback = self.logic_map["fallback"]
        logger.debug("Fallback rule: %s", fallback.get("description", "default"))
        return fallback["leds"], "fallback"

    def update_leds(self, led_indices):
        """Drive LED outputs according to the active rule."""
        new_states = [False] * 4
        for idx in led_indices:
            if 0 <= idx < 4:
                new_states[idx] = True

        if SIMULATION_MODE:
            self.sim_led_states = new_states.copy()
            # Optionally inject simulated hardware faults
            fp = self.logic_map.get("false_positives", {})
            if fp.get("enabled", False):
                prob = fp.get("probability", 0.1)
                for i in range(4):
                    if random.random() < prob:
                        self.sim_led_states[i] = not self.sim_led_states[i]
            on_leds = [i + 1 for i, s in enumerate(new_states) if s]
            print(f"💡 LEDs: {on_leds if on_leds else 'none'}")
        else:
            for i, state in enumerate(new_states):
                GPIO.output(self.LED_PINS[i], GPIO.HIGH if state else GPIO.LOW)

        self.current_led_states = new_states

    def get_led_states(self):
        """Return the current LED states (actual hardware or simulation)."""
        return self.sim_led_states if SIMULATION_MODE else self.current_led_states

    def cleanup(self):
        logger.info("Cleaning up GPIO…")
        if not SIMULATION_MODE:
            GPIO.cleanup()
