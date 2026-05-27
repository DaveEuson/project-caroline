const SETTINGS_KEY = "caroline-companion-settings";

export type HostDeviceType = "" | "Pi" | "Steam" | "Ubuntu" | "Mac" | "Windows";

export type SavedHost = {
  id: string;
  name: string;
  aiName?: string;
  avatarId?: string;
  deviceType?: HostDeviceType;
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

const DEFAULT_SOCKET_URL = "";
const DEFAULT_HOSTS: SavedHost[] = [
  {
    id: "caroline-host",
    name: "Caroline",
    aiName: "Caroline",
    avatarId: "caroline",
    deviceType: "Pi",
    socketUrl: DEFAULT_SOCKET_URL,
    pairingCode: "",
  },
  {
    id: "carl-steam",
    name: "Carl",
    aiName: "Carl",
    avatarId: "carl",
    deviceType: "Steam",
    socketUrl: "ws://127.0.0.1:8088/ws/caroline",
    pairingCode: "",
  },
  {
    id: "catoline-ubuntu",
    name: "Catoline",
    aiName: "Catoline",
    avatarId: "catoline",
    deviceType: "Ubuntu",
    socketUrl: "",
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
  const value = String(url || DEFAULTS.socketUrl).replace(":1880/ws/caroline", ":8080/ws/caroline");
  try {
    const parsed = new URL(value);
    const isLoopback = ["127.0.0.1", "localhost", "::1", "[::1]"].includes(parsed.hostname);
    if (parsed.port === "8088" && !isLoopback) {
      parsed.port = "8080";
      return parsed.toString();
    }
  } catch {
    // Keep malformed/incomplete values editable in the settings UI.
  }
  return value;
}

function normalizeAvatarId(value: unknown, fallback = "caroline") {
  const id = String(value || "").trim();
  return ["caroline", "carl", "catoline", "robot"].includes(id) ? id : fallback;
}

export function normalizeDeviceType(value: unknown): HostDeviceType {
  const raw = String(value || "").trim().toLowerCase();
  if (!raw) return "";
  if (raw === "pi" || raw.includes("raspberry")) return "Pi";
  if (raw === "steam" || raw.includes("steam") || raw.includes("deck")) return "Steam";
  if (raw === "windows" || raw.includes("windows") || raw.includes("wsl")) return "Windows";
  if (raw === "mac" || raw.includes("mac") || raw.includes("darwin")) return "Mac";
  if (raw === "ubuntu" || raw.includes("ubuntu") || raw.includes("pop") || raw.includes("debian") || raw.includes("linux")) return "Ubuntu";
  return "";
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

function isLegacyPlaceholderHost(host: Partial<SavedHost>) {
  const id = String(host?.id || "").trim();
  const name = String(host?.name || "").toLowerCase();
  const url = String(host?.socketUrl || "");
  const pairingCode = String(host?.pairingCode || "").trim();
  if (pairingCode) return false;
  if (id === "carl-steamdeck" || id === "catoline-popos") return true;
  if (url.includes("POP_OS_IP")) return true;
  return name === "carl (steam deck tunnel)" || name === "catoline (pop!_os)";
}

function defaultDeviceTypeForHost(host: Partial<SavedHost>) {
  const hint = `${host?.id || ""} ${host?.name || ""} ${host?.aiName || ""} ${host?.socketUrl || ""}`;
  return normalizeDeviceType(hint);
}

function deriveUserNameFromCompanionName(value: string) {
  const match = String(value || "").trim().match(/^(.+?)'s Companion$/i);
  return match ? match[1].trim() : "";
}

function normalizeHosts(settings: AppSettings): AppSettings {
  const socketUrl = migrateSocketUrl(settings.socketUrl);
  const userName = String(settings.userName || deriveUserNameFromCompanionName(settings.companionName) || "").trim();
  const companionName = String(settings.companionName || (userName ? `${userName}'s Companion` : "My Companion")).trim();
  const avatarId = normalizeAvatarId(settings.avatarId, DEFAULTS.avatarId);
  const savedHosts = Array.isArray(settings.hosts) ? settings.hosts : [];
  const hostSource = savedHosts.length ? [...DEFAULT_HOSTS, ...savedHosts] : DEFAULT_HOSTS;
  const hosts = hostSource
    .filter((host) => !isLegacyPlaceholderHost(host))
    .map<SavedHost | null>((host, index) => {
      const hostUrl = migrateSocketUrl(host?.socketUrl || (index === 0 ? socketUrl : ""));
      const hostAiName = String(host?.aiName || "").trim();
      const hostAvatarId = normalizeAvatarId(host?.avatarId, "");
      const hostDeviceType = normalizeDeviceType(host?.deviceType) || defaultDeviceTypeForHost(host);
      const normalized: SavedHost = {
        id: safeHostId(host?.id || `host-${index + 1}`, `host-${index + 1}`),
        name: String(host?.name || hostAiName || hostNameFromUrl(hostUrl)).trim() || hostNameFromUrl(hostUrl),
        socketUrl: hostUrl,
        pairingCode: String(host?.pairingCode || ""),
      };
      if (hostAiName) normalized.aiName = hostAiName;
      if (hostAvatarId) normalized.avatarId = hostAvatarId;
      if (hostDeviceType) normalized.deviceType = hostDeviceType;
      return normalized;
    })
    .filter((host): host is SavedHost => host !== null);

  if (socketUrl && !hosts.some((host) => host.socketUrl === socketUrl)) {
    hosts.unshift({
      id: "default-host",
      name: hostNameFromUrl(socketUrl),
      socketUrl,
      pairingCode: settings.pairingCode || "",
    });
  }

  const uniqueHosts = hosts.reduce<SavedHost[]>((list, host) => {
    const existingIndex = list.findIndex((candidate) => candidate.id === host.id || (candidate.socketUrl && host.socketUrl && candidate.socketUrl === host.socketUrl));
    if (existingIndex >= 0) list[existingIndex] = host;
    else list.push(host);
    return list;
  }, []);

  const activeHostId = uniqueHosts.some((host) => host.id === settings.activeHostId)
    ? settings.activeHostId
    : (socketUrl ? uniqueHosts.find((host) => host.socketUrl === socketUrl)?.id : "") || uniqueHosts[0]?.id || "default-host";

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
