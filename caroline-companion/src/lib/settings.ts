const SETTINGS_KEY = "caroline-companion-settings";

export type SavedHost = {
  id: string;
  name: string;
  socketUrl: string;
  pairingCode: string;
};

export type AgentProfile = {
  weekKey: string;
  screenName: string;
  headline: string;
  body: string;
  profileLines: string[];
  songs: string[];
  status: string;
  warningLevel: number;
  onlineMinutes: number;
  idleMinutes: number;
  theme: string;
  writtenAt: string;
  seed: string;
};

export type AppSettings = {
  socketUrl: string;
  userName: string;
  companionName: string;
  avatarId: string;
  pairingCode: string;
  darkMode: boolean;
  activeHostId: string;
  hosts: SavedHost[];
  agentProfile: AgentProfile | null;
};

const DEFAULT_SOCKET_URL = "ws://192.168.1.50:8080/ws/caroline";
const DEFAULT_HOSTS: SavedHost[] = [
  {
    id: "caroline-pi",
    name: "Caroline (Pi)",
    socketUrl: DEFAULT_SOCKET_URL,
    pairingCode: "",
  },
  {
    id: "carl-steamdeck",
    name: "Carl (Steam Deck tunnel)",
    socketUrl: "ws://127.0.0.1:8088/ws/caroline",
    pairingCode: "",
  },
  {
    id: "catoline-popos",
    name: "Catoline (Pop!_OS)",
    socketUrl: "ws://POP_OS_IP:8080/ws/caroline",
    pairingCode: "",
  },
];

const DEFAULTS: AppSettings = {
  socketUrl: DEFAULT_SOCKET_URL,
  userName: "",
  companionName: "",
  avatarId: "caroline",
  pairingCode: "",
  darkMode: false,
  activeHostId: DEFAULT_HOSTS[0].id,
  agentProfile: null,
  hosts: DEFAULT_HOSTS,
};

function migrateSocketUrl(url: string) {
  return String(url || DEFAULTS.socketUrl).replace(":1880/ws/caroline", ":8080/ws/caroline");
}

function safeHostId(value: string, fallback: string) {
  return String(value || fallback).replace(/[^a-zA-Z0-9_-]+/g, "-").replace(/^-+|-+$/g, "") || fallback;
}

function hostNameFromUrl(url: string) {
  try {
    const parsed = new URL(url);
    return parsed.hostname ? `Project: Caroline @ ${parsed.hostname}` : "Project: Caroline";
  } catch {
    return "Project: Caroline";
  }
}

function deriveUserNameFromCompanionName(value: string) {
  const match = String(value || "").trim().match(/^(.+?)'s Companion$/i);
  return match ? match[1].trim() : "";
}

function normalizeHosts(settings: AppSettings): AppSettings {
  const socketUrl = migrateSocketUrl(settings.socketUrl);
  const userName = String(settings.userName || deriveUserNameFromCompanionName(settings.companionName) || "").trim();
  const companionName = String(settings.companionName || (userName ? `${userName}'s Companion` : "My Companion")).trim();
  const avatarId = ["caroline", "carl", "catoline", "robot"].includes(String(settings.avatarId || "").trim())
    ? String(settings.avatarId).trim()
    : DEFAULTS.avatarId;
  const hostSource = [...DEFAULT_HOSTS, ...(Array.isArray(settings.hosts) ? settings.hosts : [])];
  const hosts = hostSource
    .map((host, index) => {
      const hostUrl = migrateSocketUrl(host?.socketUrl || (index === 0 ? socketUrl : ""));
      if (!hostUrl) return null;
      return {
        id: safeHostId(host?.id || `host-${index + 1}`, `host-${index + 1}`),
        name: String(host?.name || hostNameFromUrl(hostUrl)).trim() || hostNameFromUrl(hostUrl),
        socketUrl: hostUrl,
        pairingCode: String(host?.pairingCode || ""),
      };
    })
    .filter((host): host is SavedHost => Boolean(host));

  if (!hosts.some((host) => host.socketUrl === socketUrl)) {
    hosts.unshift({
      id: "default-host",
      name: hostNameFromUrl(socketUrl),
      socketUrl,
      pairingCode: settings.pairingCode || "",
    });
  }

  const uniqueHosts = hosts.reduce<SavedHost[]>((list, host) => {
    const existingIndex = list.findIndex((candidate) => candidate.id === host.id || candidate.socketUrl === host.socketUrl);
    if (existingIndex >= 0) list[existingIndex] = host;
    else list.push(host);
    return list;
  }, []);

  const activeHostId = uniqueHosts.some((host) => host.id === settings.activeHostId)
    ? settings.activeHostId
    : uniqueHosts.find((host) => host.socketUrl === socketUrl)?.id || uniqueHosts[0]?.id || "default-host";

  const activeHost = uniqueHosts.find((host) => host.id === activeHostId) || uniqueHosts[0];

  return {
    ...settings,
    userName,
    companionName,
    avatarId,
    socketUrl: activeHost?.socketUrl || socketUrl,
    pairingCode: activeHost?.pairingCode ?? settings.pairingCode,
    activeHostId,
    hosts: uniqueHosts.length ? uniqueHosts : DEFAULTS.hosts,
    agentProfile: settings.agentProfile || null,
  };
}

export function loadSettings(): AppSettings {
  try {
    const stored = localStorage.getItem(SETTINGS_KEY);
    if (stored) {
      const parsed = { ...DEFAULTS, ...(JSON.parse(stored) as Partial<AppSettings>) };
      return normalizeHosts(parsed);
    }
  } catch {
    // corrupted storage — use defaults
  }
  return normalizeHosts({ ...DEFAULTS });
}

export function saveSettings(settings: AppSettings): void {
  const normalized = normalizeHosts(settings);
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(normalized));
}
