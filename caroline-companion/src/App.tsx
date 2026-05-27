import { ChangeEvent, FormEvent, useCallback, useEffect, useRef, useState } from "react";
import {
  createCarolineSocket,
  type CarolineSocketMessage,
  type CarolineSocketStatus,
} from "./lib/carolineSocket";
import { buildWeeklyAgentProfile } from "./lib/agentProfile";
import { discoverCarolineHosts, type DiscoveredHost } from "./lib/hostDiscovery";
import {
  loadSettings,
  normalizeDeviceType,
  saveSettings,
  type AgentProfile,
  type AppSettings,
  type HostDeviceType,
  type SavedHost,
} from "./lib/settings";
import carolineAvatar from "../src-tauri/icons/64x64.png";
import carlAwakeAvatar from "../../assets/Carl-awake.gif";
import carlAsleepAvatar from "../../assets/Carl-asleep.gif";
import catAvatar from "../../assets/cat.gif";
import robotAwakeAvatar from "../../assets/Robot-Awake.gif";
import robotSleepingAvatar from "../../assets/Robot-Sleeping.gif";

type ChatMessage = {
  id: number;
  from: "you" | "caroline" | "system" | "user";
  sender?: string;
  source?: string;
  text: string;
};

type BuddyState = {
  status: CarolineSocketStatus;
  aiName: string;
  hostName: string;
  deviceType: HostDeviceType;
  userName: string;
  unreadCount: number;
  lastMessage: string;
  lastMessageAt: number;
};

type HostSocketEntry = {
  signature: string;
  socket: ReturnType<typeof createCarolineSocket>;
};

type HostSetupSettings = {
  userName: string;
  aiName: string;
  hostDeviceType: string;
  timezone: string;
  location: string;
  cityName: string;
  aiProvider: "openrouter" | "ollama";
  aiModel: string;
  ollamaUrl: string;
  ollamaModel: string;
  spotifyClientId: string;
  googleClientId: string;
  googleRedirectUri: string;
  calendarId: string;
  defaultWriteCalendarId: string;
};

type HostHealth = {
  aiProvider?: string;
  aiModel?: string;
  ollamaModel?: string;
  hostDeviceType?: string;
  openrouter?: {
    configured?: boolean;
  };
  google?: {
    connected?: boolean;
    clientConfigured?: boolean;
    hasClientSecret?: boolean;
    serviceAccountConfigured?: boolean;
  };
  spotify?: {
    connected?: boolean;
    clientConfigured?: boolean;
  };
  calendar?: {
    configured?: boolean;
  };
  hue?: {
    configured?: boolean;
  };
  discord?: {
    enabled?: boolean;
    configured?: boolean;
    channelConfigured?: boolean;
    mode?: string;
  };
};

type HostPrivacySummary = {
  localOnly?: boolean;
  counts?: {
    chatMessages?: number;
    memoryShards?: number;
    tasks?: number;
  };
  retention?: {
    privacyMode?: boolean;
    historyRetentionMs?: number;
    memoryRetentionMs?: number;
  };
  integrations?: Record<string, {
    label?: string;
    configured?: boolean;
    connected?: boolean;
    enabled?: boolean;
    model?: string;
  }>;
  files?: Array<{
    label?: string;
    path?: string;
    exists?: boolean;
    bytes?: number;
  }>;
  browserStorageHints?: Array<{
    label?: string;
    key?: string;
  }>;
  lastUpdated?: string;
};

type HostMemoryShard = {
  id?: string;
  text?: string;
  createdAt?: string;
  source?: string;
};

const COMPANION_VERSION = "0.1.12";
const COMPANION_RELEASES_URL = "https://github.com/Project-Caroline/project-caroline/releases";
const COMPANION_TAGS_URL = "https://api.github.com/repos/Project-Caroline/project-caroline/tags?per_page=30";
const CHAT_HISTORY_KEY = "caroline-companion-chat-history-v1";
const MAX_MESSAGES_PER_HOST = 500;
const HOST_DEVICE_TYPES: HostDeviceType[] = ["", "Pi", "Steam", "Ubuntu", "Mac", "Windows"];
const HOST_SETUP_DEFAULTS: HostSetupSettings = {
  userName: "",
  aiName: "Caroline",
  hostDeviceType: "",
  timezone: "",
  location: "",
  cityName: "",
  aiProvider: "openrouter",
  aiModel: "anthropic/claude-haiku-4.5",
  ollamaUrl: "http://localhost:11434",
  ollamaModel: "qwen2.5:1.5b",
  spotifyClientId: "",
  googleClientId: "",
  googleRedirectUri: "",
  calendarId: "primary",
  defaultWriteCalendarId: "",
};

let localMessageId = Date.now();

function nextMessageId() {
  localMessageId += 1;
  return localMessageId;
}

function inferBuddyAiName(host?: SavedHost) {
  const savedName = host?.aiName?.trim();
  if (savedName) return savedName;
  const customName = host?.name?.trim();
  if (customName && !isAutoHostName(customName)) return customName;
  const hint = `${host?.id || ""} ${host?.name || ""}`.toLowerCase();
  if (hint.includes("carl")) return "Carl";
  if (hint.includes("cat")) return "Catoline";
  if (hint.includes("robot")) return "Robot";
  if (hint.includes("frog")) return "Frog Pilot";
  return "Caroline";
}

function inferAvatarId(value: string) {
  const normalized = value.toLowerCase();
  if (normalized.includes("carl")) return "carl";
  if (normalized.includes("cat")) return "catoline";
  if (normalized.includes("robot")) return "robot";
  return "caroline";
}

function inferDeviceTypeForHost(host?: SavedHost, state?: BuddyState): HostDeviceType {
  return normalizeDeviceType(state?.deviceType || host?.deviceType) || normalizeDeviceType(`${host?.id || ""} ${host?.name || ""} ${host?.socketUrl || ""}`);
}

function deviceTypeLabel(deviceType?: HostDeviceType) {
  return deviceType ? deviceType : "Device";
}

function isAutoHostName(value: string) {
  const name = value.trim().toLowerCase();
  return (
    !name ||
    name === "project: caroline" ||
    name.startsWith("project: caroline @") ||
    name.startsWith("project: caroline (") ||
    name === "caroline (pi)" ||
    name === "carl (steam deck tunnel)" ||
    name === "catoline (pop!_os)" ||
    name === "new buddy"
  );
}

function buddyDisplayName(host: SavedHost, state?: BuddyState) {
  return state?.aiName || host.aiName || inferBuddyAiName(host);
}

function initialMessagesForHost(host?: SavedHost): ChatMessage[] {
  const buddyName = inferBuddyAiName(host);
  const hostLabel = host?.name || "Project: Caroline";
  return [
    {
      id: nextMessageId(),
      from: "caroline",
      sender: buddyName,
      text: `Hey! This chat is ready for ${hostLabel}.`,
    },
    {
      id: nextMessageId(),
      from: "system",
      text: "Enter that kiosk's SYNC code in Settings if this buddy asks to pair.",
    },
  ];
}

function resetMessagesForHosts(hosts: SavedHost[]) {
  return Object.fromEntries(hosts.map((host) => [host.id, initialMessagesForHost(host)]));
}

function normalizeChatMessage(value: unknown): ChatMessage | null {
  if (!value || typeof value !== "object") return null;
  const record = value as Record<string, unknown>;
  const from = record.from;
  const text = typeof record.text === "string" ? record.text : "";
  if (from !== "you" && from !== "caroline" && from !== "system" && from !== "user") return null;
  if (!text.trim()) return null;

  return {
    id: typeof record.id === "number" && Number.isFinite(record.id) ? record.id : nextMessageId(),
    from,
    sender: typeof record.sender === "string" ? record.sender : undefined,
    source: typeof record.source === "string" ? record.source : undefined,
    text,
  };
}

function trimChatHistory(messages: ChatMessage[]) {
  return messages.slice(-MAX_MESSAGES_PER_HOST);
}

function isTaskUpdateNoise(message: ChatMessage) {
  return message.from === "caroline" && /^\s*(?:\uD83D\uDCCB\s*)?Task list updated\b/.test(message.text);
}

function isCalendarUpdateNoise(message: ChatMessage) {
  return message.from === "caroline" && /^\s*Calendar updated\b/i.test(message.text);
}

function cleanChatHistory(messages: ChatMessage[]) {
  return trimChatHistory(messages.filter((message) => !isTaskUpdateNoise(message) && !isCalendarUpdateNoise(message)));
}

function loadChatHistory(): Record<string, ChatMessage[]> {
  try {
    const stored = localStorage.getItem(CHAT_HISTORY_KEY);
    if (!stored) return {};
    const parsed = JSON.parse(stored) as unknown;
    if (!parsed || typeof parsed !== "object") return {};

    return Object.entries(parsed as Record<string, unknown>).reduce<Record<string, ChatMessage[]>>((history, [hostId, value]) => {
      if (!Array.isArray(value)) return history;
      const messages = value.map(normalizeChatMessage).filter((message): message is ChatMessage => Boolean(message));
      const cleanedMessages = cleanChatHistory(messages);
      if (cleanedMessages.length) history[hostId] = cleanedMessages;
      return history;
    }, {});
  } catch {
    return {};
  }
}

function saveChatHistory(history: Record<string, ChatMessage[]>) {
  try {
    const trimmed = Object.entries(history).reduce<Record<string, ChatMessage[]>>((next, [hostId, messages]) => {
      const cleanedMessages = cleanChatHistory(messages);
      if (cleanedMessages.length) next[hostId] = cleanedMessages;
      return next;
    }, {});
    localStorage.setItem(CHAT_HISTORY_KEY, JSON.stringify(trimmed));
  } catch {
    // Best effort only. Chat should keep working even if browser storage is full or unavailable.
  }
}

function deleteChatHistory() {
  try {
    localStorage.removeItem(CHAT_HISTORY_KEY);
  } catch {
    // Best effort only.
  }
}

function isUsableSocketUrl(url: string) {
  const trimmed = url.trim();
  return /^wss?:\/\//i.test(trimmed) && !/POP_OS_IP/i.test(trimmed);
}

function hostLooksReadyToConnect(host?: SavedHost) {
  return Boolean(host?.pairingCode.trim()) && isUsableSocketUrl(host?.socketUrl || "");
}

function initialBuddyState(host?: SavedHost): BuddyState {
  return {
    status: hostLooksReadyToConnect(host) ? "connecting" : "offline",
    aiName: inferBuddyAiName(host),
    hostName: host?.name || "Project: Caroline",
    deviceType: inferDeviceTypeForHost(host),
    userName: "",
    unreadCount: 0,
    lastMessage: "",
    lastMessageAt: 0,
  };
}

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
  const normalized = avatarId.toLowerCase();
  if (normalized.includes("carl")) return isOnline ? carlAwakeAvatar : carlAsleepAvatar;
  if (normalized.includes("cat")) return catAvatar;
  if (normalized.includes("robot")) return isOnline ? robotAwakeAvatar : robotSleepingAvatar;
  return carolineAvatar;
}

function avatarIdForHost(host: SavedHost, state?: BuddyState) {
  if (host.avatarId) return host.avatarId;
  const hint = `${host.id} ${host.name} ${host.aiName || ""} ${state?.aiName || ""}`.toLowerCase();
  if (hint.includes("carl")) return "carl";
  if (hint.includes("cat")) return "catoline";
  if (hint.includes("robot")) return "robot";
  return "caroline";
}

function buddyStatusText(status: CarolineSocketStatus) {
  if (status === "online") return "available";
  if (status === "connecting") return "signing on...";
  if (status === "rejected") return "pairing rejected";
  return "offline";
}

function hasPairingCode(host?: SavedHost) {
  return Boolean(host?.pairingCode.trim());
}

function hostSocketSignature(url: string) {
  return url.trim();
}

function stringSetting(record: Record<string, unknown>, key: string, fallback = "") {
  const value = record[key];
  return typeof value === "string" ? value.trim() : fallback;
}

function normalizeHostSetupSettings(value: unknown): HostSetupSettings {
  const record = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const provider = stringSetting(record, "aiProvider", HOST_SETUP_DEFAULTS.aiProvider).toLowerCase();
  return {
    userName: stringSetting(record, "userName"),
    aiName: stringSetting(record, "aiName", HOST_SETUP_DEFAULTS.aiName),
    hostDeviceType: stringSetting(record, "hostDeviceType"),
    timezone: stringSetting(record, "timezone"),
    location: stringSetting(record, "location"),
    cityName: stringSetting(record, "cityName"),
    aiProvider: provider === "ollama" ? "ollama" : "openrouter",
    aiModel: stringSetting(record, "aiModel", HOST_SETUP_DEFAULTS.aiModel),
    ollamaUrl: stringSetting(record, "ollamaUrl", HOST_SETUP_DEFAULTS.ollamaUrl),
    ollamaModel: stringSetting(record, "ollamaModel", HOST_SETUP_DEFAULTS.ollamaModel),
    spotifyClientId: stringSetting(record, "spotifyClientId"),
    googleClientId: stringSetting(record, "googleClientId"),
    googleRedirectUri: stringSetting(record, "googleRedirectUri"),
    calendarId: stringSetting(record, "calendarId", HOST_SETUP_DEFAULTS.calendarId),
    defaultWriteCalendarId: stringSetting(record, "defaultWriteCalendarId"),
  };
}

function hostHttpBaseFromSocket(socketUrl: string) {
  const trimmed = socketUrl.trim();
  if (!trimmed) return "";
  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol === "ws:" || parsed.protocol === "wss:") {
      parsed.protocol = parsed.protocol === "wss:" ? "https:" : "http:";
      parsed.pathname = "";
      parsed.search = "";
      parsed.hash = "";
      return parsed.toString().replace(/\/+$/, "");
    }
    if (parsed.protocol === "http:" || parsed.protocol === "https:") {
      parsed.pathname = "";
      parsed.search = "";
      parsed.hash = "";
      return parsed.toString().replace(/\/+$/, "");
    }
  } catch {
    // Let the caller show a useful status message.
  }
  return "";
}

function hostSecureVoiceUrlFromBase(baseUrl: string) {
  if (!baseUrl) return "";
  try {
    const parsed = new URL(baseUrl);
    parsed.protocol = "https:";
    parsed.port = "8444";
    parsed.pathname = "/";
    parsed.search = "";
    parsed.hash = "";
    return parsed.toString();
  } catch {
    return "";
  }
}

function hostSettingsPayload(setup: HostSetupSettings) {
  const calendarId = setup.calendarId || "primary";
  return {
    userName: setup.userName,
    aiName: setup.aiName,
    hostDeviceType: setup.hostDeviceType,
    timezone: setup.timezone,
    location: setup.location,
    cityName: setup.cityName,
    aiProvider: setup.aiProvider,
    aiModel: setup.aiModel,
    ollamaUrl: setup.ollamaUrl,
    ollamaModel: setup.ollamaModel,
    spotifyClientId: setup.spotifyClientId,
    googleClientId: setup.googleClientId,
    googleRedirectUri: setup.googleRedirectUri,
    calendarId,
    defaultWriteCalendarId: setup.defaultWriteCalendarId || calendarId,
    setupComplete: true,
  };
}

async function fetchHostSettings(base: string) {
  let lastError: Error | null = null;
  for (const path of ["/admin/settings", "/admin/get-settings"]) {
    try {
      const response = await fetch(`${base}${path}`, { cache: "no-store" });
      if (response.status === 404) {
        lastError = new Error(`HTTP 404 at ${path}`);
        continue;
      }
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return response;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error("host settings unavailable");
    }
  }
  throw lastError || new Error("host settings unavailable");
}

async function saveHostSettings(base: string, setup: HostSetupSettings) {
  let lastError: Error | null = null;
  for (const path of ["/admin/settings", "/admin/save-settings"]) {
    try {
      const response = await fetch(`${base}${path}`, {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: JSON.stringify(hostSettingsPayload(setup)),
      });
      if (response.status === 404) {
        lastError = new Error(`HTTP 404 at ${path}`);
        continue;
      }
      const data = await response.json().catch(() => null) as { ok?: boolean; error?: string } | null;
      if (!response.ok || data?.ok === false) throw new Error(data?.error || `HTTP ${response.status}`);
      return data;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error("save failed");
    }
  }
  throw lastError || new Error("save failed");
}

async function fetchHostPrivacySummary(base: string) {
  const response = await fetch(`${base}/admin/privacy-summary`, { cache: "no-store" });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return await response.json() as HostPrivacySummary;
}

async function fetchHostMemoryShards(base: string) {
  const response = await fetch(`${base}/admin/memory-shards`, { cache: "no-store" });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const data = await response.json() as { shards?: HostMemoryShard[] };
  return Array.isArray(data.shards) ? data.shards : [];
}

async function clearHostPrivacy(base: string, payload: Record<string, boolean>) {
  const response = await fetch(`${base}/admin/privacy-clear`, {
    method: "POST",
    headers: { "Content-Type": "text/plain" },
    body: JSON.stringify(payload),
  });
  const data = await response.json().catch(() => null) as { ok?: boolean; error?: string } | null;
  if (!response.ok || data?.ok === false) throw new Error(data?.error || `HTTP ${response.status}`);
  return data;
}

async function deleteHostMemoryShard(base: string, shard: HostMemoryShard) {
  const response = await fetch(`${base}/admin/memory-shards/delete`, {
    method: "POST",
    headers: { "Content-Type": "text/plain" },
    body: JSON.stringify({ id: shard.id || "", text: shard.text || "" }),
  });
  const data = await response.json().catch(() => null) as { ok?: boolean; error?: string } | null;
  if (!response.ok || data?.ok === false) throw new Error(data?.error || `HTTP ${response.status}`);
  return data;
}

function formatHostRetention(ms?: number) {
  const value = Number(ms) || 0;
  if (value <= 0) return "Never";
  const units: Array<[string, number]> = [
    ["month", 2_592_000_000],
    ["week", 604_800_000],
    ["day", 86_400_000],
    ["hour", 3_600_000],
  ];
  for (const [label, size] of units) {
    if (value >= size && value % size === 0) {
      const count = value / size;
      return `${count} ${label}${count === 1 ? "" : "s"}`;
    }
  }
  return `${Math.round(value / 86_400_000)} days`;
}

function formatHostBytes(bytes?: number) {
  const value = Number(bytes) || 0;
  if (value <= 0) return "0 B";
  if (value < 1024) return `${value} B`;
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`;
  return `${(value / (1024 * 1024)).toFixed(1)} MB`;
}

function hostHealthLabel(value?: boolean, configured?: boolean) {
  if (value) return "connected";
  if (configured) return "configured";
  return "not set";
}

function previewText(value: string) {
  const text = value.replace(/\s+/g, " ").trim();
  return text.length > 42 ? `${text.slice(0, 39)}...` : text;
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
  const [profileOpen, setProfileOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [status, setStatus] = useState<CarolineSocketStatus>("offline");
  const [hostMessages, setHostMessages] = useState<Record<string, ChatMessage[]>>(() => {
    const savedHistory = loadChatHistory();
    return Object.fromEntries(
      settings.hosts.map((host) => [host.id, savedHistory[host.id]?.length ? savedHistory[host.id] : initialMessagesForHost(host)])
    );
  });
  const [buddyStates, setBuddyStates] = useState<Record<string, BuddyState>>(() =>
    Object.fromEntries(settings.hosts.map((host) => [host.id, initialBuddyState(host)]))
  );
  const [draft, setDraft] = useState("");
  const [discoveredHosts, setDiscoveredHosts] = useState<DiscoveredHost[]>([]);
  const [isDiscovering, setIsDiscovering] = useState(false);
  const [isCheckingUpdate, setIsCheckingUpdate] = useState(false);
  const [updateMessage, setUpdateMessage] = useState("");
  const [connectionNonce, setConnectionNonce] = useState(0);
  const [connectionUrls, setConnectionUrls] = useState<Record<string, string>>(() =>
    Object.fromEntries(settings.hosts.map((host) => [host.id, host.socketUrl]))
  );
  const [hostSetup, setHostSetup] = useState<HostSetupSettings>(HOST_SETUP_DEFAULTS);
  const [hostHealth, setHostHealth] = useState<HostHealth | null>(null);
  const [hostSetupStatus, setHostSetupStatus] = useState("");
  const [hostSetupLoadedFrom, setHostSetupLoadedFrom] = useState("");
  const [hostSetupBusy, setHostSetupBusy] = useState(false);
  const [hostPrivacy, setHostPrivacy] = useState<HostPrivacySummary | null>(null);
  const [hostMemoryShards, setHostMemoryShards] = useState<HostMemoryShard[]>([]);
  const [hostPrivacyStatus, setHostPrivacyStatus] = useState("");
  const [hostPrivacyBusy, setHostPrivacyBusy] = useState(false);

  const [clientId] = useState(getOrCreateClientId);

  const settingsRef = useRef(settings);
  const activeHostIdRef = useRef(settings.activeHostId);
  const hostSocketsRef = useRef<Map<string, HostSocketEntry>>(new Map());
  const transcriptRef = useRef<HTMLDivElement | null>(null);
  const hostUserNameRef = useRef("");

  // Apply dark mode to <html> element whenever the setting changes
  useEffect(() => {
    document.documentElement.dataset.theme = settings.darkMode ? "dark" : "light";
  }, [settings.darkMode]);

  useEffect(() => {
    settingsRef.current = settings;
    activeHostIdRef.current = settings.activeHostId;
  }, [settings]);

  useEffect(() => {
    hostUserNameRef.current = hostUserName;
  }, [hostUserName]);

  useEffect(() => {
    saveChatHistory(hostMessages);
  }, [hostMessages]);

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

  const appendHostMessage = useCallback(
    (
      hostId: string,
      message: Omit<ChatMessage, "id"> & { id?: number },
      options: { unread?: boolean; updatePreview?: boolean } = {}
    ) => {
      const nextMessage = { ...message, id: message.id ?? nextMessageId() };
      if (isTaskUpdateNoise(nextMessage) || isCalendarUpdateNoise(nextMessage)) return;

      setHostMessages((previous) => {
        const host = settingsRef.current.hosts.find((candidate) => candidate.id === hostId);
        const current = previous[hostId] || initialMessagesForHost(host);
        return { ...previous, [hostId]: trimChatHistory([...current, nextMessage]) };
      });

      if (options.updatePreview === false) return;

      const shouldUnread = options.unread ?? activeHostIdRef.current !== hostId;
      const sender = nextMessage.sender || (nextMessage.from === "you" ? "You" : nextMessage.from === "system" ? "System" : "Buddy");
      const preview = `${sender}: ${nextMessage.text}`;
      setBuddyStates((previous) => {
        const host = settingsRef.current.hosts.find((candidate) => candidate.id === hostId);
        const current = previous[hostId] || initialBuddyState(host);
        return {
          ...previous,
          [hostId]: {
            ...current,
            unreadCount: shouldUnread ? current.unreadCount + 1 : current.unreadCount,
            lastMessage: preview,
            lastMessageAt: Date.now(),
          },
        };
      });
    },
    []
  );

  const handleHostStatus = useCallback((hostId: string, nextStatus: CarolineSocketStatus) => {
    setBuddyStates((previous) => {
      const host = settingsRef.current.hosts.find((candidate) => candidate.id === hostId);
      const current = previous[hostId] || initialBuddyState(host);
      return { ...previous, [hostId]: { ...current, status: nextStatus } };
    });
    if (activeHostIdRef.current === hostId) setStatus(nextStatus);
  }, []);

  const handleHostMessage = useCallback(
    (hostId: string, msg: CarolineSocketMessage) => {
      if (msg.type === "host_hello") {
        const raw = msg.raw && typeof msg.raw === "object" ? msg.raw as Record<string, unknown> : {};
        const nextName =
          (typeof raw.aiName === "string" ? raw.aiName : null) ??
          (typeof raw.name === "string" ? raw.name : null) ??
          msg.text;
        const nextHostName =
          (typeof raw.hostName === "string" ? raw.hostName : null) ??
          (typeof raw.host === "string" ? raw.host : null);
        const nextDeviceType = normalizeDeviceType(
          (typeof raw.deviceType === "string" ? raw.deviceType : null) ??
          (typeof raw.hostDeviceType === "string" ? raw.hostDeviceType : null) ??
          msg.deviceType
        );
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
        const host = settingsRef.current.hosts.find((candidate) => candidate.id === hostId);
        const resolvedAiName = nextName.trim() || inferBuddyAiName(host);
        const userName = nextUserName?.trim() || hostUserNameRef.current;
        const isActive = activeHostIdRef.current === hostId;
        const resolvedAvatarId = inferAvatarId(resolvedAiName);

        setBuddyStates((previous) => {
          const current = previous[hostId] || initialBuddyState(host);
          return {
            ...previous,
            [hostId]: {
              ...current,
              status: "online",
              aiName: resolvedAiName,
              hostName: nextHostName?.trim() || resolvedAiName || current.hostName,
              deviceType: nextDeviceType || current.deviceType,
              userName: userName || current.userName,
            },
          };
        });

        if (isActive) {
          setAiName(resolvedAiName);
          setStatus("online");
          if (userName) setHostUserName(userName);
        }

        setSettingsRaw((previous) => {
          const settingsHost = previous.hosts.find((candidate) => candidate.id === hostId);
          const hostName = nextHostName?.trim();
          const hosts = previous.hosts.map((candidate) => {
            if (candidate.id !== hostId) return candidate;
            const nextLabel = isAutoHostName(candidate.name)
              ? resolvedAiName || hostName || candidate.name
              : candidate.name;
            return {
              ...candidate,
              name: nextLabel,
              aiName: resolvedAiName,
              avatarId: resolvedAvatarId,
              deviceType: nextDeviceType || candidate.deviceType,
            };
          });
          const profileUserName = userName || previous.userName || hostUserNameRef.current;
          const profile = buildWeeklyAgentProfile({
            aiName: resolvedAiName,
            userName: profileUserName,
            hostProfile: profileText,
            personalityHint,
            previous: previous.agentProfile,
          });
          if (isActive) setAgentProfile(profile);
          const next = {
            ...previous,
            userName: isActive ? previous.userName || profileUserName : previous.userName,
            companionName:
              isActive && shouldAutoNameCompanion(previous.companionName)
                ? companionDisplayName({ ...previous, userName: profileUserName }, profileUserName)
                : previous.companionName,
            hosts,
            agentProfile: isActive ? profile : previous.agentProfile,
            socketUrl: settingsHost?.id === previous.activeHostId ? settingsHost.socketUrl : previous.socketUrl,
          };
          saveSettings(next);
          return next;
        });
        return;
      }

      if (msg.type === "pairing_rejected") {
        appendHostMessage(hostId, {
          from: "system",
          text: "Pairing code was rejected. Check the code on the kiosk screen and try again in Settings.",
        });
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

        appendHostMessage(hostId, {
          from: "user",
          sender,
          source: msg.source,
          text: msg.text,
        });
        return;
      }

      appendHostMessage(hostId, {
        from: msg.role === "system" ? "system" : "caroline",
        sender: msg.role === "system" ? "System" : msg.aiName || inferBuddyAiName(settingsRef.current.hosts.find((host) => host.id === hostId)),
        source: msg.source,
        text: msg.text,
      });
    },
    [appendHostMessage, clientId]
  );

  useEffect(() => {
    const hostIds = new Set(settings.hosts.map((host) => host.id));

    setHostMessages((previous) => {
      let changed = false;
      const next = { ...previous };
      settings.hosts.forEach((host) => {
        if (!next[host.id]) {
          next[host.id] = initialMessagesForHost(host);
          changed = true;
        }
      });
      Object.keys(next).forEach((hostId) => {
        if (!hostIds.has(hostId)) {
          delete next[hostId];
          changed = true;
        }
      });
      return changed ? next : previous;
    });

    setBuddyStates((previous) => {
      let changed = false;
      const next = { ...previous };
      settings.hosts.forEach((host) => {
        if (!next[host.id]) {
          next[host.id] = initialBuddyState(host);
          changed = true;
        }
      });
      Object.keys(next).forEach((hostId) => {
        if (!hostIds.has(hostId)) {
          delete next[hostId];
          changed = true;
        }
      });
      return changed ? next : previous;
    });

    setConnectionUrls((previous) => {
      let changed = false;
      const next = { ...previous };
      settings.hosts.forEach((host) => {
        if (!next[host.id]) {
          next[host.id] = host.socketUrl;
          changed = true;
        }
      });
      Object.keys(next).forEach((hostId) => {
        if (!hostIds.has(hostId)) {
          delete next[hostId];
          changed = true;
        }
      });
      return changed ? next : previous;
    });
  }, [settings.hosts]);

  useEffect(() => {
    settings.hosts.forEach((host) => {
      const connectionUrl = connectionUrls[host.id] || host.socketUrl;
      const signature = hostSocketSignature(connectionUrl);
      const existing = hostSocketsRef.current.get(host.id);
      if (existing && existing.signature !== signature) {
        existing.socket.disconnect();
        hostSocketsRef.current.delete(host.id);
      }
    });

    Array.from(hostSocketsRef.current.entries()).forEach(([hostId, entry]) => {
      if (!settings.hosts.some((host) => host.id === hostId)) {
        entry.socket.disconnect();
        hostSocketsRef.current.delete(hostId);
      }
    });

    settings.hosts.forEach((host) => {
      const connectionUrl = connectionUrls[host.id] || host.socketUrl;
      if (!hasPairingCode(host) || !isUsableSocketUrl(connectionUrl)) {
        hostSocketsRef.current.get(host.id)?.socket.disconnect();
        hostSocketsRef.current.delete(host.id);
        handleHostStatus(host.id, "offline");
        return;
      }

      const signature = hostSocketSignature(connectionUrl);
      if (hostSocketsRef.current.get(host.id)?.signature === signature) return;

      const socket = createCarolineSocket({
        url: connectionUrl.trim(),
        getClient: () => {
          const latest = settingsRef.current;
          const latestHost = latest.hosts.find((candidate) => candidate.id === host.id);
          return {
            clientId,
            displayName: companionDisplayName(latest, hostUserNameRef.current),
            userName: chatUserName(latest, hostUserNameRef.current),
            pairingCode: latestHost?.pairingCode || latest.pairingCode,
          };
        },
        onStatusChange: (nextStatus) => handleHostStatus(host.id, nextStatus),
        onMessage: (msg) => handleHostMessage(host.id, msg),
      });
      hostSocketsRef.current.set(host.id, { signature, socket });
      socket.connect();
    });
  }, [clientId, connectionNonce, connectionUrls, handleHostMessage, handleHostStatus, settings.hosts]);

  useEffect(() => () => {
    hostSocketsRef.current.forEach((entry) => entry.socket.disconnect());
    hostSocketsRef.current.clear();
  }, []);

  const selectedHost = activeHost();
  const selectedBuddyState = selectedHost
    ? buddyStates[selectedHost.id] || initialBuddyState(selectedHost)
    : initialBuddyState();
  const activeStatus = selectedBuddyState.status || status;
  const activeAiName = selectedBuddyState.aiName || aiName;
  const activeDeviceType = inferDeviceTypeForHost(selectedHost, selectedBuddyState);
  const activeHostUserName = selectedBuddyState.userName || hostUserName;
  const activeAvatarId = selectedHost ? avatarIdForHost(selectedHost, selectedBuddyState) : "caroline";
  const messages = selectedHost ? hostMessages[selectedHost.id] || [] : [];
  const activeHostHttpBase = hostHttpBaseFromSocket(selectedHost?.socketUrl || settings.socketUrl);
  const activeHostSecureVoiceUrl = hostSecureVoiceUrlFromBase(activeHostHttpBase);
  const hostSetupBaseAvailable = Boolean(activeHostHttpBase || hostSetupLoadedFrom);
  const hostPrivacyCounts = hostPrivacy?.counts || {};
  const hostPrivacyRetention = hostPrivacy?.retention || {};
  const hostPrivacyIntegrations = Object.entries(hostPrivacy?.integrations || {});
  const hostPrivacyFiles = (hostPrivacy?.files || []).slice(0, 6);
  const buddyHosts = settings.hosts.filter((host) =>
    hasPairingCode(host) || host.id === settings.activeHostId || settings.hosts.length === 1
  );

  // Auto-scroll transcript on new messages
  useEffect(() => {
    transcriptRef.current?.scrollTo({
      top: transcriptRef.current.scrollHeight,
      behavior: "smooth",
    });
  }, [messages]);

  useEffect(() => {
    const current = activeHost();
    setHostHealth(null);
    setHostSetupStatus("");
    setHostSetupLoadedFrom("");
    setHostPrivacy(null);
    setHostMemoryShards([]);
    setHostPrivacyStatus("");
    setHostSetup(normalizeHostSetupSettings({
      ...HOST_SETUP_DEFAULTS,
      userName: settings.userName || activeHostUserName,
      aiName: current?.aiName || inferBuddyAiName(current),
      hostDeviceType: current?.deviceType || "",
    }));
  }, [settings.activeHostId]);

  function handleConnect() {
    const url = settings.socketUrl.trim();
    const current = activeHost();
    if (!current) return;
    if (!url) {
      appendHostMessage(
        current.id,
        { from: "system", text: "Enter this host's WebSocket URL first. The path is usually /ws/caroline." },
        { unread: false }
      );
      return;
    }
    if (url && !/^wss?:\/\//i.test(url)) {
      appendHostMessage(
        current.id,
        { from: "system", text: "WebSocket URL must start with ws:// or wss://" },
        { unread: false }
      );
      return;
    }
    const pairingCode = settings.pairingCode.trim();
    if (!pairingCode) {
      updateActiveHost({ socketUrl: url, pairingCode: "" });
      handleHostStatus(current.id, "offline");
      appendHostMessage(
        current.id,
        { from: "system", text: "Enter this host's SYNC pairing code before connecting." },
        { unread: false }
      );
      return;
    }
    updateActiveHost({ socketUrl: url, pairingCode });
    const entry = hostSocketsRef.current.get(current.id);
    if (entry) {
      entry.socket.disconnect();
      hostSocketsRef.current.delete(current.id);
    }
    if (isUsableSocketUrl(url)) handleHostStatus(current.id, "connecting");
    setConnectionUrls((previous) => ({ ...previous, [current.id]: url }));
    setConnectionNonce((value) => value + 1);
  }

  function handleSelectHost(hostId: string) {
    const host = settings.hosts.find((h) => h.id === hostId);
    if (!host) return;
    const state = buddyStates[host.id] || initialBuddyState(host);
    setSettings({
      ...settings,
      activeHostId: host.id,
      socketUrl: host.socketUrl,
      pairingCode: host.pairingCode,
    });
    setAiName(state.aiName || inferBuddyAiName(host));
    setHostUserName(state.userName || hostUserName);
    setStatus(state.status);
    setBuddyStates((previous) => ({
      ...previous,
      [host.id]: { ...(previous[host.id] || initialBuddyState(host)), unreadCount: 0 },
    }));
  }

  function handleAddHost() {
    const host: SavedHost = {
      id: newHostId(),
      name: "New Buddy",
      socketUrl: settings.socketUrl,
      deviceType: "",
      pairingCode: "",
    };
    setSettings({
      ...settings,
      activeHostId: host.id,
      pairingCode: "",
      hosts: [...settings.hosts, host],
    });
    setHostMessages((previous) => ({ ...previous, [host.id]: initialMessagesForHost(host) }));
    setBuddyStates((previous) => ({ ...previous, [host.id]: initialBuddyState(host) }));
    setConnectionUrls((previous) => ({ ...previous, [host.id]: host.socketUrl }));
    setAiName(inferBuddyAiName(host));
    setStatus("offline");
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
    hostSocketsRef.current.get(settings.activeHostId)?.socket.disconnect();
    hostSocketsRef.current.delete(settings.activeHostId);
    setStatus((buddyStates[nextHost.id] || initialBuddyState(nextHost)).status);
  }

  async function handleDiscoverHosts() {
    setIsDiscovering(true);
    setDiscoveredHosts([]);
    try {
      const hosts = await discoverCarolineHosts(settings.socketUrl);
      setDiscoveredHosts(hosts);
      const current = activeHost();
      if (current) {
        appendHostMessage(
          current.id,
          {
            from: "system",
            text: hosts.length
              ? `Found ${hosts.length} possible Project: Caroline host${hosts.length === 1 ? "" : "s"} on the network.`
              : "No Project: Caroline hosts found. Type the URL manually in Settings.",
          },
          { unread: false }
        );
      }
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
      deviceType: "",
      pairingCode: "",
    };
    const hosts = existing ? settings.hosts : [...settings.hosts, nextHost];
    setSettings({
      ...settings,
      activeHostId: nextHost.id,
      socketUrl: nextHost.socketUrl,
      pairingCode: nextHost.pairingCode,
      hosts,
    });
    if (!existing) {
      setHostMessages((previous) => ({ ...previous, [nextHost.id]: initialMessagesForHost(nextHost) }));
      setBuddyStates((previous) => ({ ...previous, [nextHost.id]: initialBuddyState(nextHost) }));
    }
    setConnectionUrls((previous) => ({ ...previous, [nextHost.id]: nextHost.socketUrl }));
    setAiName(inferBuddyAiName(nextHost));
    setStatus((buddyStates[nextHost.id] || initialBuddyState(nextHost)).status);
    setDiscoveredHosts([]);
  }

  function handleHostSetupField(field: keyof HostSetupSettings, value: string) {
    const nextValue = field === "aiProvider" && value !== "ollama" ? "openrouter" : value;
    setHostSetup((previous) => ({ ...previous, [field]: nextValue } as HostSetupSettings));
  }

  function hostSetupRequestBase() {
    return activeHostHttpBase || hostSetupLoadedFrom;
  }

  async function handleRefreshHostPrivacy() {
    const base = hostSetupRequestBase();
    if (!base) {
      setHostPrivacyStatus("Enter a host address first, then refresh privacy.");
      return;
    }

    setHostPrivacyBusy(true);
    setHostPrivacyStatus("Loading privacy data...");
    try {
      const [summaryResult, memoryResult] = await Promise.allSettled([
        fetchHostPrivacySummary(base),
        fetchHostMemoryShards(base),
      ]);

      if (summaryResult.status === "fulfilled") setHostPrivacy(summaryResult.value);
      else throw summaryResult.reason;

      if (memoryResult.status === "fulfilled") setHostMemoryShards(memoryResult.value);
      setHostPrivacyStatus("Privacy data loaded.");
    } catch (error) {
      const message = error instanceof Error ? error.message : "privacy data unavailable";
      setHostPrivacyStatus(`Could not load privacy data: ${message}`);
    } finally {
      setHostPrivacyBusy(false);
    }
  }

  async function handleClearHostPrivacy(payload: Record<string, boolean>, label: string) {
    const base = hostSetupRequestBase();
    if (!base) {
      setHostPrivacyStatus("Enter a host address first, then clear privacy data.");
      return;
    }
    const confirmed = window.confirm(`${label}? This changes the connected Caroline host.`);
    if (!confirmed) return;

    setHostPrivacyBusy(true);
    setHostPrivacyStatus(`${label}...`);
    try {
      await clearHostPrivacy(base, payload);
      await handleRefreshHostPrivacy();
      setHostPrivacyStatus(`${label} complete.`);
    } catch (error) {
      const message = error instanceof Error ? error.message : "clear failed";
      setHostPrivacyStatus(`${label} failed: ${message}`);
    } finally {
      setHostPrivacyBusy(false);
    }
  }

  async function handleDeleteHostMemoryShard(shard: HostMemoryShard) {
    const base = hostSetupRequestBase();
    if (!base || !shard.text) return;
    const confirmed = window.confirm(`Delete this memory shard?\n\n${shard.text}`);
    if (!confirmed) return;

    setHostPrivacyBusy(true);
    setHostPrivacyStatus("Deleting memory shard...");
    try {
      await deleteHostMemoryShard(base, shard);
      await handleRefreshHostPrivacy();
      setHostPrivacyStatus("Memory shard deleted.");
    } catch (error) {
      const message = error instanceof Error ? error.message : "delete failed";
      setHostPrivacyStatus(`Memory delete failed: ${message}`);
    } finally {
      setHostPrivacyBusy(false);
    }
  }

  async function handleLoadHostSetup() {
    const base = hostSetupRequestBase();
    if (!base) {
      setHostSetupStatus("Enter a host address first, then load setup.");
      return;
    }

    setHostSetupBusy(true);
    setHostSetupStatus("Loading host setup...");
    try {
      const [settingsResult, healthResult] = await Promise.allSettled([
        fetchHostSettings(base),
        fetch(`${base}/health`, { cache: "no-store" }),
      ]);

      if (healthResult.status === "fulfilled" && healthResult.value.ok) {
        setHostHealth(await healthResult.value.json() as HostHealth);
      }

      if (settingsResult.status === "rejected") throw settingsResult.reason;
      const loaded = normalizeHostSetupSettings(await settingsResult.value.json());
      setHostSetup(loaded);
      setHostSetupLoadedFrom(base);
      setHostSetupStatus("Host setup loaded.");
      await handleRefreshHostPrivacy();

      const current = activeHost();
      if (current && loaded.aiName) {
        const deviceType = normalizeDeviceType(loaded.hostDeviceType);
        const hosts = settings.hosts.map((host) =>
          host.id === current.id
            ? {
                ...host,
                aiName: loaded.aiName,
                avatarId: inferAvatarId(loaded.aiName),
                deviceType: deviceType || host.deviceType,
              }
            : host
        );
        setSettings({ ...settings, userName: loaded.userName || settings.userName, hosts });
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : "host setup unavailable";
      setHostSetupStatus(`Could not load host setup: ${message}`);
    } finally {
      setHostSetupBusy(false);
    }
  }

  async function handleSaveHostSetup() {
    const base = hostSetupRequestBase();
    if (!base) {
      setHostSetupStatus("Enter a host address first, then save setup.");
      return;
    }

    setHostSetupBusy(true);
    setHostSetupStatus("Saving host setup...");
    try {
      await saveHostSettings(base, hostSetup);

      const current = activeHost();
      if (current) {
        const deviceType = normalizeDeviceType(hostSetup.hostDeviceType);
        const hosts = settings.hosts.map((host) =>
          host.id === current.id
            ? {
                ...host,
                aiName: hostSetup.aiName || host.aiName,
                name: host.name || hostSetup.aiName || "Project: Caroline",
                avatarId: inferAvatarId(hostSetup.aiName || host.aiName || host.name),
                deviceType: deviceType || host.deviceType,
              }
            : host
        );
        setSettings({ ...settings, userName: hostSetup.userName || settings.userName, hosts });
      }

      setHostSetupLoadedFrom(base);
      setHostSetupStatus("Saved to host.");
      await handleLoadHostSetup();
    } catch (error) {
      const message = error instanceof Error ? error.message : "save failed";
      setHostSetupStatus(`Could not save host setup: ${message}`);
    } finally {
      setHostSetupBusy(false);
    }
  }

  function openExternalUrl(url: string) {
    if (!url) return;
    window.open(url, "_blank", "noopener,noreferrer");
  }

  async function handleCheckClientUpdates() {
    setIsCheckingUpdate(true);
    setUpdateMessage("Checking companion updates...");

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
    const current = activeHost();
    if (!current) return;

    appendHostMessage(
      current.id,
      { from: "you", sender: chatUserName(settings, activeHostUserName), text },
      { unread: false }
    );
    setDraft("");

    if (!hostSocketsRef.current.get(current.id)?.socket.send(text)) {
      appendHostMessage(
        current.id,
        {
          from: "system",
          text: "Project: Caroline is offline. Open Settings (⚙), enter the WebSocket URL, and click Connect.",
        },
        { unread: false }
      );
    }
  }

  function handleDeleteAllChats() {
    const confirmed = window.confirm("Delete all companion chat history saved on this computer?");
    if (!confirmed) return;

    deleteChatHistory();
    setHostMessages(resetMessagesForHosts(settings.hosts));
    setBuddyStates((previous) =>
      Object.fromEntries(
        settings.hosts.map((host) => {
          const current = previous[host.id] || initialBuddyState(host);
          return [
            host.id,
            {
              ...current,
              unreadCount: 0,
              lastMessage: "",
              lastMessageAt: 0,
            },
          ];
        })
      )
    );
  }

  const isOnline = activeStatus === "online";
  const darkModeButtonLabel = settings.darkMode ? "Switch to light mode" : "Switch to dark mode";

  function showProfilePanel() {
    setSettingsOpen(false);
    setProfileOpen(true);
  }

  function toggleSettingsPanel() {
    setSettingsOpen((open) => {
      const nextOpen = !open;
      if (nextOpen) setProfileOpen(false);
      return nextOpen;
    });
  }

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
              aria-label={darkModeButtonLabel}
              title={darkModeButtonLabel}
            >
              {settings.darkMode ? "☀" : "☾"}
            </button>
            <button
              type="button"
              className={`settings-btn${settingsOpen ? " active" : ""}`}
              onClick={toggleSettingsPanel}
              aria-label={settingsOpen ? "Close settings" : "Open settings"}
              title="Settings"
            >
              ⚙
            </button>
          </div>
        </header>

        {/* ── Status row ────────────────────────────────────── */}
        <div className="status-row">
          <span className={`status-light ${activeStatus}`} />
          <span>{statusLabel(activeStatus, activeAiName)}</span>
        </div>

        {/* ── Settings panel (shown when settingsOpen) ──────── */}
        {settingsOpen && (
          <section className="settings-panel" aria-label="Settings">

            <div className="settings-group settings-group-wide">
              <label htmlFor="saved-host">Saved Buddy</label>
              <div className="settings-row">
                <select
                  id="saved-host"
                  value={settings.activeHostId}
                  onChange={(e) => handleSelectHost(e.target.value)}
                >
                  {settings.hosts.map((host) => (
                    <option value={host.id} key={host.id}>
                      {buddyDisplayName(host, buddyStates[host.id])}
                      {inferDeviceTypeForHost(host, buddyStates[host.id]) ? ` (${inferDeviceTypeForHost(host, buddyStates[host.id])})` : ""}
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
              <label htmlFor="host-ai-name">Buddy Name</label>
              <input
                id="host-ai-name"
                value={activeHost()?.aiName || inferBuddyAiName(activeHost())}
                onChange={(e) => updateActiveHost({ aiName: e.target.value, avatarId: inferAvatarId(e.target.value) })}
              />
            </div>

            <div className="settings-group">
              <label htmlFor="user-name">Your Name</label>
              <input
                id="user-name"
                value={settings.userName || activeHostUserName}
                onChange={(e) => setSettings({ ...settings, userName: e.target.value })}
                placeholder="Dave"
              />
            </div>

            <div className="settings-group">
              <label htmlFor="pairing-code">
                SYNC Code{" "}
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

            <div className="settings-group">
              <label htmlFor="socket-url">Host Address</label>
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
              <label htmlFor="host-device-type">Device</label>
              <select
                id="host-device-type"
                value={activeHost()?.deviceType || ""}
                onChange={(e) => updateActiveHost({ deviceType: normalizeDeviceType(e.target.value) })}
              >
                {HOST_DEVICE_TYPES.map((deviceType) => (
                  <option value={deviceType} key={deviceType || "unknown"}>
                    {deviceType || "Unknown"}
                  </option>
                ))}
              </select>
            </div>

            <details className="settings-advanced host-setup-panel" open>
              <summary>Host Setup Hub</summary>
              <div className="host-setup-body">
                <div className="host-setup-actions">
                  <button type="button" onClick={handleLoadHostSetup} disabled={hostSetupBusy || !hostSetupBaseAvailable}>
                    {hostSetupBusy ? "Working..." : "Load From Host"}
                  </button>
                  <button type="button" onClick={handleSaveHostSetup} disabled={hostSetupBusy || !hostSetupBaseAvailable}>
                    Save To Host
                  </button>
                  <button type="button" onClick={() => openExternalUrl(activeHostHttpBase)} disabled={!activeHostHttpBase}>
                    Open Host UI
                  </button>
                  <button type="button" onClick={() => openExternalUrl(activeHostSecureVoiceUrl)} disabled={!activeHostSecureVoiceUrl}>
                    Secure Voice
                  </button>
                </div>

                <div className="host-setup-status-row">
                  <span>{activeHostHttpBase || "No host address yet"}</span>
                  {hostSetupStatus && <strong>{hostSetupStatus}</strong>}
                </div>

                {hostHealth && (
                  <div className="host-health-list" aria-label="Host integration status">
                    <span className="host-health-chip">AI: {hostHealth.aiProvider || hostSetup.aiProvider}</span>
                    <span className="host-health-chip">Model: {hostHealth.ollamaModel || hostHealth.aiModel || (hostSetup.aiProvider === "ollama" ? hostSetup.ollamaModel : hostSetup.aiModel)}</span>
                    <span className="host-health-chip">Google: {hostHealthLabel(hostHealth.google?.connected || hostHealth.google?.serviceAccountConfigured, hostHealth.google?.clientConfigured || hostHealth.google?.hasClientSecret)}</span>
                    <span className="host-health-chip">Spotify: {hostHealthLabel(hostHealth.spotify?.connected, hostHealth.spotify?.clientConfigured)}</span>
                    <span className="host-health-chip">Calendar: {hostHealthLabel(hostHealth.calendar?.configured, hostHealth.google?.connected)}</span>
                    <span className="host-health-chip">Hue: {hostHealthLabel(hostHealth.hue?.configured, hostHealth.hue?.configured)}</span>
                    <span className="host-health-chip">Discord: {hostHealthLabel(hostHealth.discord?.configured, hostHealth.discord?.enabled || hostHealth.discord?.channelConfigured)}</span>
                  </div>
                )}

                <div className="host-privacy-panel">
                  <div className="host-setup-section-title">Privacy</div>
                  <div className="host-privacy-actions">
                    <button type="button" onClick={handleRefreshHostPrivacy} disabled={hostPrivacyBusy || !hostSetupBaseAvailable}>
                      {hostPrivacyBusy ? "Working..." : "Refresh Privacy"}
                    </button>
                    <button type="button" onClick={() => handleClearHostPrivacy({ history: true }, "Clear host chat")} disabled={hostPrivacyBusy || !hostSetupBaseAvailable}>
                      Clear Chat
                    </button>
                    <button type="button" onClick={() => handleClearHostPrivacy({ memory: true }, "Clear host memory")} disabled={hostPrivacyBusy || !hostSetupBaseAvailable}>
                      Clear Memory
                    </button>
                    <button type="button" onClick={() => handleClearHostPrivacy({ history: true, memory: true, profile: true }, "Reset host privacy data")} disabled={hostPrivacyBusy || !hostSetupBaseAvailable}>
                      Reset Privacy
                    </button>
                  </div>

                  <div className="host-privacy-status">
                    {hostPrivacyStatus || (hostPrivacy ? "Host privacy data loaded." : "Load host setup or refresh privacy to view host data.")}
                  </div>

                  <div className="host-privacy-stats">
                    <span><strong>{hostPrivacyCounts.chatMessages || 0}</strong> chat</span>
                    <span><strong>{hostPrivacyCounts.memoryShards || 0}</strong> memory</span>
                    <span><strong>{hostPrivacyCounts.tasks || 0}</strong> tasks</span>
                    <span><strong>{hostPrivacyRetention.privacyMode ? "Private" : "Normal"}</strong> mode</span>
                    <span><strong>{formatHostRetention(hostPrivacyRetention.historyRetentionMs)}</strong> chat TTL</span>
                    <span><strong>{formatHostRetention(hostPrivacyRetention.memoryRetentionMs)}</strong> memory TTL</span>
                  </div>

                  {hostPrivacyIntegrations.length > 0 && (
                    <div className="host-health-list" aria-label="Host privacy integration status">
                      {hostPrivacyIntegrations.map(([key, info]) => {
                        const enabled = info.enabled !== false;
                        const state = !enabled ? "off" : (info.connected ? "connected" : (info.configured ? "configured" : "off"));
                        return (
                          <span className="host-health-chip" key={`privacy-${key}`}>
                            {info.label || key}: {state}{info.model ? ` / ${info.model}` : ""}
                          </span>
                        );
                      })}
                    </div>
                  )}

                  {hostPrivacyFiles.length > 0 && (
                    <div className="host-privacy-files">
                      {hostPrivacyFiles.map((file) => (
                        <div className="host-privacy-file" key={`${file.label || "file"}-${file.path || ""}`}>
                          <span>{file.label || "Host file"}</span>
                          <code>{file.path || "unknown path"}</code>
                          <em>{file.exists ? formatHostBytes(file.bytes) : "empty"}</em>
                        </div>
                      ))}
                    </div>
                  )}

                  <div className="host-memory-list">
                    {hostMemoryShards.slice(0, 6).map((shard) => (
                      <div className="host-memory-item" key={shard.id || shard.text}>
                        <span>{shard.text || "Untitled memory"}</span>
                        <button type="button" onClick={() => handleDeleteHostMemoryShard(shard)} disabled={hostPrivacyBusy}>
                          Delete
                        </button>
                      </div>
                    ))}
                    {hostMemoryShards.length === 0 && <div className="host-memory-empty">No host memory shards loaded.</div>}
                  </div>
                </div>

                <div className="host-setup-grid">
                  <div className="host-setup-section-title">Identity</div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-user-name">Your Name</label>
                    <input
                      id="host-setup-user-name"
                      value={hostSetup.userName}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("userName", e.target.value)}
                      placeholder="Dave"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-ai-name">Buddy Name</label>
                    <input
                      id="host-setup-ai-name"
                      value={hostSetup.aiName}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("aiName", e.target.value)}
                      placeholder="Caroline"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-device-type">Host Device</label>
                    <select
                      id="host-setup-device-type"
                      value={normalizeDeviceType(hostSetup.hostDeviceType)}
                      onChange={(e: ChangeEvent<HTMLSelectElement>) => handleHostSetupField("hostDeviceType", e.target.value)}
                    >
                      {HOST_DEVICE_TYPES.map((deviceType) => (
                        <option value={deviceType} key={`host-setup-${deviceType || "unknown"}`}>
                          {deviceType || "Unknown"}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div className="host-setup-section-title">Place & Time</div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-timezone">Timezone</label>
                    <input
                      id="host-setup-timezone"
                      value={hostSetup.timezone}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("timezone", e.target.value)}
                      placeholder="America/Los_Angeles"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-location">Location</label>
                    <input
                      id="host-setup-location"
                      value={hostSetup.location}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("location", e.target.value)}
                      placeholder="Chula Vista, CA"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-city">City</label>
                    <input
                      id="host-setup-city"
                      value={hostSetup.cityName}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("cityName", e.target.value)}
                      placeholder="Chula Vista"
                    />
                  </div>

                  <div className="host-setup-section-title">AI</div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-provider">AI Provider</label>
                    <select
                      id="host-setup-provider"
                      value={hostSetup.aiProvider}
                      onChange={(e: ChangeEvent<HTMLSelectElement>) => handleHostSetupField("aiProvider", e.target.value)}
                    >
                      <option value="openrouter">OpenRouter</option>
                      <option value="ollama">Ollama</option>
                    </select>
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-ai-model">Cloud Model</label>
                    <input
                      id="host-setup-ai-model"
                      value={hostSetup.aiModel}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("aiModel", e.target.value)}
                      placeholder="anthropic/claude-haiku-4.5"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-ollama-url">Ollama URL</label>
                    <input
                      id="host-setup-ollama-url"
                      value={hostSetup.ollamaUrl}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("ollamaUrl", e.target.value)}
                      placeholder="http://localhost:11434"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-ollama-model">Ollama Model</label>
                    <input
                      id="host-setup-ollama-model"
                      value={hostSetup.ollamaModel}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("ollamaModel", e.target.value)}
                      placeholder="qwen2.5:1.5b"
                    />
                  </div>

                  <div className="host-setup-section-title">Integrations</div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-spotify">Spotify Client ID</label>
                    <input
                      id="host-setup-spotify"
                      value={hostSetup.spotifyClientId}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("spotifyClientId", e.target.value)}
                      placeholder="Optional custom app"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-google">Google Client ID</label>
                    <input
                      id="host-setup-google"
                      value={hostSetup.googleClientId}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("googleClientId", e.target.value)}
                      placeholder="OAuth client ID"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-google-redirect">Google Redirect URI</label>
                    <input
                      id="host-setup-google-redirect"
                      value={hostSetup.googleRedirectUri}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("googleRedirectUri", e.target.value)}
                      placeholder="http://127.0.0.1:1880/admin/google/callback"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-calendar">Read Calendar</label>
                    <input
                      id="host-setup-calendar"
                      value={hostSetup.calendarId}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("calendarId", e.target.value)}
                      placeholder="primary"
                    />
                  </div>

                  <div className="settings-group">
                    <label htmlFor="host-setup-write-calendar">Write Calendar</label>
                    <input
                      id="host-setup-write-calendar"
                      value={hostSetup.defaultWriteCalendarId}
                      onChange={(e: ChangeEvent<HTMLInputElement>) => handleHostSetupField("defaultWriteCalendarId", e.target.value)}
                      placeholder="primary"
                    />
                  </div>
                </div>
              </div>
            </details>

            <div className="settings-group settings-toggle-row">
              <label htmlFor="dark-mode">Dark Mode</label>
              <input
                id="dark-mode"
                type="checkbox"
                checked={settings.darkMode}
                onChange={(e) => setSettings({ ...settings, darkMode: e.target.checked })}
              />
            </div>

            <div className="settings-group settings-group-wide">
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

            <details className="settings-advanced">
              <summary>More host details</summary>
              <div className="settings-advanced-grid">
                <div className="settings-group">
                  <label htmlFor="host-name">Host Label</label>
                  <input
                    id="host-name"
                    value={activeHost()?.name || ""}
                    onChange={(e) => updateActiveHost({ name: e.target.value })}
                  />
                </div>

                <div className="settings-group">
                  <label htmlFor="host-avatar-id">Buddy Avatar</label>
                  <select
                    id="host-avatar-id"
                    value={activeAvatarId}
                    onChange={(e) => updateActiveHost({ avatarId: e.target.value })}
                  >
                    <option value="caroline">Caroline</option>
                    <option value="carl">Carl</option>
                    <option value="catoline">Catoline</option>
                    <option value="robot">Robot</option>
                  </select>
                </div>

                <div className="settings-group settings-group-wide">
                  <label htmlFor="companion-name">Client Display Name</label>
                  <input
                    id="companion-name"
                    value={settings.companionName}
                    onChange={(e) => setSettings({ ...settings, companionName: e.target.value })}
                    placeholder={`${chatUserName(settings, activeHostUserName)}'s Companion`}
                  />
                  <p className="settings-note">Shown to the host when this computer connects.</p>
                </div>
              </div>
            </details>

            <details className="settings-advanced">
              <summary>Maintenance & privacy</summary>
              <div className="settings-advanced-grid">
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

                <div className="settings-group">
                  <button
                    type="button"
                    className="full-width-btn danger-btn"
                    onClick={handleDeleteAllChats}
                  >
                    Delete All Chats
                  </button>
                  <p className="settings-note">Clears saved companion transcripts and unread counts on this computer.</p>
                </div>
              </div>
            </details>

          </section>
        )}

        {/* ── Chat area ─────────────────────────────────────── */}
        <section className="chat-shell">
          <aside className="buddy-list" aria-label="Buddy list">
            <div className="buddy-heading">Buddies</div>
            {buddyHosts.map((host) => {
              const state = buddyStates[host.id] || initialBuddyState(host);
              const displayName = buddyDisplayName(host, state);
              const deviceType = inferDeviceTypeForHost(host, state);
              const selected = host.id === settings.activeHostId;
              const avatarId = avatarIdForHost(host, state);
              const avatar = buddyAvatarSrc(avatarId, state.status === "online");
              return (
                <button
                  type="button"
                  className={`buddy buddy-button ${selected ? "active" : ""} ${state.status} ${state.unreadCount ? "unread" : ""}`}
                  key={host.id}
                  onClick={() => handleSelectHost(host.id)}
                  title={host.socketUrl}
                >
                  <img
                    src={avatar}
                    alt={displayName}
                    className="buddy-avatar"
                    width={32}
                    height={32}
                  />
                  <div className="buddy-copy">
                    <strong>{displayName}</strong>
                    <small>{buddyStatusText(state.status)}{deviceType ? ` · ${deviceType}` : ""}</small>
                    {state.lastMessage && <em>{previewText(state.lastMessage)}</em>}
                  </div>
                  {state.unreadCount > 0 && (
                    <span className="buddy-unread" aria-label={`${state.unreadCount} unread message${state.unreadCount === 1 ? "" : "s"}`}>
                      {state.unreadCount > 9 ? "9+" : state.unreadCount}
                    </span>
                  )}
                </button>
              );
            })}
            <button
              type="button"
              className="buddy-profile-btn"
              onClick={showProfilePanel}
            >
              Buddy Info
            </button>
          </aside>

          <div className="chat-panel">
            {profileOpen && (
              <section
                className={`profile-window profile-theme-${agentProfile.theme || "midnight"}`}
                aria-label={`${activeAiName} buddy info`}
              >
                <header className="profile-title">
                  <span className="profile-presence-chip" />
                  <strong>Buddy Info:</strong>
                  <input value={agentProfile.screenName || activeAiName} readOnly aria-label="Generated screen name" />
                  <button type="button" disabled>
                    OK
                  </button>
                  <button type="button" onClick={() => setProfileOpen(false)}>
                    Close
                  </button>
                </header>
                <div className="profile-stats">
                  <p>
                    <strong>Device:</strong> {deviceTypeLabel(activeDeviceType)}
                  </p>
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
                    <div className="profile-kicker">{agentProfile.screenName || activeAiName}</div>
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
                        ? chatUserName(settings, activeHostUserName)
                        : msg.from === "caroline"
                        ? activeAiName
                        : msg.from === "user"
                        ? activeHostUserName || "You"
                        : "System")}
                  </span>
                  <p>{msg.text}</p>
                </article>
              ))}
            </div>

            <div className="action-strip" aria-label="Chat actions">
              <button type="button" onClick={showProfilePanel} className={profileOpen && !settingsOpen ? "active" : ""}>
                Profile
              </button>
              <button type="button" onClick={toggleSettingsPanel} className={settingsOpen ? "active" : ""}>
                Settings
              </button>
              <button type="button" onClick={handleCheckClientUpdates} disabled={isCheckingUpdate}>
                {isCheckingUpdate ? "Checking..." : "Updates"}
              </button>
            </div>
            {updateMessage && !settingsOpen && (
              <p className="update-status" role="status">
                {updateMessage}
              </p>
            )}

            <form className="compose" onSubmit={handleSubmit}>
              <input
                aria-label={`Message ${activeAiName}`}
                placeholder={isOnline ? "Type a message..." : `${activeAiName} is offline...`}
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
