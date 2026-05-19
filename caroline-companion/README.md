# Caroline Companion

Small retro messenger-style desktop companion for Project Caroline.

This app is intentionally simple: one chat window, saved bot profiles for Caroline/Carl/Catoline, and a small helper that talks to the Node-RED WebSocket flow.

## Scripts

```bash
npm run dev
npm run tauri:dev
npm run build
```

`npm run dev` starts the Vite frontend only.

`npm run tauri:dev` starts the Tauri desktop app. This requires Rust/Cargo and the Tauri desktop prerequisites to be installed on your machine.

## Backend Hook

The default Pi profile is:

```text
ws://192.168.1.50:8080/ws/caroline
```

The default Steam Deck profile uses an SSH tunnel because SteamOS Caroline binds to localhost:

```bash
ssh -L 8088:127.0.0.1:8080 deck@STEAM_DECK_IP
```

Then Carl connects through:

```text
ws://127.0.0.1:8088/ws/caroline
```

Change any profile in the app UI.

Port 8080 is the Caroline kiosk/nginx proxy. Port 1880 is Node-RED direct and is commonly blocked by the host firewall, so the companion should always connect through 8080.

In Node-RED, expose a WebSocket endpoint at `/ws/caroline` through the kiosk proxy, parse messages with a `message` field, send them through Caroline's existing chat handler, and send the reply back over the socket.

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

Discovered hosts can be saved as separate profiles. Each saved host keeps its own WebSocket URL and pairing code so the desktop companion can switch between multiple Caroline hosts without retyping setup details.

This is a first-pass desktop-friendly scan. The more polished future version should advertise Caroline hosts with mDNS, SSDP, or a small UDP beacon from the Caroline host, then have the Tauri backend listen for those announcements.
