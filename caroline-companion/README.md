# Caroline Companion

Small retro messenger-style desktop companion for Project Caroline.

This app is intentionally simple: one chat window, a configurable WebSocket URL, and a small helper that can talk to a future Node-RED WebSocket flow.

## Scripts

```bash
npm run dev
npm run tauri:dev
npm run build
```

`npm run dev` starts the Vite frontend only.

`npm run tauri:dev` starts the Tauri desktop app. This requires Rust/Cargo and the Tauri desktop prerequisites to be installed on your machine.

## Backend Hook

The default WebSocket URL is:

```text
ws://192.168.1.50:1880/ws/caroline
```

Change it in the app UI or in `src/lib/carolineSocket.ts`.

In Node-RED, create a WebSocket endpoint at `/ws/caroline`, parse messages with a `message` field, send them through Caroline's existing chat handler, and send the reply back over the socket.

## Host Visibility

When the companion connects, it sends:

```json
{
  "type": "client_hello",
  "source": "caroline-companion",
  "clientId": "saved-device-id",
  "clientName": "Dave's Companion",
  "appVersion": "0.1.0"
}
```

Every 30 seconds it sends:

```json
{
  "type": "client_heartbeat",
  "source": "caroline-companion",
  "clientId": "saved-device-id",
  "clientName": "Dave's Companion"
}
```

In Node-RED, store those messages in flow/global context. That is the simple starting point for showing connected companion clients on the Caroline host.

## Host Discovery

The **Find Hosts** button probes likely local WebSocket URLs, including the default `192.168.1.x` network and common home LAN ranges.

This is a first-pass desktop-friendly scan. The more polished future version should advertise Caroline hosts with mDNS, SSDP, or a small UDP beacon from the Caroline host, then have the Tauri backend listen for those announcements.
