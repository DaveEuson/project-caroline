import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import {
  createCarolineSocket,
  type CarolineSocketStatus,
} from "./lib/carolineSocket";
import { discoverCarolineHosts, type DiscoveredHost } from "./lib/hostDiscovery";
import { loadSettings, saveSettings, type AppSettings } from "./lib/settings";

type ChatMessage = {
  id: number;
  from: "you" | "caroline" | "system";
  text: string;
};

const initialMessages: ChatMessage[] = [
  {
    id: 1,
    from: "caroline",
    text: "Hey! Open Settings (⚙) to connect me to your Caroline backend.",
  },
  {
    id: 2,
    from: "system",
    text: "Enter the WebSocket URL and, if required, the pairing code shown on the kiosk screen.",
  },
];

function getOrCreateClientId() {
  const storageKey = "caroline-companion-client-id";
  const existing = localStorage.getItem(storageKey);
  if (existing) return existing;
  const created = crypto.randomUUID ? crypto.randomUUID() : `companion-${Date.now()}`;
  localStorage.setItem(storageKey, created);
  return created;
}

function statusLabel(status: CarolineSocketStatus) {
  if (status === "online") return "Caroline is online";
  if (status === "connecting") return "Connecting...";
  if (status === "rejected") return "Pairing code rejected";
  return "Caroline is offline";
}

export default function App() {
  const [settings, setSettingsRaw] = useState<AppSettings>(loadSettings);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [activeSocketUrl, setActiveSocketUrl] = useState(() => loadSettings().socketUrl);
  const [status, setStatus] = useState<CarolineSocketStatus>("offline");
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);
  const [draft, setDraft] = useState("");
  const [discoveredHosts, setDiscoveredHosts] = useState<DiscoveredHost[]>([]);
  const [isDiscovering, setIsDiscovering] = useState(false);

  const [clientId] = useState(getOrCreateClientId);

  // Mutable ref so socket always reads latest name/code without being recreated
  const clientRef = useRef({
    clientId,
    displayName: settings.companionName,
    pairingCode: settings.pairingCode,
  });

  const socketRef = useRef<ReturnType<typeof createCarolineSocket> | null>(null);
  const transcriptRef = useRef<HTMLDivElement | null>(null);

  // Apply dark mode to <html> element whenever the setting changes
  useEffect(() => {
    document.documentElement.dataset.theme = settings.darkMode ? "dark" : "light";
  }, [settings.darkMode]);

  // Keep clientRef current with latest settings (no socket reconnect needed)
  useEffect(() => {
    clientRef.current = {
      clientId,
      displayName: settings.companionName,
      pairingCode: settings.pairingCode,
    };
  }, [clientId, settings.companionName, settings.pairingCode]);

  function setSettings(next: AppSettings) {
    setSettingsRaw(next);
    saveSettings(next);
  }

  // Only recreates (and reconnects) when the active URL changes
  const socket = useMemo(
    () =>
      createCarolineSocket({
        url: activeSocketUrl,
        getClient: () => clientRef.current,
        onStatusChange: setStatus,
        onMessage: (msg) => {
          if (msg.type === "pairing_rejected") {
            setMessages((m) => [
              ...m,
              {
                id: Date.now(),
                from: "system",
                text: "Pairing code was rejected. Check the code on the kiosk screen and try again in Settings.",
              },
            ]);
            return;
          }
          setMessages((m) => [
            ...m,
            { id: Date.now(), from: "caroline", text: msg.text },
          ]);
        },
      }),
    [activeSocketUrl]
  );

  useEffect(() => {
    socketRef.current = socket;
    socket.connect();
    return () => socket.disconnect();
  }, [socket]);

  // Auto-scroll transcript on new messages
  useEffect(() => {
    transcriptRef.current?.scrollTo({
      top: transcriptRef.current.scrollHeight,
      behavior: "smooth",
    });
  }, [messages]);

  function handleConnect() {
    const url = settings.socketUrl.trim();
    if (url && url !== activeSocketUrl) {
      setActiveSocketUrl(url);
    } else {
      socketRef.current?.connect();
    }
  }

  async function handleDiscoverHosts() {
    setIsDiscovering(true);
    setDiscoveredHosts([]);
    try {
      const hosts = await discoverCarolineHosts(settings.socketUrl);
      setDiscoveredHosts(hosts);
      setMessages((m) => [
        ...m,
        {
          id: Date.now(),
          from: "system",
          text: hosts.length
            ? `Found ${hosts.length} possible Caroline host${hosts.length === 1 ? "" : "s"} on the network.`
            : "No Caroline hosts found. Type the URL manually in Settings.",
        },
      ]);
    } finally {
      setIsDiscovering(false);
    }
  }

  function handleUseDiscoveredHost(host: DiscoveredHost) {
    setSettings({ ...settings, socketUrl: host.url });
    setActiveSocketUrl(host.url);
    setDiscoveredHosts([]);
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = draft.trim();
    if (!text) return;

    setMessages((m) => [...m, { id: Date.now(), from: "you", text }]);
    setDraft("");

    if (!socketRef.current?.send(text)) {
      setMessages((m) => [
        ...m,
        {
          id: Date.now() + 1,
          from: "system",
          text: "Caroline is offline. Open Settings to connect first.",
        },
      ]);
    }
  }

  const isOnline = status === "online";

  return (
    <main className="desktop">
      <section className="messenger-window" aria-label="Caroline companion chat">

        {/* ── Title bar ─────────────────────────────────────── */}
        <header className="title-bar">
          <div className="title-left">
            <span className="window-dot" />
            <strong>Caroline</strong>
          </div>
          <div className="title-right">
            <span className="title-version">Companion 0.1b</span>
            <button
              type="button"
              className={`settings-btn${settingsOpen ? " active" : ""}`}
              onClick={() => setSettingsOpen((o) => !o)}
              aria-label={settingsOpen ? "Close settings" : "Open settings"}
              title="Settings"
            >
              ⚙
            </button>
          </div>
        </header>

        {/* ── Status row ────────────────────────────────────── */}
        <div className="status-row">
          <span className={`status-light ${status}`} />
          <span>{statusLabel(status)}</span>
        </div>

        {/* ── Settings panel (shown when settingsOpen) ──────── */}
        {settingsOpen && (
          <section className="settings-panel" aria-label="Settings">

            <div className="settings-group">
              <label htmlFor="socket-url">WebSocket URL</label>
              <div className="settings-row">
                <input
                  id="socket-url"
                  className="mono"
                  value={settings.socketUrl}
                  onChange={(e) => setSettings({ ...settings, socketUrl: e.target.value })}
                  spellCheck={false}
                />
                <button type="button" onClick={handleConnect}>
                  Connect
                </button>
              </div>
            </div>

            <div className="settings-group">
              <label htmlFor="companion-name">Your Name</label>
              <input
                id="companion-name"
                value={settings.companionName}
                onChange={(e) => setSettings({ ...settings, companionName: e.target.value })}
              />
            </div>

            {/* Pairing code — host kiosk displays a code; client enters it here */}
            <div className="settings-group">
              <label htmlFor="pairing-code">
                Pairing Code{" "}
                <span
                  className="help-tip"
                  title="Enter the code shown on the Caroline kiosk screen. Leave blank if the host does not require one."
                >
                  ?
                </span>
              </label>
              <input
                id="pairing-code"
                value={settings.pairingCode}
                onChange={(e) => setSettings({ ...settings, pairingCode: e.target.value })}
                placeholder="Code from kiosk screen"
                maxLength={16}
              />
            </div>

            <div className="settings-group settings-toggle-row">
              <label htmlFor="dark-mode">Dark Mode</label>
              <input
                id="dark-mode"
                type="checkbox"
                checked={settings.darkMode}
                onChange={(e) => setSettings({ ...settings, darkMode: e.target.checked })}
              />
            </div>

            <div className="settings-group">
              <button
                type="button"
                className="full-width-btn"
                onClick={handleDiscoverHosts}
                disabled={isDiscovering}
              >
                {isDiscovering ? "Searching network..." : "Find Caroline Hosts on Network"}
              </button>
              {discoveredHosts.length > 0 && (
                <div className="discovered-hosts">
                  {discoveredHosts.map((h) => (
                    <button
                      type="button"
                      key={h.url}
                      onClick={() => handleUseDiscoveredHost(h)}
                    >
                      {h.label}
                    </button>
                  ))}
                </div>
              )}
            </div>

            <p className="settings-note">
              Node-RED: handle <code>client_hello</code> → validate <code>pairingCode</code> →
              reply <code>{"{ type: \"pairing_rejected\" }"}</code> if wrong, else store client.
            </p>
          </section>
        )}

        {/* ── Chat area ─────────────────────────────────────── */}
        <section className="chat-shell">
          <aside className="buddy-list" aria-label="Buddy list">
            <div className="buddy-heading">Buddies</div>
            <div className={`buddy${isOnline ? " active" : ""}`}>
              <img
                src="/caroline.gif"
                alt="Caroline"
                className="buddy-avatar"
                width={32}
                height={32}
              />
              <div>
                <strong>Caroline</strong>
                <small>{isOnline ? "available" : "offline"}</small>
              </div>
            </div>
          </aside>

          <div className="chat-panel">
            <div className="transcript" ref={transcriptRef}>
              {messages.map((msg) => (
                <article className={`message ${msg.from}`} key={msg.id}>
                  <span>
                    {msg.from === "you"
                      ? settings.companionName || "You"
                      : msg.from === "caroline"
                      ? "Caroline"
                      : "System"}
                  </span>
                  <p>{msg.text}</p>
                </article>
              ))}
            </div>

            <form className="compose" onSubmit={handleSubmit}>
              <input
                aria-label="Message Caroline"
                placeholder={isOnline ? "Type a message..." : "Caroline is offline..."}
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
              />
              <button type="submit">Send</button>
            </form>
          </div>
        </section>

      </section>
    </main>
  );
}
