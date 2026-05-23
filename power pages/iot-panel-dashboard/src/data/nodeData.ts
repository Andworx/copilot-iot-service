export interface NodeDef {
  id: string;
  label: string;
  sublabel: string;
  cx: number;
  cy: number;
  tier: 'edge' | 'cloud' | 'platform';
  accentColor: string;
  description: string;
  role: string;
  protocol: string;
  connectedTo: string[];
}

export interface ConnectionDef {
  from: string;
  to: string;
  label: string;
}

export const NODE_DATA: NodeDef[] = [
  {
    id: 'sensors',
    label: 'Sensors',
    sublabel: 'Temp / Humidity / GPIO',
    cx: 165,
    cy: 110,
    tier: 'edge',
    accentColor: '#22C55E',
    description:
      'Physical sensors (DHT22 temperature/humidity, GPIO push-buttons) wired directly to the Raspberry Pi GPIO header pins.',
    role: 'Collect raw environmental data and physical state signals from the edge device.',
    protocol: 'GPIO (physical)',
    connectedTo: ['pi'],
  },
  {
    id: 'pi',
    label: 'Raspberry Pi',
    sublabel: 'Edge IoT Device',
    cx: 490,
    cy: 110,
    tier: 'edge',
    accentColor: '#22C55E',
    description:
      'The Raspberry Pi is the edge compute device. It reads sensor values over GPIO, manages LED outputs, runs the IoT agent process, and relays telemetry to Azure over the internet.',
    role: 'Edge compute — reads sensors, controls GPIO outputs (LEDs/switches), runs the IoT agent, and publishes telemetry to Azure IoT Hub over MQTT.',
    protocol: 'MQTT / Azure IoT SDK (Python)',
    connectedTo: ['sensors', 'iothub'],
  },
  {
    id: 'iothub',
    label: 'Azure IoT Hub',
    sublabel: 'Cloud Messaging',
    cx: 255,
    cy: 270,
    tier: 'cloud',
    accentColor: '#F59E0B',
    description:
      'Azure IoT Hub is the cloud-side MQTT/AMQP message broker. It authenticates the Pi device, receives telemetry messages, and routes them downstream via its built-in Event Hub endpoint.',
    role: 'Ingests device telemetry, manages device twins and connection state, and fans out messages to Azure Functions via an Event Hub-compatible trigger.',
    protocol: 'MQTT 3.1.1 / AMQP 1.0 / HTTPS',
    connectedTo: ['pi', 'functions'],
  },
  {
    id: 'functions',
    label: 'Azure Functions',
    sublabel: 'Event Processing',
    cx: 635,
    cy: 270,
    tier: 'cloud',
    accentColor: '#F59E0B',
    description:
      'Azure Functions provides serverless event processing. Triggered by IoT Hub messages, each function transforms raw telemetry, writes records to Dataverse, and fires downstream automation.',
    role: 'Processes raw telemetry events, applies business logic (thresholds, deduplication), writes structured records to Dataverse, and triggers Power Automate flows via HTTP.',
    protocol: 'Event Hub Trigger / Dataverse REST API / HTTP',
    connectedTo: ['iothub', 'dataverse', 'flows'],
  },
  {
    id: 'dataverse',
    label: 'Dataverse',
    sublabel: 'Persistent Storage',
    cx: 125,
    cy: 440,
    tier: 'platform',
    accentColor: '#3B82F6',
    description:
      'Microsoft Dataverse is the Power Platform data store. It holds all processed telemetry records, device state history, and configuration data — serving as the single source of truth for the portal and AI agent.',
    role: 'Stores processed telemetry, device state, and historical sensor data. Serves data to Power Pages via the Web API and to Copilot Studio via the built-in Dataverse connector.',
    protocol: 'Dataverse Web API (OData v4)',
    connectedTo: ['functions', 'pages'],
  },
  {
    id: 'pages',
    label: 'Power Pages',
    sublabel: 'Web Front-End',
    cx: 325,
    cy: 440,
    tier: 'platform',
    accentColor: '#3B82F6',
    description:
      'This Power Pages portal is the web front-end for the IoT system. Built as a code-first React SPA, it renders real-time telemetry from Dataverse, live GPIO state via SignalR, and hosts the embedded Copilot Studio agent.',
    role: 'Presents real-time and historical telemetry to end users. Provides the Status, History, Devices, and System Map tabs. Hosts the Copilot Studio conversational agent.',
    protocol: 'Power Pages Web API / SignalR (Azure)',
    connectedTo: ['dataverse', 'copilot'],
  },
  {
    id: 'copilot',
    label: 'Copilot Studio',
    sublabel: 'AI Agent',
    cx: 555,
    cy: 440,
    tier: 'platform',
    accentColor: '#3B82F6',
    description:
      'The Copilot Studio agent provides a natural-language conversational interface for the IoT system. Users can ask questions about sensor readings, device health, and recent events — and trigger actions via Power Automate.',
    role: 'AI agent — understands user queries about telemetry, retrieves Dataverse records, triggers Power Automate actions, and escalates to human support when needed.',
    protocol: 'Direct Line API / Copilot Studio SDK',
    connectedTo: ['pages', 'dataverse'],
  },
  {
    id: 'flows',
    label: 'Power Automate',
    sublabel: 'Automation Layer',
    cx: 785,
    cy: 440,
    tier: 'platform',
    accentColor: '#3B82F6',
    description:
      'Power Automate flows handle alert and automation logic triggered by Azure Functions or the Copilot Studio agent — such as sending email or Teams notifications when sensor thresholds are exceeded.',
    role: 'Automation — reacts to telemetry threshold events, sends notifications (email/Teams), updates Dataverse records, and orchestrates multi-step approval processes.',
    protocol: 'HTTP Trigger / Dataverse Connector / Teams Connector',
    connectedTo: ['functions', 'dataverse'],
  },
];

export const CONNECTIONS: ConnectionDef[] = [
  { from: 'sensors',   to: 'pi',        label: 'GPIO'       },
  { from: 'pi',        to: 'iothub',    label: 'MQTT'       },
  { from: 'iothub',    to: 'functions', label: 'Event Hub'  },
  { from: 'functions', to: 'dataverse', label: 'REST'       },
  { from: 'functions', to: 'flows',     label: 'HTTP'       },
  { from: 'dataverse', to: 'pages',     label: 'OData'      },
  { from: 'pages',     to: 'copilot',   label: 'DirectLine' },
];
