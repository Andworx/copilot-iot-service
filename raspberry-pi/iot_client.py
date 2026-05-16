#!/usr/bin/env python3
"""
AgenticIoT — Azure IoT Hub Client
Sends telemetry messages from the Pi to Azure IoT Hub over MQTT/TLS.
Supports Device Twin config sync: desired.logic_map is fetched on startup
and pushed live whenever the twin is updated in Azure.

Connection string is read from the environment variable specified in
logic_map.json (iot_hub.connection_string_env) — never hard-coded.
"""

import json
import logging
import os

from azure.iot.device import IoTHubDeviceClient, Message

logger = logging.getLogger("IoTMonitor.IoTClient")

SERVICE_VERSION = "1.1.0"


class IoTHubClient:
    """Azure IoT Hub client with Device Twin config sync support."""

    def __init__(self, connection_string: str, device_id: str):
        self.connection_string = connection_string
        self.device_id = device_id
        self.client = None
        logger.info("IoTHubClient created for device: %s", device_id)

    # ─── Connection ───────────────────────────────────────────────────────────

    def connect(self) -> bool:
        if not self.connection_string:
            logger.error("Cannot connect: connection string is empty")
            return False
        try:
            self.client = IoTHubDeviceClient.create_from_connection_string(
                self.connection_string
            )
            self.client.connect()
            logger.info("Connected to Azure IoT Hub")
            return True
        except Exception as e:
            logger.error("IoT Hub connect failed: %s", e)
            self.client = None
            return False

    def disconnect(self):
        if self.client:
            try:
                self.client.disconnect()
                logger.info("Disconnected from Azure IoT Hub")
            except Exception as e:
                logger.error("Error during disconnect: %s", e)
            finally:
                self.client = None

    # ─── Device Twin — config sync ────────────────────────────────────────────

    def sync_config_from_twin(self, config_file_path: str) -> bool:
        """Fetch Device Twin on startup; write desired.logic_map to config_file_path.

        Falls back gracefully — if the twin has no logic_map, the local file
        is left untouched and the method returns False.

        Returns True if a valid logic_map was found and written.
        """
        if not self.client:
            logger.warning("Cannot sync twin — not connected")
            return False
        try:
            twin = self.client.get_twin()
            desired = twin.get("desired", {})
            logic_map = desired.get("logic_map")

            if not logic_map:
                logger.info(
                    "Device Twin has no logic_map in desired properties — using local config"
                )
                return False

            self._write_config(logic_map, config_file_path)
            version = logic_map.get("version", 1)
            self._report_config_applied(version)
            logger.info("Config synced from Device Twin (version %s)", version)
            return True

        except Exception as e:
            logger.error("Failed to sync config from Device Twin: %s", e)
            return False

    def register_twin_patch_callback(
        self, config_file_path: str, on_config_updated=None
    ):
        """Register a handler for Device Twin desired property patches.

        When desired.logic_map changes in Azure, the new config is written to
        config_file_path and on_config_updated(logic_map) is called so the
        monitoring loop can reload without a restart.
        """
        if not self.client:
            logger.warning("Cannot register twin callback — not connected")
            return

        def _patch_handler(patch):
            logic_map = patch.get("logic_map")
            if not logic_map:
                logger.debug("Twin patch received (no logic_map change — ignoring)")
                return

            logger.info("Device Twin patch received — updating config")
            try:
                self._write_config(logic_map, config_file_path)
                version = logic_map.get("version", "?")
                self._report_config_applied(version)
            except Exception as e:
                logger.error("Error writing twin patch config: %s", e)
                return

            if on_config_updated:
                try:
                    on_config_updated(logic_map)
                except Exception as e:
                    logger.error("Error in on_config_updated callback: %s", e)

        self.client.on_twin_desired_properties_patch_received = _patch_handler
        logger.info("Device Twin patch callback registered")

    def _report_config_applied(self, version):
        """Report back to IoT Hub that config was applied (reported properties)."""
        if not self.client:
            return
        try:
            self.client.patch_twin_reported_properties(
                {
                    "logic_map_version": version,
                    "service_version": SERVICE_VERSION,
                    "config_source": "device_twin",
                }
            )
        except Exception as e:
            logger.warning("Could not update twin reported properties: %s", e)

    @staticmethod
    def _write_config(logic_map: dict, config_file_path: str):
        """Atomically write logic_map dict to JSON config file (via temp file)."""
        tmp_path = config_file_path + ".tmp"
        with open(tmp_path, "w") as f:
            json.dump(logic_map, f, indent=2)
        os.replace(tmp_path, config_file_path)
        logger.info("Config written to %s from Device Twin", config_file_path)

    # ─── Messaging ────────────────────────────────────────────────────────────

    def send_message(self, payload: dict) -> bool:
        """Serialise payload to JSON and send to IoT Hub."""
        if not self.client:
            logger.warning("Not connected — dropping message")
            return False
        try:
            msg = Message(json.dumps(payload))
            msg.content_type = "application/json"
            msg.content_encoding = "utf-8"
            self.client.send_message(msg)
            logger.debug("Message sent (rule: %s)", payload.get("active_rule", "?"))
            return True
        except Exception as e:
            logger.error("Failed to send message: %s", e)
            return False

    # ─── Context manager ──────────────────────────────────────────────────────

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, *_):
        self.disconnect()
