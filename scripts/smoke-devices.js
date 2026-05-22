#!/usr/bin/env node
const { spawnSync } = require('child_process');

const DEFAULT_TIMEOUT_MS = 10000;
const CHAT_WAIT_MS = 9000;

function usage() {
  console.log(`Usage: node scripts/smoke-devices.js --target <name=host-or-url> [options]

Options:
  --target <name=host-or-url>   Device target. Repeat for multiple devices.
                                host values become http://HOST:8080.
  --ssh <name=user@host>        Optional SSH service probe for a named target.
                                Repeat for multiple devices.
  --timeout-ms <ms>             HTTP timeout (default: ${DEFAULT_TIMEOUT_MS})
  --chat-wait-ms <ms>           WebSocket capture wait after /chat (default: ${CHAT_WAIT_MS})
  --json                        Print raw JSON results.
  --help                        Show this help.

Examples:
  node scripts/smoke-devices.js --target Pi=192.168.1.50 --ssh Pi=dave@192.168.1.50
  node scripts/smoke-devices.js --target Deck=http://steamdeck:8080
`);
}

function parseArgs(argv) {
  const opts = { targets: [], ssh: new Map(), timeoutMs: DEFAULT_TIMEOUT_MS, chatWaitMs: CHAT_WAIT_MS, json: false };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      usage();
      process.exit(0);
    }
    if (arg === '--json') {
      opts.json = true;
      continue;
    }
    const value = argv[++i];
    if (!value) throw new Error(`Missing value for ${arg}`);
    if (arg === '--target') opts.targets.push(parseTarget(value));
    else if (arg === '--ssh') {
      const parsed = parseKeyValue(value, '--ssh');
      opts.ssh.set(parsed.key, parsed.value);
    } else if (arg === '--timeout-ms') opts.timeoutMs = Number(value);
    else if (arg === '--chat-wait-ms') opts.chatWaitMs = Number(value);
    else throw new Error(`Unknown option: ${arg}`);
  }
  if (!opts.targets.length) throw new Error('Add at least one --target <name=host-or-url>.');
  return opts;
}

function parseKeyValue(value, flagName) {
  const idx = value.indexOf('=');
  if (idx <= 0 || idx === value.length - 1) throw new Error(`${flagName} must be name=value`);
  return { key: value.slice(0, idx), value: value.slice(idx + 1) };
}

function parseTarget(value) {
  const parsed = parseKeyValue(value, '--target');
  let baseUrl = parsed.value.trim();
  if (!/^https?:\/\//i.test(baseUrl)) baseUrl = `http://${baseUrl}`;
  const url = new URL(baseUrl);
  if (!url.port) url.port = '8080';
  url.pathname = url.pathname.replace(/\/+$/, '');
  return { name: parsed.key, baseUrl: url.toString().replace(/\/+$/, '') };
}

function command(name) {
  if (process.platform === 'win32' && name === 'ssh') return 'C:\\Windows\\System32\\OpenSSH\\ssh.exe';
  return name;
}

function makeAbort(timeoutMs) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  return { signal: controller.signal, clear: () => clearTimeout(timeout) };
}

async function fetchJson(baseUrl, path, options, timeoutMs) {
  const abort = makeAbort(timeoutMs);
  try {
    const resp = await fetch(baseUrl + path, { ...options, signal: abort.signal });
    const text = await resp.text();
    let body = null;
    try { body = text ? JSON.parse(text) : null; } catch (error) { body = text; }
    return { ok: resp.ok, status: resp.status, body };
  } finally {
    abort.clear();
  }
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function websocketUrl(baseUrl) {
  const url = new URL(baseUrl);
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  url.pathname = '/ws/caroline';
  return url.toString();
}

async function captureChat(target, message, extraBody, opts) {
  const events = [];
  let ws = null;
  let wsOpen = false;
  if (typeof WebSocket === 'function') {
    try {
      ws = new WebSocket(websocketUrl(target.baseUrl));
      await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('websocket open timeout')), opts.timeoutMs);
        ws.addEventListener('open', () => {
          clearTimeout(timer);
          wsOpen = true;
          resolve();
        }, { once: true });
        ws.addEventListener('error', () => {
          clearTimeout(timer);
          reject(new Error('websocket error'));
        }, { once: true });
      });
      ws.addEventListener('message', event => {
        try {
          const parsed = JSON.parse(event.data);
          if (parsed && (parsed.type === 'conversation_event' || parsed.type === 'reply')) events.push(parsed);
        } catch (error) {
          // Ignore non-JSON websocket chatter.
        }
      });
    } catch (error) {
      events.push({ type: 'smoke_error', content: error.message, source: 'smoke-runner' });
    }
  }

  const response = await fetchJson(target.baseUrl, '/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message,
      userName: 'Dave',
      aiName: 'Caroline',
      ...(extraBody || {}),
    }),
  }, Math.max(opts.timeoutMs, opts.chatWaitMs + 5000));

  if (wsOpen) await delay(opts.chatWaitMs);
  if (ws) ws.close();
  return { response, events };
}

function textFromChat(result) {
  const body = result && result.response && result.response.body;
  if (!body) return '';
  if (typeof body === 'string') return body;
  return String(body.reply || body.content || body.message || '');
}

function pass(name, details) {
  return { name, status: 'pass', details: details || '' };
}

function fail(name, details) {
  return { name, status: 'fail', details: details || '' };
}

function skip(name, details) {
  return { name, status: 'skip', details: details || '' };
}

function serviceProbe(sshTarget) {
  if (!sshTarget) return skip('service', 'no SSH target supplied');
  const remoteCmd = [
    'systemctl --user is-active caroline.service 2>/dev/null',
    'systemctl --user is-active caroline 2>/dev/null',
    'systemctl is-active caroline.service 2>/dev/null',
    'systemctl is-active caroline 2>/dev/null',
  ].join(' || ');
  const result = spawnSync(command('ssh'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    sshTarget,
    remoteCmd,
  ], { encoding: 'utf8' });
  const output = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
  const lines = output.split(/\r?\n/).map(line => line.trim()).filter(Boolean);
  if (lines.includes('active')) return pass('service', 'active');
  return skip('service', output || `ssh exit ${result.status}`);
}

async function smokeTarget(target, opts) {
  const checks = [];
  let healthBody = null;
  try {
    const health = await fetchJson(target.baseUrl, '/health', {}, opts.timeoutMs);
    healthBody = health.body && typeof health.body === 'object' ? health.body : null;
    checks.push(health.ok && healthBody ? pass('health', `${healthBody.hostDeviceType || healthBody.hostname || 'device'} ${healthBody.aiProvider || ''} ${healthBody.aiModel || healthBody.ollamaModel || ''}`.trim()) : fail('health', `HTTP ${health.status}`));
  } catch (error) {
    checks.push(fail('health', error.message));
  }

  try {
    const chat = await captureChat(target, 'test', {}, opts);
    const replyText = textFromChat(chat);
    const userEvent = chat.events.find(event => event.type === 'conversation_event' && event.role === 'user');
    const replyEvent = chat.events.find(event => event.type === 'reply');
    const visibleSource = userEvent && !(userEvent.source === 'display' && userEvent.origin === 'http-chat');
    if (chat.response.ok && replyText && userEvent && replyEvent && visibleSource) {
      checks.push(pass('chat visibility', `user source=${userEvent.source || 'n/a'}, reply source=${replyEvent.source || 'n/a'}`));
    } else {
      checks.push(fail('chat visibility', `HTTP ${chat.response.status}, reply=${JSON.stringify(replyText).slice(0, 120)}, userEvent=${userEvent ? `${userEvent.source}/${userEvent.origin}` : 'missing'}, replyEvent=${replyEvent ? `${replyEvent.source}/${replyEvent.origin}` : 'missing'}`));
    }
  } catch (error) {
    checks.push(fail('chat visibility', error.message));
  }

  try {
    const calendar = await captureChat(target, 'What is on my calendar today?', {}, opts);
    const replyText = textFromChat(calendar);
    const connected = !!(healthBody && ((healthBody.google && healthBody.google.connected) || (!healthBody.google && healthBody.calendar && healthBody.calendar.configured)));
    const looksDisconnected = /\b(not linked|connect|reconnect|not enabled|disabled|settings|no calendar)\b/i.test(replyText);
    if (!calendar.response.ok) checks.push(fail('calendar read', `HTTP ${calendar.response.status}`));
    else if (connected && looksDisconnected) checks.push(fail('calendar read', `connected device gave disconnected reply: ${replyText.slice(0, 160)}`));
    else checks.push(pass('calendar read', replyText.slice(0, 160)));
  } catch (error) {
    checks.push(fail('calendar read', error.message));
  }

  try {
    const gated = await captureChat(target, 'What is on my calendar today?', {
      features: { calendar: false },
      context: { features: { calendar: false } },
    }, opts);
    const replyText = textFromChat(gated);
    const gatedReply = /\b(not linked|connect|settings|off|disabled|not enabled)\b/i.test(replyText);
    checks.push(gated.response.ok && gatedReply ? pass('widget gating', replyText.slice(0, 160)) : fail('widget gating', `reply=${replyText.slice(0, 160)}`));
  } catch (error) {
    checks.push(fail('widget gating', error.message));
  }

  checks.push(serviceProbe(opts.ssh.get(target.name)));
  if (healthBody && healthBody.discord) {
    const discord = healthBody.discord;
    checks.push(discord.enabled && discord.configured && discord.channelConfigured
      ? pass('discord configured', 'enabled/configured/channel configured')
      : skip('discord configured', JSON.stringify(discord)));
  } else {
    checks.push(skip('discord configured', 'not reported by /health'));
  }

  return { target, health: healthBody, checks };
}

function printResults(results) {
  for (const result of results) {
    console.log(`\n${result.target.name} (${result.target.baseUrl})`);
    for (const check of result.checks) {
      const marker = check.status === 'pass' ? 'PASS' : check.status === 'fail' ? 'FAIL' : 'SKIP';
      console.log(`  ${marker} ${check.name}${check.details ? ` - ${check.details}` : ''}`);
    }
  }
  const failed = results.flatMap(result => result.checks.filter(check => check.status === 'fail'));
  console.log(`\nSummary: ${failed.length ? `${failed.length} failing check(s)` : 'all required checks passed'}`);
}

async function main() {
  const opts = parseArgs(process.argv);
  if (typeof fetch !== 'function') throw new Error('This script requires Node.js with global fetch support.');
  const results = [];
  for (const target of opts.targets) results.push(await smokeTarget(target, opts));
  if (opts.json) console.log(JSON.stringify(results, null, 2));
  else printResults(results);
  const failed = results.flatMap(result => result.checks.filter(check => check.status === 'fail'));
  if (failed.length) process.exit(1);
}

main().catch(error => {
  console.error(error.message || error);
  process.exit(1);
});
