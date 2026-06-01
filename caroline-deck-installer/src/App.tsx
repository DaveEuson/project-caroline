import { useEffect, useMemo, useState } from "react";
import { invoke } from "@tauri-apps/api/core";

type DeckStatus = {
  isSteamOsLike: boolean;
  osName: string;
  userName: string;
  homeDir: string;
  carolineDirExists: boolean;
  serviceState: string;
  ollamaState: string;
  version: string;
  commit: string;
  channel: string;
  lanUrl: string;
  localUrl: string;
  launchersReady: boolean;
};

type DeckOptions = {
  action: "install" | "update" | "repair" | "uninstall";
  channel: "release" | "nightly";
  aiMode: "cloud" | "local";
  installOllama: boolean;
  ollamaModel: string;
  lanAccess: boolean;
  keepData: boolean;
};

type ActionResult = {
  ok: boolean;
  output: string;
};

const DEFAULT_STATUS: DeckStatus = {
  isSteamOsLike: false,
  osName: "Checking...",
  userName: "",
  homeDir: "",
  carolineDirExists: false,
  serviceState: "unknown",
  ollamaState: "unknown",
  version: "",
  commit: "",
  channel: "",
  lanUrl: "",
  localUrl: "http://localhost:8080/",
  launchersReady: false
};

const DEFAULT_OPTIONS: DeckOptions = {
  action: "install",
  channel: "release",
  aiMode: "cloud",
  installOllama: false,
  ollamaModel: "qwen3:1.7b",
  lanAccess: false,
  keepData: true
};

const ACTIONS: Array<{
  id: DeckOptions["action"];
  title: string;
  detail: string;
  tone?: "danger";
}> = [
  { id: "install", title: "Install", detail: "Fresh guided setup for this Deck." },
  { id: "update", title: "Update", detail: "Move an existing install to the selected channel." },
  { id: "repair", title: "Repair", detail: "Re-run setup while preserving settings." },
  { id: "uninstall", title: "Uninstall", detail: "Remove launchers and service files.", tone: "danger" }
];

const STEPS = ["Check Deck", "Download Installer", "Apply Choices", "Restart Service", "Verify Launchers"];

function statusTone(state: string) {
  if (/active|running|ready|installed/i.test(state)) return "good";
  if (/inactive|missing|not installed|unknown/i.test(state)) return "warn";
  return "bad";
}

function line(label: string, value: string | boolean) {
  return (
    <div className="spec-line">
      <span>{label}</span>
      <strong>{typeof value === "boolean" ? (value ? "Yes" : "No") : value || "--"}</strong>
    </div>
  );
}

export default function App() {
  const [status, setStatus] = useState<DeckStatus>(DEFAULT_STATUS);
  const [options, setOptions] = useState<DeckOptions>(DEFAULT_OPTIONS);
  const [running, setRunning] = useState(false);
  const [activeStep, setActiveStep] = useState(0);
  const [log, setLog] = useState("Ready. Pick an action and Caroline will handle the Deck-side setup.");
  const [lastResult, setLastResult] = useState<"ok" | "bad" | "idle">("idle");

  const selectedAction = useMemo(
    () => ACTIONS.find(action => action.id === options.action) || ACTIONS[0],
    [options.action]
  );

  async function refreshStatus() {
    try {
      const next = await invoke<DeckStatus>("deck_status");
      setStatus(next);
    } catch (error) {
      setLog(String(error));
      setLastResult("bad");
    }
  }

  useEffect(() => {
    refreshStatus();
  }, []);

  useEffect(() => {
    if (!running) return;
    const timer = window.setInterval(() => {
      setActiveStep(step => Math.min(step + 1, STEPS.length - 1));
    }, 1800);
    return () => window.clearInterval(timer);
  }, [running]);

  async function runAction() {
    setRunning(true);
    setLastResult("idle");
    setActiveStep(0);
    setLog(`Starting ${selectedAction.title.toLowerCase()} on channel ${options.channel}...\n`);
    try {
      const result = await invoke<ActionResult>("run_deck_action", { options });
      setLog(result.output || "Action completed.");
      setLastResult(result.ok ? "ok" : "bad");
      await refreshStatus();
    } catch (error) {
      setLog(String(error));
      setLastResult("bad");
    } finally {
      setRunning(false);
      setActiveStep(STEPS.length - 1);
    }
  }

  async function openTarget(kind: "windowed" | "kiosk") {
    try {
      const result = await invoke<ActionResult>("open_caroline", { kind });
      setLog(result.output || `Open ${kind} requested.`);
      setLastResult(result.ok ? "ok" : "bad");
    } catch (error) {
      setLog(String(error));
      setLastResult("bad");
    }
  }

  return (
    <main className="deck-shell">
      <section className="hero-panel">
        <div>
          <p className="terminal-label">// Project: Caroline Deck Installer</p>
          <h1>Set up Project: Caroline on Steam Deck</h1>
          <p className="hero-copy">
            Install, repair, update, or remove the SteamOS host without typing shell commands.
          </p>
        </div>
        <div className={`status-chip ${status.isSteamOsLike ? "good" : "warn"}`}>
          {status.isSteamOsLike ? "Deck Ready" : "Deck Check"}
        </div>
      </section>

      <section className="grid">
        <div className="panel actions-panel">
          <div className="panel-head">
            <span>01 Action</span>
            <button type="button" onClick={refreshStatus} disabled={running}>Refresh</button>
          </div>
          <div className="action-grid">
            {ACTIONS.map(action => (
              <button
                key={action.id}
                type="button"
                className={`action-card ${options.action === action.id ? "selected" : ""} ${action.tone || ""}`}
                onClick={() => setOptions(current => ({ ...current, action: action.id }))}
                disabled={running}
              >
                <strong>{action.title}</strong>
                <span>{action.detail}</span>
              </button>
            ))}
          </div>

          <div className="option-row">
            <label>
              Channel
              <select
                value={options.channel}
                onChange={event => setOptions(current => ({ ...current, channel: event.target.value as DeckOptions["channel"] }))}
                disabled={running}
              >
                <option value="release">release</option>
                <option value="nightly">nightly</option>
              </select>
            </label>
            <label>
              AI Mode
              <select
                value={options.aiMode}
                onChange={event => {
                  const aiMode = event.target.value as DeckOptions["aiMode"];
                  setOptions(current => ({ ...current, aiMode, installOllama: aiMode === "local" ? current.installOllama : false }));
                }}
                disabled={running}
              >
                <option value="cloud">OpenRouter cloud</option>
                <option value="local">Ollama local</option>
              </select>
            </label>
          </div>

          <div className="toggle-list">
            <label className="toggle-line">
              <input
                type="checkbox"
                checked={options.lanAccess}
                onChange={event => setOptions(current => ({ ...current, lanAccess: event.target.checked }))}
                disabled={running}
              />
              <span>Allow phone and companion access on trusted LAN</span>
            </label>
            <label className="toggle-line">
              <input
                type="checkbox"
                checked={options.aiMode === "local" && options.installOllama}
                onChange={event => setOptions(current => ({ ...current, aiMode: event.target.checked ? "local" : current.aiMode, installOllama: event.target.checked }))}
                disabled={running}
              />
              <span>Install Ollama and pull qwen3:1.7b</span>
            </label>
            <label className="toggle-line">
              <input
                type="checkbox"
                checked={options.keepData}
                onChange={event => setOptions(current => ({ ...current, keepData: event.target.checked }))}
                disabled={running || options.action !== "uninstall"}
              />
              <span>Keep chat, settings, OAuth, and memory on uninstall</span>
            </label>
          </div>

          <button type="button" className="primary-run" onClick={runAction} disabled={running}>
            {running ? "Working..." : `${selectedAction.title} Project: Caroline`}
          </button>
        </div>

        <div className="panel status-panel">
          <div className="panel-head">
            <span>02 Deck Status</span>
            <span className={`mini-state ${statusTone(status.serviceState)}`}>{status.serviceState || "unknown"}</span>
          </div>
          {line("OS", status.osName)}
          {line("User", status.userName)}
          {line("Install", status.carolineDirExists ? "Installed" : "Not installed")}
          {line("Version", [status.version, status.commit].filter(Boolean).join(" @ "))}
          {line("Channel", status.channel)}
          {line("Ollama", status.ollamaState)}
          {line("Launchers", status.launchersReady)}
          {line("Local URL", status.localUrl)}
          {status.lanUrl ? line("LAN URL", status.lanUrl) : null}
          <div className="quick-open">
            <button type="button" onClick={() => openTarget("windowed")} disabled={running}>Open Caroline</button>
            <button type="button" onClick={() => openTarget("kiosk")} disabled={running}>Open Kiosk</button>
          </div>
        </div>
      </section>

      <section className="panel progress-panel">
        <div className="panel-head">
          <span>03 Progress</span>
          <span className={`mini-state ${lastResult}`}>{lastResult === "idle" ? "ready" : lastResult === "ok" ? "complete" : "needs attention"}</span>
        </div>
        <div className="step-row">
          {STEPS.map((step, index) => (
            <div key={step} className={`step ${index < activeStep ? "done" : ""} ${index === activeStep ? "active" : ""}`}>
              <span>{String(index + 1).padStart(2, "0")}</span>
              {step}
            </div>
          ))}
        </div>
        <pre className="log-output">{log}</pre>
      </section>

      <section className="panel gaming-panel">
        <div className="panel-head">
          <span>04 Gaming Mode</span>
          <span className="mini-state good">next</span>
        </div>
        <p>
          After install, add <strong>Project: Caroline Kiosk</strong> as a non-Steam game from Steam Desktop Mode.
          The kiosk includes controller navigation and a Steam Hub for Library shortcuts, Downloads, and trusted launch tiles.
        </p>
      </section>
    </main>
  );
}
