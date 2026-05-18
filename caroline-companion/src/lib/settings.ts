const SETTINGS_KEY = "caroline-companion-settings";

export type AppSettings = {
  socketUrl: string;
  companionName: string;
  pairingCode: string;
  darkMode: boolean;
};

const DEFAULTS: AppSettings = {
  socketUrl: "ws://192.168.1.50:8080/ws/caroline",
  companionName: "Dave's Companion",
  pairingCode: "",
  darkMode: false,
};

export function loadSettings(): AppSettings {
  try {
    const stored = localStorage.getItem(SETTINGS_KEY);
    if (stored) return { ...DEFAULTS, ...(JSON.parse(stored) as Partial<AppSettings>) };
  } catch {
    // corrupted storage — use defaults
  }
  return { ...DEFAULTS };
}

export function saveSettings(settings: AppSettings): void {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
}
