import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import {
  createCarolineSocket,
  type CarolineSocketStatus,
} from "./lib/carolineSocket";
import { discoverCarolineHosts, type DiscoveredHost } from "./lib/hostDiscovery";
import { loadSettings, saveSettings, type AppSettings, type SavedHost } from "./lib/settings";
import carolineAvatar from "../src-tauri/icons/64x64.png";

type ChatMessage = {
  id: number;
  from: "you" | "caroline" | "system";
  text: string;
};

const initialMessages: ChatMessage[] = [
  {
    id: 1,
    from: "caroline",
    text: "Hey! I am ready when your Project: Caroline host is.",
  },
  {
    id: 2,
    from: "system",
    text: "Use Settings to change the WebSocket URL or pairing code.",
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

function statusLabel(status: CarolineSocketStatus, aiName: string) {
  if (status === "online") return `${aiName} is online`;
  if (status === "connecting") return "Connecting...";
  if (status === "rejected") return "Pairing code rejected";
  return `${aiName} is offline`;
}

function hostNameFromUrl(url: string) {
  try {
    const parsed = new URL(url);
    return parsed.hostname ? `Project: Caroline @ ${parsed.hostname}` : "Project: Caroline";
  } catch {
    return "Project: Caroline";
  }
}

function newHostId() {
  return `host-${Date.now()}-${Math.random().toString(16).slice(2, 6)}`;
}

export default function App() {
  const [settings, setSettingsRaw] = useState<AppSettings>(loadSettings);
  const [aiName, setAiName] = useState("Caroline");
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

  function activeHost() {
    return settings.hosts.find((host) => host.id === settings.activeHostId) || settings.hosts[0];
  }

  function updateActiveHost(fields: Partial<SavedHost>) {
    const current = activeHost();
    if (!current) return;
    const hosts = settings.hosts.map((host) =>
      host.id === current.id ? { ...host, ...fields } : host
    );
    setSettings({
      ...settings,
      socketUrl: fields.socketUrl ?? settings.socketUrl,
      pairingCode: fields.pairingCode ?? settings.pairingCode,
      hosts,
    });
  }

  // Only recreates (and reconnects) when the active URL changes
  const socket = useMemo(
    () =>
      createCarolineSocket({
        url: activeSocketUrl,
        getClient: () => clientRef.current,
        onStatusChange: setStatus,
        onMessage: (msg) => {
          if (msg.type === "host_hello") {
            const raw = msg.raw && typeof msg.raw === "object" ? msg.raw as Record<string, unknown> : {};
            const nextName =
              (typeof raw.aiName === "string" ? raw.aiName : null) ??
              (typeof raw.name === "string" ? raw.name : null) ??
              msg.text;
            const nextHostName =
              (typeof raw.hostName === "string" ? raw.hostName : null) ??
              (typeof raw.host === "string" ? raw.host : null);

            if (nextName.trim()) setAiName(nextName.trim());
            if (nextHostName?.trim()) {
              const hostName = nextHostName.trim();
              setSettingsRaw((previous) => {
                let changed = false;
                const hosts = previous.hosts.map((host) => {
                  if (host.id !== previous.activeHostId || host.name === hostName) return host;
                  changed = true;
                  return { ...host, name: hostName };
                });

                if (!changed) return previous;

                const next = { ...previous, hosts };
                saveSettings(next);
                return next;
              });
            }
            return;
          }

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
    if (url && !/^wss?:\/\//i.test(url)) {
      setMessages((m) => [
        ...m,
        { id: Date.now(), from: "system", text: "WebSocket URL must start with ws:// or wss://" },
      ]);
      return;
    }
    updateActiveHost({ socketUrl: url, pairingCode: settings.pairingCode });
    if (url && url !== activeSocketUrl) {
      setActiveSocketUrl(url);
    } else {
      socketRef.current?.connect();
    }
  }

  function handleSelectHost(hostId: string) {
    const host = settings.hosts.find((h) => h.id === hostId);
    if (!host) return;
    setSettings({
      ...settings,
      activeHostId: host.id,
      socketUrl: host.socketUrl,
      pairingCode: host.pairingCode,
    });
    setActiveSocketUrl(host.socketUrl);
    setAiName("Caroline");
    setMessages((m) => [
      ...m,
      {
        id: Date.now(),
        from: "system",
        text: `Switched to ${host.name}.`,
      },
    ]);
  }

  function handleAddHost() {
    const host: SavedHost = {
      id: newHostId(),
      name: hostNameFromUrl(settings.socketUrl),
      socketUrl: settings.socketUrl,
      pairingCode: settings.pairingCode,
    };
    setSettings({
      ...settings,
      activeHostId: host.id,
      hosts: [...settings.hosts, host],
    });
  }

  function handleRemoveHost() {
    if (settings.hosts.length <= 1) return;
    const remaining = settings.hosts.filter((host) => host.id !== settings.activeHostId);
    const nextHost = remaining[0];
    setSettings({
      ...settings,
      activeHostId: nextHost.id,
      socketUrl: nextHost.socketUrl,
      pairingCode: nextHost.pairingCode,
      hosts: remaining,
    });
    setActiveSocketUrl(nextHost.socketUrl);
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
    const existing = settings.hosts.find((saved) => saved.socketUrl === host.url);
    const nextHost = existing || {
      id: newHostId(),
      name: `Project: Caroline @ ${host.label}`,
      socketUrl: host.url,
      pairingCode: settings.pairingCode,
    };
    const hosts = existing ? settings.hosts : [...settings.hosts, nextHost];
    setSettings({
      ...settings,
      activeHostId: nextHost.id,
      socketUrl: nextHost.socketUrl,
      pairingCode: nextHost.pairingCode,
      hosts,
    });
    setActiveSocketUrl(host.url);
    setAiName("Caroline");
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
          text: "Project: Caroline is offline. Open Settings (⚙), enter the WebSocket URL, and click Connect.",
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
            <strong>Project: Caroline</strong>
          </div>
          <div className="title-right">
            <span className="title-version">Companion 0.1b</span>
            <button
              type="button"
              className="settings-btn"
              onClick={() => setSettings({ ...settings, darkMode: !settings.darkMode })}
              aria-label="Toggle dark mode"
              title={settings.darkMode ? "Switch to light mode" : "Switch to dark mode"}
            >
              {settings.darkMode ? "☀" : "☾"}
            </button>
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
          <span>{statusLabel(status, aiName)}</span>
        </div>

        {/* ── Settings panel (shown when settingsOpen) ──────── */}
        {settingsOpen && (
          <section className="settings-panel" aria-label="Settings">

            <div className="settings-group">
              <label htmlFor="saved-host">Saved Host</label>
              <div className="settings-row">
                <select
                  id="saved-host"
                  value={settings.activeHostId}
                  onChange={(e) => handleSelectHost(e.target.value)}
                >
                  {settings.hosts.map((host) => (
                    <option value={host.id} key={host.id}>
                      {host.name}
                    </option>
                  ))}
                </select>
                <button type="button" onClick={handleAddHost}>
                  New
                </button>
                <button type="button" onClick={handleRemoveHost} disabled={settings.hosts.length <= 1}>
                  Remove
                </button>
              </div>
            </div>

            <div className="settings-group">
              <label htmlFor="host-name">Host Name</label>
              <input
                id="host-name"
                value={activeHost()?.name || ""}
                onChange={(e) => updateActiveHost({ name: e.target.value })}
              />
            </div>

            <div className="settings-group">
              <label htmlFor="socket-url">WebSocket URL</label>
              <div className="settings-row">
                <input
                  id="socket-url"
                  className="mono"
                  value={settings.socketUrl}
                  onChange={(e) => updateActiveHost({ socketUrl: e.target.value })}
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
                onChange={(e) => updateActiveHost({ pairingCode: e.target.value })}
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
                {isDiscovering ? "Searching network..." : "Find Project: Caroline Hosts on Network"}
              </button>
              {discoveredHosts.length > 0 && (
                <div className="discovered-hosts">
                  <p className="settings-note discovered-label">
                    Tap a host to connect:
                  </p>
                  {discoveredHosts.map((h) => (
                    <button
                      type="button"
                      key={h.url}
                      onClick={() => handleUseDiscoveredHost(h)}
                      title={h.url}
                    >
                      Project: Caroline @ {h.label}
                    </button>
                  ))}
                </div>
              )}
            </div>

          </section>
        )}

        {/* ── Chat area ─────────────────────────────────────── */}
        <section className="chat-shell">
          <aside className="buddy-list" aria-label="Buddy list">
            <div className="buddy-heading">Buddies</div>
            <div className={`buddy${isOnline ? " active" : ""}`}>
              <img
                src={carolineAvatar}
                alt={aiName}
                className="buddy-avatar"
                width={32}
                height={32}
              />
              <div>
                <strong>{aiName}</strong>
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
                      ? aiName
                      : "System"}
                  </span>
                  <p>{msg.text}</p>
                </article>
              ))}
            </div>

            <form className="compose" onSubmit={handleSubmit}>
              <input
                aria-label="Message Caroline"
                placeholder={isOnline ? "Type a message..." : `${aiName} is offline...`}
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
