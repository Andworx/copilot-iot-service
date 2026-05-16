#!/usr/bin/env python3
"""
AgenticIoT — Azure IoT Hub Client
Sends telemetry messages from the Pi to Azure IoT Hub over MQTT/TLS.

Connection string is read from the environment variable specified in
logic_map.json (iot_hub.connection_string_env) — never hard-coded.
"""

import logging
import json
from azure.iot.device import IoTHubDeviceClient, Message

logger = logging.getLogger("IoTMonitor.IoTClient")


class IoTHubClient:
    """Thin wrapper around the Azure IoT Device SDK client."""

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
