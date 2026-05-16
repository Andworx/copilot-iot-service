#!/usr/bin/env python3
"""
AgenticIoT — IoT Monitor
Raspberry Pi GPIO panel monitor with Azure IoT Hub telemetry.

Architecture:
  GPIO switches/LEDs → panel_controller.py
  Azure IoT Hub      → iot_client.py
  Local web API      → api_server.py
  Configuration      → logic_map.json
"""

import time
import logging
import sys
import os
import json
import threading
from datetime import datetime, timezone
from dotenv import load_dotenv

from panel_controller import PanelController
from api_server import APIServer
from iot_client import IoTHubClient

# ─── Logging ──────────────────────────────────────────────────────────────────
LOG_DIR = "/var/log/iot-monitor"
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, "iot-monitor.log")),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger("IoTMonitor")

# ─── Constants ────────────────────────────────────────────────────────────────
ENV_PATH = "/opt/iot-monitor/.env"
CONFIG_CHECK_CYCLES = 10   # check for config changes every N poll cycles
POLL_INTERVAL_SECS = 2     # seconds between GPIO polls
HEARTBEAT_INTERVAL_SECS = 30


class SimpleMonitor:
    """Main monitoring loop: GPIO → logic rules → LEDs → IoT Hub telemetry."""

    def __init__(self):
        self.panel = PanelController()
        self.running = False
        self.api_server = None
        self.iot_hub_client = None
        self.iot_hub_device_id = None
        self.config_file = os.path.join(os.path.dirname(__file__), "logic_map.json")
        self.last_config_mtime = 0
        self.previous_switch_states = None
        self.last_heartbeat_time = 0
        self._twin_updated = threading.Event()  # set by Device Twin patch callback

        if os.path.exists(ENV_PATH):
            load_dotenv(ENV_PATH)
            logger.info("Loaded environment from %s", ENV_PATH)
        else:
            logger.warning(".env not found at %s — IoT Hub will be disabled", ENV_PATH)

        logger.info("SimpleMonitor initialised")

    # ─── Config ───────────────────────────────────────────────────────────────

    def load_config(self):
        try:
            with open(self.config_file) as f:
                return json.load(f)
        except Exception as e:
            logger.error("Failed to load config: %s", e)
            return None

    def check_config_changes(self):
        try:
            mtime = os.path.getmtime(self.config_file)
            if mtime != self.last_config_mtime:
                logger.info("Configuration changed — reloading")
                self.last_config_mtime = mtime
                self.panel.logic_map = self.panel.load_logic_mapping(self.config_file)
                config = self.load_config()
                if config:
                    self.manage_api_server(config.get("web_ui", {}))
                return True
        except Exception as e:
            logger.error("Error checking config changes: %s", e)
        return False

    # ─── API server lifecycle ─────────────────────────────────────────────────

    def manage_api_server(self, web_ui_config):
        enabled = web_ui_config.get("enabled", False)

        if self.api_server:
            self.api_server.stop()
            self.api_server = None

        if enabled:
            try:
                logger.info("Starting API server (web_ui.enabled = true)…")
                self.api_server = APIServer(self.panel, web_ui_config)
                self.api_server.start()
            except Exception as e:
                logger.error("Failed to start API server: %s", e, exc_info=True)
                self.api_server = None

    # ─── IoT Hub lifecycle ────────────────────────────────────────────────────

    def manage_iot_hub(self, iot_hub_config):
        enabled = iot_hub_config.get("enabled", False)

        if enabled and not self.iot_hub_client:
            env_var = iot_hub_config.get("connection_string_env", "IOT_HUB_CONNECTION_STRING")
            connection_string = os.getenv(env_var)
            device_id = iot_hub_config.get("device_id", "raspberry-pi-iotpanel")

            if not connection_string:
                logger.warning(
                    "IoT Hub enabled but %s is not set in %s", env_var, ENV_PATH
                )
                return

            try:
                logger.info("Connecting to IoT Hub as device '%s'…", device_id)
                self.iot_hub_device_id = device_id
                self.iot_hub_client = IoTHubClient(connection_string, device_id)
                if not self.iot_hub_client.connect():
                    self.iot_hub_client = None
                    logger.error("IoT Hub connection failed")
            except Exception as e:
                logger.error("Failed to start IoT Hub client: %s", e, exc_info=True)
                self.iot_hub_client = None

        elif not enabled and self.iot_hub_client:
            logger.info("Stopping IoT Hub client (iot_hub.enabled = false)…")
            self.iot_hub_client.disconnect()
            self.iot_hub_client = None

    # ─── Device Twin config sync ──────────────────────────────────────────────

    def _sync_twin_config(self):
        """Fetch Device Twin on startup and register live-update callback.

        If desired.logic_map exists in the twin, it overwrites local logic_map.json
        and reloads all subsystems.  If the twin has no logic_map (e.g. first deploy),
        the local file is used as-is — no disruption.
        """
        if not self.iot_hub_client:
            return

        synced = self.iot_hub_client.sync_config_from_twin(self.config_file)
        if synced:
            logger.info("Reloading subsystems with Device Twin config…")
            config = self.load_config()
            if config:
                self.last_config_mtime = os.path.getmtime(self.config_file)
                self.panel.logic_map = self.panel.load_logic_mapping(self.config_file)
                self.manage_api_server(config.get("web_ui", {}))

        def _on_twin_updated(_logic_map):
            """Called from the SDK thread when a twin patch arrives."""
            self._twin_updated.set()

        self.iot_hub_client.register_twin_patch_callback(
            self.config_file, on_config_updated=_on_twin_updated
        )

    # ─── Main loop ────────────────────────────────────────────────────────────

    def start_monitoring(self):
        self.running = True
        logger.info("Starting monitoring loop…")

        config = self.load_config()
        if config:
            self.last_config_mtime = os.path.getmtime(self.config_file)
            self.manage_api_server(config.get("web_ui", {}))
            self.manage_iot_hub(config.get("iot_hub", {}))
            self._sync_twin_config()

        try:
            cycle_count = 0
            while self.running:
                switch_states = self.panel.poll_switches()
                led_indices, rule_id = self.panel.apply_logic_rules(switch_states)
                self.panel.update_leds(led_indices)
                self._send_telemetry(switch_states, led_indices, rule_id)

                logger.debug("Rule: %s  LEDs: %s", rule_id, led_indices)

                cycle_count += 1
                if cycle_count >= CONFIG_CHECK_CYCLES:
                    self.check_config_changes()
                    cycle_count = 0

                # Device Twin push update (set from SDK callback thread)
                if self._twin_updated.is_set():
                    self._twin_updated.clear()
                    logger.info("Device Twin config update received — reloading…")
                    config = self.load_config()
                    if config:
                        self.last_config_mtime = os.path.getmtime(self.config_file)
                        self.panel.logic_map = self.panel.load_logic_mapping(self.config_file)
                        self.manage_api_server(config.get("web_ui", {}))
                        self.manage_iot_hub(config.get("iot_hub", {}))

                time.sleep(POLL_INTERVAL_SECS)

        except KeyboardInterrupt:
            logger.info("Monitoring stopped by user (Ctrl+C)")
        except Exception as e:
            logger.error("Monitoring error: %s", e, exc_info=True)
        finally:
            self.stop_monitoring()

    # ─── Telemetry ────────────────────────────────────────────────────────────

    def _send_telemetry(self, switch_states, led_indices, rule_id):
        if not self.iot_hub_client:
            return

        now = time.time()
        state_changed = (
            self.previous_switch_states is None
            or switch_states != self.previous_switch_states
        )
        heartbeat_due = (now - self.last_heartbeat_time) >= HEARTBEAT_INTERVAL_SECS

        if not (state_changed or heartbeat_due):
            return

        try:
            actual_led_states = self.panel.get_led_states()
            expected_leds = [1 if i in led_indices else 0 for i in range(4)]
            actual_leds = [1 if s else 0 for s in actual_led_states]
            mismatch = expected_leds != actual_leds
            needs_help = mismatch or (rule_id != "all_lights_on")

            payload = {
                "switches": [1 if s else 0 for s in switch_states],
                "expected_leds": expected_leds,
                "actual_leds": actual_leds,
                "active_rule": rule_id,
                "mismatch": mismatch,
                "needs_help": needs_help,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "deviceId": self.iot_hub_device_id,
                "source": "iot-hub",
                "message_type": "change" if state_changed else "heartbeat",
                "timestamps": {
                    "pi_generated": datetime.now(timezone.utc).isoformat()
                },
            }

            self.iot_hub_client.send_message(payload)

            if state_changed:
                logger.info("State change → telemetry sent (rule: %s)", rule_id)
            else:
                logger.debug("Heartbeat sent (rule: %s)", rule_id)

            self.previous_switch_states = switch_states.copy()
            self.last_heartbeat_time = now

        except Exception as e:
            logger.error("Failed to send telemetry: %s", e)

    # ─── Shutdown ─────────────────────────────────────────────────────────────

    def stop_monitoring(self):
        self.running = False
        if self.api_server:
            self.api_server.stop()
            self.api_server = None
        if self.iot_hub_client:
            self.iot_hub_client.disconnect()
            self.iot_hub_client = None
        self.panel.cleanup()
        logger.info("Monitoring stopped, GPIO cleaned up")


def main():
    logger.info("=" * 60)
    logger.info("AgenticIoT IoT Monitor")
    logger.info("=" * 60)
    monitor = SimpleMonitor()
    try:
        monitor.start_monitoring()
    except Exception as e:
        logger.error("Fatal error: %s", e, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
