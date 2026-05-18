import { FormEvent, useEffect, useMemo, useRef, useState } from "react";
import {
  createCarolineSocket,
  type CarolineSocketStatus,
} from "./lib/carolineSocket";
import { buildWeeklyAgentProfile } from "./lib/agentProfile";
import { discoverCarolineHosts, type DiscoveredHost } from "./lib/hostDiscovery";
import { loadSettings, saveSettings, type AgentProfile, type AppSettings, type SavedHost } from "./lib/settings";
import carolineAvatar from "../src-tauri/icons/64x64.png";
import carlAwakeAvatar from "../../assets/Carl-awake.gif";
import carlAsleepAvatar from "../../assets/Carl-asleep.gif";

type ChatMessage = {
  id: number;
  from: "you" | "caroline" | "system" | "user";
  sender?: string;
  source?: string;
  text: string;
};

const COMPANION_VERSION = "0.1.4";
const COMPANION_RELEASES_URL = "https://github.com/Project-Caroline/project-caroline/releases";
const COMPANION_TAGS_URL = "https://api.github.com/repos/Project-Caroline/project-caroline/tags?per_page=30";

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
  return "Project: Caroline is offline";
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

function parseVersion(value: string) {
  return String(value || "")
    .replace(/^companion-v/i, "")
    .replace(/^v/i, "")
    .split(".")
    .map((part) => Number.parseInt(part, 10))
    .map((part) => (Number.isFinite(part) ? part : 0));
}

function compareVersions(a: string, b: string) {
  const left = parseVersion(a);
  const right = parseVersion(b);
  const length = Math.max(left.length, right.length, 3);
  for (let index = 0; index < length; index += 1) {
    const diff = (left[index] || 0) - (right[index] || 0);
    if (diff !== 0) return diff;
  }
  return 0;
}

function shouldAutoNameCompanion(value: string) {
  return !value.trim() || value.trim() === "My Companion" || value.trim() === "Dave's Companion";
}

function companionDisplayName(settings: AppSettings, fallbackUserName: string) {
  const saved = settings.companionName.trim();
  if (saved) return saved;
  const userName = settings.userName.trim() || fallbackUserName.trim();
  return userName ? `${userName}'s Companion` : "My Companion";
}

function buddyAvatarSrc(avatarId: string, isOnline: boolean) {
  return avatarId === "carl" ? (isOnline ? carlAwakeAvatar : carlAsleepAvatar) : carolineAvatar;
}

function chatUserName(settings: AppSettings, fallbackUserName: string) {
  return settings.userName.trim() || fallbackUserName.trim() || "You";
}

function formatMinutes(totalMinutes: number) {
  const minutes = Math.max(0, Math.round(totalMinutes));
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  const mins = minutes % 60;
  const parts = [];
  if (days) parts.push(`${days} day${days === 1 ? "" : "s"}`);
  if (hours) parts.push(`${hours} hour${hours === 1 ? "" : "s"}`);
  if (mins || !parts.length) parts.push(`${mins} minute${mins === 1 ? "" : "s"}`);
  return parts.join(", ");
}

export default function App() {
  const [settings, setSettingsRaw] = useState<AppSettings>(loadSettings);
  const [aiName, setAiName] = useState("Caroline");
  const [hostUserName, setHostUserName] = useState("");
  const [agentProfile, setAgentProfile] = useState<AgentProfile>(() =>
    buildWeeklyAgentProfile({
      aiName: "Caroline",
      userName: settings.userName,
      previous: settings.agentProfile,
    })
  );
  const [profileOpen, setProfileOpen] = useState(true);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [activeSocketUrl, setActiveSocketUrl] = useState(() => loadSettings().socketUrl);
  const [status, setStatus] = useState<CarolineSocketStatus>("offline");
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages);
  const [draft, setDraft] = useState("");
  const [discoveredHosts, setDiscoveredHosts] = useState<DiscoveredHost[]>([]);
  const [isDiscovering, setIsDiscovering] = useState(false);
  const [isCheckingUpdate, setIsCheckingUpdate] = useState(false);
  const [updateMessage, setUpdateMessage] = useState("");

  const [clientId] = useState(getOrCreateClientId);

  // Mutable ref so socket always reads latest name/code without being recreated
  const clientRef = useRef({
    clientId,
    displayName: companionDisplayName(settings, hostUserName),
    userName: chatUserName(settings, hostUserName),
    pairingCode: settings.pairingCode,
  });

  const socketRef = useRef<ReturnType<typeof createCarolineSocket> | null>(null);
  const transcriptRef = useRef<HTMLDivElement | null>(null);
  const aiNameRef = useRef(aiName);
  const hostUserNameRef = useRef("");

  // Apply dark mode to <html> element whenever the setting changes
  useEffect(() => {
    document.documentElement.dataset.theme = settings.darkMode ? "dark" : "light";
  }, [settings.darkMode]);

  // Keep clientRef current with latest settings (no socket reconnect needed)
  useEffect(() => {
    clientRef.current = {
      clientId,
      displayName: companionDisplayName(settings, hostUserName),
      userName: chatUserName(settings, hostUserName),
      pairingCode: settings.pairingCode,
    };
  }, [clientId, hostUserName, settings.companionName, settings.pairingCode, settings.userName]);

  useEffect(() => {
    aiNameRef.current = aiName;
  }, [aiName]);

  useEffect(() => {
    hostUserNameRef.current = hostUserName;
  }, [hostUserName]);

  useEffect(() => {
    const nextProfile = buildWeeklyAgentProfile({
      aiName,
      userName: chatUserName(settings, hostUserName),
      previous: settings.agentProfile || agentProfile,
    });
    setAgentProfile(nextProfile);
    if (settings.agentProfile?.weekKey !== nextProfile.weekKey || settings.agentProfile?.seed !== nextProfile.seed) {
      setSettingsRaw((previous) => {
        const next = { ...previous, agentProfile: nextProfile };
        saveSettings(next);
        return next;
      });
    }
  }, [aiName, hostUserName, settings.userName]);

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
            const nextUserName =
              (typeof raw.userName === "string" ? raw.userName : null) ??
              msg.userName;
            const profileText =
              (typeof raw.agentProfile === "string" ? raw.agentProfile : null) ??
              (typeof raw.profile === "string" ? raw.profile : null) ??
              msg.agentProfile ??
              "";
            const personalityHint =
              (typeof raw.personalityHint === "string" ? raw.personalityHint : null) ??
              (typeof raw.personalitySummary === "string" ? raw.personalitySummary : null) ??
              msg.personalityHint ??
              "";

            const resolvedAiName = nextName.trim() || "Caroline";
            if (resolvedAiName) setAiName(resolvedAiName);
            if (nextUserName?.trim()) {
              const userName = nextUserName.trim();
              setHostUserName(userName);
            }

            setSettingsRaw((previous) => {
              const userName = nextUserName?.trim() || previous.userName || hostUserNameRef.current;
              const hostName = nextHostName?.trim();
              const hosts = hostName
                ? previous.hosts.map((host) =>
                    host.id === previous.activeHostId && host.name !== hostName
                      ? { ...host, name: hostName }
                      : host
                  )
                : previous.hosts;
              const companionName = shouldAutoNameCompanion(previous.companionName)
                ? companionDisplayName({ ...previous, userName }, userName)
                : previous.companionName;
              const profile = buildWeeklyAgentProfile({
                aiName: resolvedAiName,
                userName,
                hostProfile: profileText,
                personalityHint,
                previous: previous.agentProfile,
              });
              setAgentProfile(profile);
              const next = {
                ...previous,
                userName: previous.userName || userName,
                companionName,
                hosts,
                agentProfile: profile,
              };
              saveSettings(next);
              return next;
            });
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

          if (msg.role === "user" || msg.type === "user_discord" || msg.type === "user_telegram") {
            if (msg.clientId && msg.clientId === clientId) return;

            const sender =
              msg.source === "caroline-companion"
                ? msg.clientName || "Companion"
                : msg.source === "discord"
                ? `${msg.userName || hostUserNameRef.current || "User"} via Discord`
                : msg.source === "telegram"
                ? `${msg.userName || hostUserNameRef.current || "User"} via Telegram`
                : msg.userName || hostUserNameRef.current || "You";

            setMessages((m) => [
              ...m,
              {
                id: Date.now(),
                from: "user",
                sender,
                source: msg.source,
                text: msg.text,
              },
            ]);
            return;
          }

          setMessages((m) => [
            ...m,
            {
              id: Date.now(),
              from: msg.role === "system" ? "system" : "caroline",
              sender: msg.role === "system" ? "System" : msg.aiName || aiNameRef.current,
              source: msg.source,
              text: msg.text,
            },
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
            ? `Found ${hosts.length} possible Project: Caroline host${hosts.length === 1 ? "" : "s"} on the network.`
            : "No Project: Caroline hosts found. Type the URL manually in Settings.",
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

  async function handleCheckClientUpdates() {
    setIsCheckingUpdate(true);
    setUpdateMessage("");

    try {
      const response = await fetch(COMPANION_TAGS_URL, { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const tags = await response.json() as Array<{ name?: string }>;
      const latestTag = tags
        .map((tag) => String(tag.name || ""))
        .find((name) => /^companion-v\d+/i.test(name));

      if (!latestTag) {
        setUpdateMessage("No Companion release tag is published yet.");
        return;
      }

      const latestVersion = latestTag.replace(/^companion-v/i, "");
      if (compareVersions(latestVersion, COMPANION_VERSION) > 0) {
        setUpdateMessage(`Companion ${latestVersion} is available. Get it from ${COMPANION_RELEASES_URL}.`);
      } else {
        setUpdateMessage(`Companion ${COMPANION_VERSION} is current on nightly.`);
      }
    } catch {
      setUpdateMessage(`Could not check GitHub. Releases live at ${COMPANION_RELEASES_URL}.`);
    } finally {
      setIsCheckingUpdate(false);
    }
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = draft.trim();
    if (!text) return;

    setMessages((m) => [
      ...m,
      { id: Date.now(), from: "you", sender: chatUserName(settings, hostUserName), text },
    ]);
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
  const buddyAvatar = buddyAvatarSrc(settings.avatarId, isOnline);

  return (
    <main className="desktop">
      <section className="messenger-window" aria-label="Project: Caroline companion chat">

        {/* ── Title bar ─────────────────────────────────────── */}
        <header className="title-bar">
          <div className="title-left">
            <span className="window-dot" />
            <strong>Project: Caroline</strong>
          </div>
          <div className="title-right">
            <span className="title-version">Companion {COMPANION_VERSION}</span>
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
              <label htmlFor="saved-host">Saved Project: Caroline Host</label>
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
              <label htmlFor="user-name">Your Name</label>
              <input
                id="user-name"
                value={settings.userName || hostUserName}
                onChange={(e) => setSettings({ ...settings, userName: e.target.value })}
                placeholder="Dave"
              />
            </div>

            <div className="settings-group">
              <label htmlFor="companion-name">Companion Name</label>
              <input
                id="companion-name"
                value={settings.companionName}
                onChange={(e) => setSettings({ ...settings, companionName: e.target.value })}
                placeholder={`${chatUserName(settings, hostUserName)}'s Companion`}
              />
            </div>

            <div className="settings-group">
              <label htmlFor="avatar-id">AI Avatar</label>
              <select
                id="avatar-id"
                value={settings.avatarId || "caroline"}
                onChange={(e) => setSettings({ ...settings, avatarId: e.target.value })}
              >
                <option value="caroline">Caroline</option>
                <option value="carl">Carl</option>
              </select>
            </div>

            <div className="settings-group">
              <button
                type="button"
                className="full-width-btn"
                onClick={handleCheckClientUpdates}
                disabled={isCheckingUpdate}
              >
                {isCheckingUpdate ? "Checking for Client Updates..." : "Check Client Updates"}
              </button>
              {updateMessage && <p className="settings-note">{updateMessage}</p>}
            </div>

            {/* Pairing code — host kiosk displays a code; client enters it here */}
            <div className="settings-group">
              <label htmlFor="pairing-code">
                Pairing Code{" "}
                <span
                  className="help-tip"
                  title="Enter the code shown on the Project: Caroline kiosk screen. Leave blank if the host does not require one."
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
                src={buddyAvatar}
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
            <button
              type="button"
              className="buddy-profile-btn"
              onClick={() => setProfileOpen((open) => !open)}
            >
              Buddy Info
            </button>
          </aside>

          <div className="chat-panel">
            {profileOpen && (
              <section
                className={`profile-window profile-theme-${agentProfile.theme || "midnight"}`}
                aria-label={`${aiName} buddy info`}
              >
                <header className="profile-title">
                  <span className="profile-running-icon" />
                  <strong>Buddy Info:</strong>
                  <input value={agentProfile.screenName || aiName} readOnly aria-label="Generated screen name" />
                  <button type="button" disabled>
                    OK
                  </button>
                  <button type="button" onClick={() => setProfileOpen(false)}>
                    Close
                  </button>
                </header>
                <div className="profile-stats">
                  <p>
                    <strong>Warning Level:</strong> {agentProfile.warningLevel || 0}%
                  </p>
                  <p>
                    <strong>Online time:</strong> {formatMinutes(agentProfile.onlineMinutes || 4)}
                  </p>
                  <p>
                    <strong>Away, Idle:</strong> {formatMinutes(agentProfile.idleMinutes || 1)}
                  </p>
                </div>
                <div className="profile-label">Away message / Personal Profile:</div>
                <div className="profile-scroll">
                  <div className="profile-canvas">
                    <div className="profile-kicker">{agentProfile.screenName || aiName}</div>
                    {agentProfile.profileLines.map((line, index) => (
                      <p className={`profile-line line-${index + 1}`} key={`${agentProfile.weekKey}-${index}`}>
                        {line}
                      </p>
                    ))}
                    <div className="profile-divider">~x~x~x~x~x~x~x~x~x~x~x~x~x~x~x~x~x~x~x~</div>
                    <div className="profile-music">
                      <strong>Now listening:</strong>
                      {agentProfile.songs.map((song) => (
                        <span key={song}>{song}</span>
                      ))}
                    </div>
                    <div className="profile-footer">{agentProfile.status}</div>
                  </div>
                </div>
              </section>
            )}
            <div className="transcript" ref={transcriptRef}>
              {messages.map((msg) => (
                <article className={`message ${msg.from}`} key={msg.id}>
                  <span>
                    {msg.sender ||
                      (msg.from === "you"
                        ? chatUserName(settings, hostUserName)
                        : msg.from === "caroline"
                        ? aiName
                        : msg.from === "user"
                        ? hostUserName || "You"
                        : "System")}
                  </span>
                  <p>{msg.text}</p>
                </article>
              ))}
            </div>

            <div className="action-strip" aria-label="Chat actions">
              <button type="button" onClick={() => setProfileOpen((open) => !open)}>
                Profile
              </button>
              <button type="button" onClick={() => setSettingsOpen((open) => !open)}>
                Settings
              </button>
              <button type="button" onClick={handleCheckClientUpdates} disabled={isCheckingUpdate}>
                Updates
              </button>
            </div>

            <form className="compose" onSubmit={handleSubmit}>
              <input
                aria-label={`Message ${aiName}`}
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
