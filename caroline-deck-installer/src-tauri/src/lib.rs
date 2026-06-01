use serde::{Deserialize, Serialize};
use std::{
    env,
    fs,
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DeckStatus {
    is_steam_os_like: bool,
    os_name: String,
    user_name: String,
    home_dir: String,
    caroline_dir_exists: bool,
    service_state: String,
    ollama_state: String,
    version: String,
    commit: String,
    channel: String,
    lan_url: String,
    local_url: String,
    launchers_ready: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DeckActionOptions {
    action: String,
    channel: String,
    ai_mode: String,
    install_ollama: bool,
    ollama_model: String,
    lan_access: bool,
    keep_data: bool,
}

#[derive(Debug, Serialize)]
struct ActionResult {
    ok: bool,
    output: String,
}

fn home_dir() -> PathBuf {
    env::var("HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from("."))
}

fn run_capture(program: &str, args: &[&str]) -> String {
    Command::new(program)
        .args(args)
        .output()
        .map(|out| {
            let mut text = String::from_utf8_lossy(&out.stdout).to_string();
            text.push_str(&String::from_utf8_lossy(&out.stderr));
            text.trim().to_string()
        })
        .unwrap_or_default()
}

fn os_release() -> String {
    fs::read_to_string("/etc/os-release").unwrap_or_default()
}

fn os_pretty_name(os: &str) -> String {
    os.lines()
        .find_map(|line| line.strip_prefix("PRETTY_NAME="))
        .map(|value| value.trim_matches('"').to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| env::consts::OS.to_string())
}

fn is_steam_os_like(os: &str) -> bool {
    let low = os.to_lowercase();
    low.contains("steamos") || low.contains("bazzite") || low.contains("steam deck")
}

fn read_build(caroline_dir: &Path, key: &str) -> String {
    let path = caroline_dir.join("caroline_build.json");
    let Ok(text) = fs::read_to_string(path) else {
        return String::new();
    };
    let Ok(value) = serde_json::from_str::<serde_json::Value>(&text) else {
        return String::new();
    };
    value
        .get(key)
        .and_then(|v| v.as_str())
        .unwrap_or_default()
        .to_string()
}

fn safe_value(value: &str, allowed: &str, fallback: &str) -> String {
    if !value.is_empty() && value.chars().all(|ch| allowed.contains(ch)) {
        value.to_string()
    } else {
        fallback.to_string()
    }
}

fn sanitize_channel(channel: &str) -> String {
    match channel {
        "release" | "nightly" => channel.to_string(),
        _ => "release".to_string(),
    }
}

fn sanitize_model(model: &str) -> String {
    safe_value(
        model,
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-/",
        "qwen3:1.7b",
    )
}

fn run_bash(script: &str, envs: &[(&str, String)]) -> ActionResult {
    let mut command = Command::new("bash");
    command.arg("-lc").arg(script);
    for (key, value) in envs {
        command.env(key, value);
    }
    match command.output() {
        Ok(out) => {
            let mut output = String::from_utf8_lossy(&out.stdout).to_string();
            output.push_str(&String::from_utf8_lossy(&out.stderr));
            ActionResult {
                ok: out.status.success(),
                output,
            }
        }
        Err(error) => ActionResult {
            ok: false,
            output: format!("Could not start bash: {error}"),
        },
    }
}

fn install_or_repair(options: &DeckActionOptions) -> ActionResult {
    let channel = sanitize_channel(&options.channel);
    let ai_provider = if options.ai_mode == "local" { "ollama" } else { "openrouter" };
    let install_ollama = if ai_provider == "ollama" && options.install_ollama {
        "true"
    } else {
        "false"
    };
    let bind_host = if options.lan_access { "0.0.0.0" } else { "127.0.0.1" };
    let model = sanitize_model(&options.ollama_model);
    let script = r#"
set -Eeuo pipefail
LOG="${TMPDIR:-/tmp}/caroline-deck-installer.log"
INSTALLER="${TMPDIR:-/tmp}/caroline-install-steamos-gui.sh"
echo "Project: Caroline Deck Installer"
echo "Action: ${CAROLINE_GUI_ACTION}"
echo "Channel: ${CAROLINE_CHANNEL}"
echo "AI provider: ${CAROLINE_AI_PROVIDER}"
echo "LAN bind: ${CAROLINE_BIND_HOST}"
echo ""
curl -fsSL "https://raw.githubusercontent.com/Project-Caroline/project-caroline/${CAROLINE_CHANNEL}/install-steamos.sh" -o "$INSTALLER"
chmod 700 "$INSTALLER"
NO_COLOR=1 TERM=dumb CAROLINE_NONINTERACTIVE=true bash "$INSTALLER" 2>&1 | tee "$LOG"
"#;
    run_bash(
        script,
        &[
            ("CAROLINE_GUI_ACTION", options.action.clone()),
            ("CAROLINE_CHANNEL", channel),
            ("CAROLINE_AI_PROVIDER", ai_provider.to_string()),
            ("CAROLINE_INSTALL_OLLAMA", install_ollama.to_string()),
            ("CAROLINE_OLLAMA_MODEL", model),
            ("CAROLINE_BIND_HOST", bind_host.to_string()),
        ],
    )
}

fn update_install(options: &DeckActionOptions) -> ActionResult {
    let channel = sanitize_channel(&options.channel);
    let script = r#"
set -Eeuo pipefail
CAROLINE_DIR="$HOME/caroline"
if [ ! -x "$HOME/.local/bin/caroline-update" ]; then
  echo "Update helper missing. Running repair installer instead."
  exit 42
fi
mkdir -p "$CAROLINE_DIR"
printf '%s\n' "$CAROLINE_CHANNEL" > "$CAROLINE_DIR/caroline_channel"
CAROLINE_UPDATE_CHANNEL="$CAROLINE_CHANNEL" "$HOME/.local/bin/caroline-update"
cat /tmp/caroline-update.log 2>/dev/null || true
"#;
    let result = run_bash(script, &[("CAROLINE_CHANNEL", channel.clone())]);
    if result.ok || !result.output.contains("Update helper missing") {
        return result;
    }
    let repair_options = DeckActionOptions {
        action: "repair".to_string(),
        channel,
        ai_mode: options.ai_mode.clone(),
        install_ollama: false,
        ollama_model: options.ollama_model.clone(),
        lan_access: options.lan_access,
        keep_data: true,
    };
    install_or_repair(&repair_options)
}

fn uninstall_install(options: &DeckActionOptions) -> ActionResult {
    let keep_data = if options.keep_data { "true" } else { "false" };
    let script = r#"
set -Eeuo pipefail
echo "Stopping Project: Caroline user services..."
systemctl --user stop caroline.service 2>/dev/null || true
systemctl --user disable caroline.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/caroline.service"
systemctl --user daemon-reload 2>/dev/null || true
rm -f "$HOME/.local/share/applications/caroline-steamos.desktop"
rm -f "$HOME/.local/share/applications/caroline-steamos-kiosk.desktop"
rm -f "$HOME/Desktop/Project: Caroline.desktop"
rm -f "$HOME/Desktop/Project: Caroline Kiosk.desktop"
rm -f "$HOME/.local/bin/caroline-steamos-open"
rm -f "$HOME/.local/bin/caroline-steamos-kiosk"
rm -f "$HOME/.local/bin/caroline-update"
if [ "$CAROLINE_KEEP_DATA" = "true" ]; then
  echo "Kept $HOME/caroline and $HOME/project-caroline."
else
  echo "Removing app data and source cache..."
  rm -rf "$HOME/caroline" "$HOME/project-caroline"
fi
echo "Project: Caroline Deck uninstall complete."
"#;
    run_bash(script, &[("CAROLINE_KEEP_DATA", keep_data.to_string())])
}

fn open_install(kind: String) -> ActionResult {
    let script = if kind == "kiosk" {
        r#"
set -Eeuo pipefail
if [ -x "$HOME/.local/bin/caroline-steamos-kiosk" ]; then
  nohup "$HOME/.local/bin/caroline-steamos-kiosk" >/tmp/caroline-kiosk-open.log 2>&1 &
else
  nohup xdg-open http://localhost:8080/ >/tmp/caroline-kiosk-open.log 2>&1 &
fi
echo "Kiosk launch requested."
"#
    } else {
        r#"
set -Eeuo pipefail
if [ -x "$HOME/.local/bin/caroline-steamos-open" ]; then
  nohup "$HOME/.local/bin/caroline-steamos-open" >/tmp/caroline-open.log 2>&1 &
else
  nohup xdg-open http://localhost:8080/ >/tmp/caroline-open.log 2>&1 &
fi
echo "Windowed launch requested."
"#
    };
    run_bash(script, &[])
}

#[tauri::command]
fn deck_status() -> DeckStatus {
    let home = home_dir();
    let caroline_dir = home.join("caroline");
    let os = os_release();
    let bind = run_capture(
        "bash",
        &[
            "-lc",
            "sed -n 's/.*uiHost: process.env.CAROLINE_BIND_HOST || \"\\([^\"]*\\)\".*/\\1/p' \"$HOME/caroline/settings.js\" 2>/dev/null | head -1",
        ],
    );
    let ip = run_capture("bash", &["-lc", "hostname -I 2>/dev/null | awk '{print $1}'"]);
    let lan_url = if !ip.is_empty() && bind != "127.0.0.1" && bind != "localhost" {
        format!("http://{ip}:8080/")
    } else {
        String::new()
    };
    DeckStatus {
        is_steam_os_like: is_steam_os_like(&os),
        os_name: os_pretty_name(&os),
        user_name: env::var("USER").unwrap_or_default(),
        home_dir: home.display().to_string(),
        caroline_dir_exists: caroline_dir.exists(),
        service_state: run_capture("bash", &["-lc", "systemctl --user is-active caroline.service 2>/dev/null || echo inactive"]),
        ollama_state: run_capture("bash", &["-lc", "systemctl --user is-active ollama.service 2>/dev/null || echo inactive"]),
        version: read_build(&caroline_dir, "version"),
        commit: read_build(&caroline_dir, "commit"),
        channel: read_build(&caroline_dir, "channel"),
        lan_url,
        local_url: "http://localhost:8080/".to_string(),
        launchers_ready: home.join(".local/bin/caroline-steamos-open").exists()
            && home.join(".local/bin/caroline-steamos-kiosk").exists(),
    }
}

#[tauri::command]
async fn run_deck_action(options: DeckActionOptions) -> Result<ActionResult, String> {
    tauri::async_runtime::spawn_blocking(move || match options.action.as_str() {
        "install" | "repair" => install_or_repair(&options),
        "update" => update_install(&options),
        "uninstall" => uninstall_install(&options),
        _ => ActionResult {
            ok: false,
            output: "Unknown action.".to_string(),
        },
    })
    .await
    .map_err(|error| error.to_string())
}

#[tauri::command]
async fn open_caroline(kind: String) -> Result<ActionResult, String> {
    tauri::async_runtime::spawn_blocking(move || open_install(kind))
        .await
        .map_err(|error| error.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![deck_status, run_deck_action, open_caroline])
        .run(tauri::generate_context!())
        .expect("error while running Caroline Deck Installer");
}
