/**
 * AgenticIoT — IoT SignalR Function App
 *
 * Primary pipeline (push — added in feat/eventhub-direct-trigger, issue #101):
 *   IoT Hub → built-in Event Hub endpoint → iotTelemetry (EH trigger) → SignalR → Browser
 *
 * Secondary / test pipeline (kept for manual testing and backward compat):
 *   POST /api/telemetry → SignalR → Browser
 *
 * Endpoints:
 *   GET  /api/negotiate    — SignalR connection info (function auth)
 *   POST /api/telemetry    — Manual/test telemetry ingestion (function auth)
 *   GET  /api/test-signalr — Manual broadcast smoke test (anonymous)
 *   GET  /api/health       — Health check (anonymous)
 */

'use strict';

const { app, input, output } = require('@azure/functions');
const crypto = require('crypto');

// ─── SignalR bindings ──────────────────────────────────────────────────────────

const signalRConnectionInfo = input.generic({
    type: 'signalRConnectionInfo',
    name: 'connectionInfo',
    hubName: 'default',
    connectionStringSetting: 'AzureSignalRConnectionString'
});

const signalROutput = output.generic({
    type: 'signalR',
    name: 'signalRMessages',
    hubName: 'default',
    connectionStringSetting: 'AzureSignalRConnectionString'
});

// ─── Shared broadcast helper ──────────────────────────────────────────────────

/**
 * Derives SignalR messages from a parsed IoT telemetry payload and writes them
 * to the SignalR output binding.  Called by both the Event Hub trigger and the
 * HTTP /api/telemetry endpoint so the logic stays in one place.
 *
 * @param {object} messageData  Parsed JSON telemetry payload from the Pi
 * @param {object} context      Azure Functions invocation context
 */
function broadcastTelemetry(messageData, context) {
    const deviceId = messageData.deviceId || messageData.device_id || 'raspberry-pi-iotpanel';

    // Derive needs_help if Pi didn't send it (older firmware)
    let needs_help = messageData.needs_help;
    if (needs_help === undefined || needs_help === null) {
        const mismatch   = messageData.mismatch === true;
        const notHealthy = messageData.active_rule !== 'all_lights_on';
        needs_help = mismatch || notHealthy;
        context.log(`needs_help derived: ${needs_help} (mismatch=${mismatch}, rule=${messageData.active_rule})`);
    }

    const messages = [
        {
            target: 'SendTelemetryUpdate',
            arguments: [{
                deviceId,
                timestamp: messageData.timestamp || new Date().toISOString(),
                data: messageData,
                source: 'iot-hub',
            }],
        },
    ];

    if (needs_help === true) {
        context.log(`Help needed for ${deviceId} — sending TriggerAgentHelp`);
        messages.push({
            target: 'TriggerAgentHelp',
            arguments: [{
                deviceId,
                timestamp:      messageData.timestamp || new Date().toISOString(),
                active_rule:    messageData.active_rule,
                switches:       messageData.switches,
                expected_leds:  messageData.expected_leds,
                actual_leds:    messageData.actual_leds,
                mismatch:       messageData.mismatch,
            }],
        });
    }

    context.extraOutputs.set(signalROutput, messages);
    context.log(`Broadcast ${messages.length} SignalR message(s) for device: ${deviceId}`);
    return { deviceId, messageCount: messages.length };
}

// ─── iotTelemetry — Event Hub trigger (primary path) ─────────────────────────
//
// Reads directly from IoT Hub's built-in Event Hub-compatible endpoint.
// Connection string is stored in app setting: IoTHubEventHubConnectionString
//   Format: Endpoint=sb://<iothub>.servicebus.windows.net/;SharedAccessKeyName=iothubowner;SharedAccessKey=<key>;EntityPath=<iothub-name>
//
// This replaces the Logic App polling approach and fires within milliseconds
// of the Pi sending a message rather than up to 5 seconds later.

app.eventHub('iotTelemetry', {
    connection:    'IoTHubEventHubConnectionString',
    eventHubName:  process.env.IoTHubName || 'iothub-aw-iot-copilot',
    cardinality:   'many',     // batch of events per invocation
    consumerGroup: '$Default',
    extraOutputs:  [signalROutput],
    handler: async (events, context) => {
        if (!Array.isArray(events) || events.length === 0) return;

        context.log(`Event Hub trigger fired — ${events.length} event(s)`);

        for (const event of events) {
            let messageData;
            try {
                messageData = typeof event === 'string' ? JSON.parse(event) : event;
            } catch (e) {
                context.log.error('Failed to parse EH event body:', e.message);
                continue;
            }

            context.log(`EH payload preview: ${JSON.stringify(messageData).substring(0, 200)}`);
            broadcastTelemetry(messageData, context);
        }
    },
});

// ─── negotiate ────────────────────────────────────────────────────────────────

app.http('negotiate', {
    methods: ['GET', 'POST', 'OPTIONS'],
    authLevel: 'function',
    extraInputs: [signalRConnectionInfo],
    handler: async (request, context) => {
        if (request.method === 'OPTIONS') {
            return {
                status: 200,
                headers: corsHeaders()
            };
        }

        context.log('SignalR negotiate request');
        const connectionInfo = context.extraInputs.get('connectionInfo');

        return {
            status: 200,
            headers: { 'Content-Type': 'application/json', ...corsHeaders() },
            body: JSON.stringify(connectionInfo)
        };
    }
});

// ─── telemetry — HTTP endpoint (secondary / test path) ───────────────────────
//
// Previously the primary path called by the Logic App.
// Now retained for manual testing and backward compatibility.
// Primary ingestion is handled by the iotTelemetry Event Hub trigger above.

app.http('telemetry', {
    methods: ['POST'],
    authLevel: 'function',
    extraOutputs: [signalROutput],
    handler: async (request, context) => {
        context.log('Telemetry received via HTTP /api/telemetry (secondary path)');

        let messageData;
        try {
            messageData = await request.json();
        } catch (e) {
            context.log.error('Failed to parse request body:', e.message);
            return { status: 400, body: JSON.stringify({ error: 'Invalid JSON body' }) };
        }

        context.log(`Payload preview: ${JSON.stringify(messageData).substring(0, 200)}`);

        const { deviceId, messageCount } = broadcastTelemetry(messageData, context);

        return {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ success: true, deviceId, messageCount }),
        };
    },
});

// ─── test-signalr ─────────────────────────────────────────────────────────────

app.http('test-signalr', {
    methods: ['GET'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        context.log('Test SignalR endpoint called');

        const connStr = process.env.AzureSignalRConnectionString || '';
        const endpointMatch = connStr.match(/Endpoint=([^;]+)/);
        const keyMatch = connStr.match(/AccessKey=([^;]+)/);

        if (!endpointMatch || !keyMatch) {
            return {
                status: 500,
                body: JSON.stringify({ error: 'AzureSignalRConnectionString not configured' })
            };
        }

        const endpoint = endpointMatch[1];
        const accessKey = keyMatch[1];
        const hubName = 'default';
        const url = `${endpoint}/api/v1/hubs/${hubName}`;
        const audience = url;

        const now = Math.floor(Date.now() / 1000);
        const headerB64 = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
        const payloadB64 = Buffer.from(JSON.stringify({ aud: audience, exp: now + 3600 })).toString('base64url');
        const sig = crypto.createHmac('sha256', accessKey)
            .update(`${headerB64}.${payloadB64}`)
            .digest('base64url');
        const token = `${headerB64}.${payloadB64}.${sig}`;

        const testPayload = {
            target: 'SendTelemetryUpdate',
            arguments: [{
                deviceId: 'test-device',
                timestamp: new Date().toISOString(),
                data: { switches: [1, 0, 1, 0], actual_leds: [1, 0, 1, 0], active_rule: 'test', mismatch: false },
                source: 'test-endpoint'
            }]
        };

        try {
            const fetch = require('node-fetch');
            const res = await fetch(url, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
                body: JSON.stringify(testPayload)
            });

            return {
                status: 200,
                headers: { 'Content-Type': 'application/json', ...corsHeaders() },
                body: JSON.stringify({ status: res.ok ? 'ok' : 'failed', signalrStatus: res.status, timestamp: new Date().toISOString() })
            };
        } catch (err) {
            context.log.error('SignalR REST error:', err.message);
            return { status: 500, body: JSON.stringify({ error: err.message }) };
        }
    }
});

// ─── health ───────────────────────────────────────────────────────────────────

app.http('health', {
    methods: ['GET'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        return {
            status: 200,
            headers: { 'Content-Type': 'application/json', ...corsHeaders() },
            body: JSON.stringify({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                service: 'iot-signalr-func'
            })
        };
    }
});

// ─── helpers ──────────────────────────────────────────────────────────────────

function corsHeaders() {
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    };
}
