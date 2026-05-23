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
    id: 'switch',
    label: 'Switch',
    sublabel: 'GPIO Input',
    cx: 185,
    cy: 88,
    tier: 'edge',
    accentColor: '#22C55E',
    description:
      'Physical push-button switches wired directly to Raspberry Pi GPIO header pins. When pressed, they generate a digital HIGH/LOW signal read by the Pi\'s GPIO library.',
    role: 'GPIO input device — generates user-triggered control signals that the Raspberry Pi detects and acts on (e.g., toggle LED, transmit a command to Azure IoT Hub).',
    protocol: 'GPIO (digital input)',
    connectedTo: ['pi'],
  },
  {
    id: 'led',
    label: 'LED',
    sublabel: 'GPIO Output',
    cx: 185,
    cy: 152,
    tier: 'edge',
    accentColor: '#22C55E',
    description:
      'Physical LED wired to a Raspberry Pi GPIO output pin via a current-limiting resistor. The Pi sets the pin HIGH or LOW to turn the LED on or off in response to local button presses or cloud commands.',
    role: 'GPIO output device — provides physical visual feedback of device state. Controlled by the Raspberry Pi in response to local switch presses or commands received from the cloud via IoT Hub.',
    protocol: 'GPIO (digital output)',
    connectedTo: ['pi'],
  },
  {
    id: 'pi',
    label: 'Raspberry Pi',
    sublabel: 'Edge IoT Device',
    cx: 590,
    cy: 120,
    tier: 'edge',
    accentColor: '#22C55E',
    description:
      'The Raspberry Pi is the edge compute device. It polls GPIO switch inputs, drives the LED output, runs the IoT agent process, and relays device state changes to Azure IoT Hub over the internet.',
    role: 'Edge compute — reads GPIO inputs (switch), controls GPIO outputs (LED), runs the IoT agent, and publishes device events to Azure IoT Hub over MQTT.',
    protocol: 'MQTT / Azure IoT SDK (Python)',
    connectedTo: ['switch', 'led', 'iothub'],
  },
  {
    id: 'iothub',
    label: 'Azure IoT Hub',
    sublabel: 'Cloud Messaging',
    cx: 225,
    cy: 270,
    tier: 'cloud',
    accentColor: '#F59E0B',
    description:
      'Azure IoT Hub is the cloud-side MQTT/AMQP message broker. It authenticates the Pi device, receives device event messages, and routes them downstream via its built-in Event Hub endpoint.',
    role: 'Ingests device events, manages device twins and connection state, and fans out messages to Azure Functions via an Event Hub-compatible trigger.',
    protocol: 'MQTT 3.1.1 / AMQP 1.0 / HTTPS',
    connectedTo: ['pi', 'functions'],
  },
  {
    id: 'functions',
    label: 'Azure Functions',
    sublabel: 'Event Processing',
    cx: 510,
    cy: 270,
    tier: 'cloud',
    accentColor: '#F59E0B',
    description:
      'Azure Functions provides serverless event processing. Triggered by IoT Hub messages, each function transforms raw device events, writes records to Dataverse, pushes real-time state updates to browser clients via SignalR, and fires downstream Power Automate flows.',
    role: 'Processes raw device events, applies business logic, writes structured records to Dataverse, pushes live status to Power Pages via Azure SignalR, and triggers Power Automate flows via HTTP.',
    protocol: 'Event Hub Trigger / Dataverse REST API / SignalR / HTTP',
    connectedTo: ['iothub', 'dataverse', 'signalr', 'flows'],
  },
  {
    id: 'signalr',
    label: 'Azure SignalR',
    sublabel: 'Real-time Push',
    cx: 760,
    cy: 270,
    tier: 'cloud',
    accentColor: '#F59E0B',
    description:
      'Azure SignalR Service maintains persistent WebSocket connections between the Azure Functions backend and browser clients running the Power Pages portal. When a switch state changes on the Pi, the event flows Pi → IoT Hub → Functions → SignalR → browser in real time.',
    role: 'Real-time messaging hub — receives push notifications from Azure Functions and broadcasts live device state changes to all connected Power Pages browser sessions over WebSocket. Eliminates polling; browsers react instantly to hardware events.',
    protocol: 'WebSocket / SignalR Hub Protocol',
    connectedTo: ['functions', 'pages'],
  },
  {
    id: 'dataverse',
    label: 'Dataverse',
    sublabel: 'Persistent Storage',
    cx: 110,
    cy: 440,
    tier: 'platform',
    accentColor: '#3B82F6',
    description:
      'Microsoft Dataverse is the Power Platform data store. It holds all processed device events, state history, and configuration data — serving as the single source of truth for the portal and AI agent.',
    role: 'Stores processed device events, state history, and configuration. Serves data to Power Pages via the Web API and to Copilot Studio via the built-in Dataverse connector.',
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
      'This Power Pages portal is the web front-end for the IoT system. Built as a code-first React SPA, it receives live device state pushes from Azure SignalR (WebSocket), queries historical data from Dataverse, and hosts the embedded Copilot Studio agent.',
    role: 'Presents real-time and historical device state to end users. Receives live hardware state via Azure SignalR (WebSocket) so the Status page updates the moment a switch is pressed or LED toggled. Historical data comes from Dataverse. Hosts the Copilot Studio conversational agent.',
    protocol: 'Azure SignalR (WebSocket) / Dataverse Web API',
    connectedTo: ['signalr', 'dataverse', 'copilot'],
  },
  {
    id: 'copilot',
    label: 'Copilot Studio',
    sublabel: 'AI Agent',
    cx: 548,
    cy: 440,
    tier: 'platform',
    accentColor: '#3B82F6',
    description:
      'The Copilot Studio agent provides a natural-language conversational interface for the IoT system. Users can ask questions about device state, history, and recent events — and trigger actions via Power Automate.',
    role: 'AI agent — understands user queries about device state, retrieves Dataverse records, triggers Power Automate actions, and escalates to human support when needed.',
    protocol: 'Direct Line API / Copilot Studio SDK',
    connectedTo: ['pages', 'dataverse'],
  },
  {
    id: 'flows',
    label: 'Power Automate',
    sublabel: 'Automation Layer',
    cx: 775,
    cy: 440,
    tier: 'platform',
    accentColor: '#3B82F6',
    description:
      'Power Automate flows handle alert and automation logic triggered by Azure Functions or the Copilot Studio agent — such as sending Teams or email notifications when device state changes exceed thresholds.',
    role: 'Automation — reacts to device events, sends notifications (email/Teams), updates Dataverse records, and orchestrates multi-step approval processes.',
    protocol: 'HTTP Trigger / Dataverse Connector / Teams Connector',
    connectedTo: ['functions', 'dataverse'],
  },
];

export const CONNECTIONS: ConnectionDef[] = [
  { from: 'switch',    to: 'pi',        label: 'GPIO'      },
  { from: 'pi',        to: 'led',       label: 'GPIO'      },
  { from: 'pi',        to: 'iothub',    label: 'MQTT'      },
  { from: 'iothub',    to: 'functions', label: 'Event Hub' },
  { from: 'functions', to: 'signalr',   label: 'Push'      },
  { from: 'signalr',   to: 'pages',     label: 'WebSocket' },
  { from: 'functions', to: 'dataverse', label: 'REST'      },
  { from: 'functions', to: 'flows',     label: 'HTTP'      },
  { from: 'dataverse', to: 'pages',     label: 'OData'     },
  { from: 'pages',     to: 'copilot',   label: 'DirectLine'},
];
