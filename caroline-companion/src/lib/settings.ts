const SETTINGS_KEY = "caroline-companion-settings";

export type SavedHost = {
  id: string;
  name: string;
  socketUrl: string;
  pairingCode: string;
};

export type AppSettings = {
  socketUrl: string;
  companionName: string;
  pairingCode: string;
  darkMode: boolean;
  activeHostId: string;
  hosts: SavedHost[];
};

const DEFAULT_SOCKET_URL = "ws://192.168.1.50:8080/ws/caroline";

const DEFAULTS: AppSettings = {
  socketUrl: DEFAULT_SOCKET_URL,
  companionName: "Dave's Companion",
  pairingCode: "",
  darkMode: false,
  activeHostId: "default-host",
  hosts: [
    {
      id: "default-host",
      name: "Project: Caroline",
      socketUrl: DEFAULT_SOCKET_URL,
      pairingCode: "",
    },
  ],
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

function normalizeHosts(settings: AppSettings): AppSettings {
  const socketUrl = migrateSocketUrl(settings.socketUrl);
  const hosts = (Array.isArray(settings.hosts) ? settings.hosts : [])
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

  const uniqueHosts = hosts.filter((host, index, list) => {
    return list.findIndex((candidate) => candidate.socketUrl === host.socketUrl) === index;
  });

  const activeHostId = uniqueHosts.some((host) => host.id === settings.activeHostId)
    ? settings.activeHostId
    : uniqueHosts.find((host) => host.socketUrl === socketUrl)?.id || uniqueHosts[0]?.id || "default-host";

  const activeHost = uniqueHosts.find((host) => host.id === activeHostId) || uniqueHosts[0];

  return {
    ...settings,
    socketUrl: activeHost?.socketUrl || socketUrl,
    pairingCode: activeHost?.pairingCode ?? settings.pairingCode,
    activeHostId,
    hosts: uniqueHosts.length ? uniqueHosts : DEFAULTS.hosts,
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
  // Pairing codes are session-only credentials — don't persist them to disk.
  const toSave = {
    ...normalized,
    pairingCode: "",
    hosts: normalized.hosts.map((h) => ({ ...h, pairingCode: "" })),
  };
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(toSave));
}
