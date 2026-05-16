"""
AgenticIoT — Local API Server
Flask REST API that exposes the panel state for local network monitoring.
Enabled/disabled via logic_map.json web_ui.enabled flag.
Runs in a daemon thread alongside the main monitoring loop.
"""

import logging
import json
from datetime import datetime, timezone
from flask import Flask, jsonify
from flask_cors import CORS
from werkzeug.serving import make_server
import threading

logger = logging.getLogger(__name__)


class APIServer:
    """Flask server for local panel status monitoring."""

    def __init__(self, panel_controller, config: dict):
        """
        Args:
            panel_controller: PanelController instance (shared reference)
            config: web_ui section from logic_map.json
        """
        self.panel = panel_controller
        self.config = config
        self.app = Flask(__name__)
        CORS(self.app)

        self.server = None
        self.server_thread = None
        self.running = False

        self._register_routes()
        logger.info(
            "APIServer configured on %s:%s", config.get("host"), config.get("port")
        )

    # ─── Routes ───────────────────────────────────────────────────────────────

    def _register_routes(self):

        @self.app.route("/api/status", methods=["GET"])
        def get_status():
            try:
                switch_states = self.panel.poll_switches()
                led_indices, rule_id = self.panel.apply_logic_rules(switch_states)
                actual_led_states = self.panel.get_led_states()
                expected_leds = [1 if i in led_indices else 0 for i in range(4)]
                actual_leds = [1 if s else 0 for s in actual_led_states]
                mismatch = expected_leds != actual_leds

                return jsonify({
                    "switches": [1 if s else 0 for s in switch_states],
                    "expected_leds": expected_leds,
                    "actual_leds": actual_leds,
                    "active_rule": rule_id,
                    "mismatch": mismatch,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "source": "local-api",
                }), 200

            except Exception as e:
                logger.error("API error: %s", e, exc_info=True)
                return jsonify({"error": str(e)}), 500

        @self.app.route("/api/health", methods=["GET"])
        def health():
            return jsonify({"status": "ok", "service": "iot-monitor-api"}), 200

    # ─── Lifecycle ────────────────────────────────────────────────────────────

    def start(self):
        if self.running:
            logger.warning("API server already running")
            return

        host = self.config.get("host", "127.0.0.1")
        port = self.config.get("port", 8080)

        self.server = make_server(host, port, self.app, threaded=True)
        self.server_thread = threading.Thread(
            target=self.server.serve_forever, daemon=True
        )
        self.server_thread.start()
        self.running = True
        logger.info("API server started on http://%s:%s", host, port)

    def stop(self):
        if not self.running:
            return
        try:
            self.server.shutdown()
            self.server_thread.join(timeout=5)
            self.running = False
            logger.info("API server stopped")
        except Exception as e:
            logger.error("Error stopping API server: %s", e, exc_info=True)

    def is_running(self) -> bool:
        return self.running
