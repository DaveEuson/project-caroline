// Port 8080 = nginx proxy (externally accessible). Port 1880 = Node-RED direct (firewall-blocked).
export const DEFAULT_CAROLINE_SOCKET_URL = "ws://192.168.1.50:8080/ws/caroline";

export type CarolineSocketStatus = "connecting" | "online" | "offline" | "rejected";

export type CarolineSocketMessage = {
  text: string;
  type?: string;
  raw: unknown;
};

export type CompanionClientInfo = {
  clientId: string;
  displayName: string;
  pairingCode?: string;
};

type CarolineSocketOptions = {
  url?: string;
  // Getter so the socket always reads current settings without being recreated on name/code changes
  getClient: () => CompanionClientInfo;
  onStatusChange?: (status: CarolineSocketStatus) => void;
  onMessage?: (message: CarolineSocketMessage) => void;
};

function summarizeTask(task: unknown, index: number) {
  if (!task || typeof task !== "object") return `Task ${index + 1}`;

  const record = task as Record<string, unknown>;
  const text =
    (typeof record.title === "string" ? record.title : null) ??
    (typeof record.text === "string" ? record.text : null) ??
    (typeof record.task === "string" ? record.task : null) ??
    (typeof record.content === "string" ? record.content : null);

  return text?.trim() || `Task ${index + 1}`;
}

function summarizeTodoUpdate(record: Record<string, unknown>) {
  const tasks = Array.isArray(record.tasks) ? record.tasks : [];
  if (!tasks.length) return "📋 Task list updated.";

  const preview = tasks.slice(0, 3).map(summarizeTask).join(", ");
  const remaining = tasks.length > 3 ? `, and ${tasks.length - 3} more` : "";
  return `📋 Task list updated: ${preview}${remaining}`;
}

function summarizeCalendarUpdate(record: Record<string, unknown>) {
  const event = record.event && typeof record.event === "object"
    ? record.event as Record<string, unknown>
    : null;

  if (!event) return "Calendar updated.";

  const title =
    (typeof event.title === "string" ? event.title : null) ??
    (typeof event.summary === "string" ? event.summary : null) ??
    "calendar event";
  const date = typeof event.date === "string" ? event.date : "";
  const start = typeof event.start === "string" ? event.start : "";
  const when = [date, start].filter(Boolean).join(" at ");

  return when ? `Calendar updated: ${title} (${when})` : `Calendar updated: ${title}`;
}

function parseIncomingMessage(data: unknown): CarolineSocketMessage | null {
  if (typeof data !== "string") {
    return { text: String(data ?? ""), raw: data };
  }

  try {
    const parsed = JSON.parse(data) as unknown;

    if (parsed && typeof parsed === "object") {
      const record = parsed as Record<string, unknown>;

      const msgType = typeof record.type === "string" ? record.type : undefined;

      if (msgType === "system_stats" || msgType === "client_heartbeat") {
        return null;
      }

      if (msgType === "host_hello") {
        const hostName =
          (typeof record.aiName === "string" ? record.aiName : null) ??
          (typeof record.name === "string" ? record.name : null) ??
          "Caroline";

        return { text: hostName, type: msgType, raw: parsed };
      }

      if (msgType === "todo_update") {
        return { text: summarizeTodoUpdate(record), type: msgType, raw: parsed };
      }

      if (msgType === "calendar_update") {
        return { text: summarizeCalendarUpdate(record), type: msgType, raw: parsed };
      }

      if (msgType?.startsWith("spotify_")) {
        const text =
          (typeof record.reply === "string" ? record.reply : null) ??
          (typeof record.message === "string" ? record.message : null) ??
          (typeof record.content === "string" ? record.content : null) ??
          (typeof record.text === "string" ? record.text : null) ??
          msgType.replace(/_/g, " ");

        return { text: `🎵 ${text}`, type: msgType, raw: parsed };
      }

      const text =
        (typeof record.reply === "string" ? record.reply : null) ??
        (typeof record.message === "string" ? record.message : null) ??
        (typeof record.content === "string" ? record.content : null) ??
        (typeof record.text === "string" ? record.text : null) ??
        data;

      return { text: String(text), type: msgType, raw: parsed };
    }

    return { text: String(parsed), raw: parsed };
  } catch {
    return { text: data, raw: data };
  }
}

export function createCarolineSocket(options: CarolineSocketOptions) {
  let socket: WebSocket | null = null;
  let heartbeatTimer: number | undefined;
  const url = options.url || DEFAULT_CAROLINE_SOCKET_URL;

  function setStatus(status: CarolineSocketStatus) {
    options.onStatusChange?.(status);
  }

  function connect() {
    disconnect();
    setStatus("connecting");

    try {
      socket = new WebSocket(url);
    } catch {
      setStatus("offline");
      return;
    }

    socket.onopen = () => {
      setStatus("online");
      announceClient();
      heartbeatTimer = window.setInterval(sendHeartbeat, 30_000);
    };
    socket.onclose = () => {
      clearHeartbeat();
      setStatus("offline");
    };
    socket.onerror = () => setStatus("offline");
    socket.onmessage = (event) => {
      const msg = parseIncomingMessage(event.data);
      if (!msg) return;

      // Node-RED host sends { type: "pairing_rejected", reason: "..." } for a wrong code.
      // Disconnect immediately so the user knows to fix the code in Settings.
      if (msg.type === "pairing_rejected") {
        clearHeartbeat();
        socket?.close();
        setStatus("rejected");
      }

      options.onMessage?.(msg);
    };
  }

  function send(text: string) {
    if (!socket || socket.readyState !== WebSocket.OPEN) return false;

    const client = options.getClient();
    // Node-RED hook: route this "chat" message into your LLM/AI flow and reply via the socket.
    socket.send(
      JSON.stringify({
        type: "chat",
        message: text,
        source: "caroline-companion",
        clientId: client.clientId,
        clientName: client.displayName,
      })
    );

    return true;
  }

  function announceClient() {
    if (!socket || socket.readyState !== WebSocket.OPEN) return;

    const client = options.getClient();
    // Node-RED host visibility: on receiving "client_hello", validate pairingCode and
    // store clientId/displayName in flow context so the kiosk can list connected companions.
    // If pairingCode is wrong, reply with { type: "pairing_rejected", reason: "Bad code" }.
    socket.send(
      JSON.stringify({
        type: "client_hello",
        source: "caroline-companion",
        clientId: client.clientId,
        clientName: client.displayName,
        pairingCode: client.pairingCode || undefined,
        appVersion: "0.1.0",
      })
    );
  }

  function sendHeartbeat() {
    if (!socket || socket.readyState !== WebSocket.OPEN) return;

    const client = options.getClient();
    // Node-RED: refresh the connected-clients list on each heartbeat (every 30s).
    socket.send(
      JSON.stringify({
        type: "client_heartbeat",
        source: "caroline-companion",
        clientId: client.clientId,
        clientName: client.displayName,
        sentAt: new Date().toISOString(),
      })
    );
  }

  function clearHeartbeat() {
    if (heartbeatTimer !== undefined) {
      window.clearInterval(heartbeatTimer);
      heartbeatTimer = undefined;
    }
  }

  function disconnect() {
    clearHeartbeat();
    if (socket) {
      socket.close();
      socket = null;
    }
  }

  return { connect, disconnect, send, get url() { return url; } };
}
