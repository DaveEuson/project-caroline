#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const MODEL_PRESETS = {
  fast: ['qwen3:0.6b', 'llama3.2:1b', 'gemma3:1b', 'qwen2.5:0.5b', 'tinyllama:1.1b'],
  small: ['qwen3:1.7b', 'llama3.2:1b', 'llama3.2:3b', 'gemma3:1b', 'deepseek-r1:1.5b', 'smollm2:1.7b', 'qwen2.5:1.5b'],
  popular: [
    'qwen3:1.7b',
    'qwen3:4b',
    'llama3.2:1b',
    'llama3.2:3b',
    'gemma3:1b',
    'gemma3:4b',
    'phi4-mini',
    'deepseek-r1:1.5b',
    'deepseek-r1:7b',
    'mistral:7b',
    'llama3.1:8b',
    'smollm2:1.7b',
    'tinyllama:1.1b',
    'qwen2.5:1.5b',
  ],
  gpu: [
    'qwen3:1.7b',
    'qwen3:4b',
    'gemma3:4b',
    'phi4-mini',
    'mistral:7b',
    'deepseek-r1:7b',
    'llama3.1:8b',
    'gpt-oss:20b',
  ],
};
const DEFAULT_MODELS = MODEL_PRESETS.popular;
const DEFAULT_TIMEOUT_MS = 120000;
const DEFAULT_PULL_TIMEOUT_MS = 20 * 60 * 1000;

function todayParts() {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Los_Angeles',
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });
  const parts = Object.fromEntries(formatter.formatToParts(new Date()).map((part) => [part.type, part.value]));
  return {
    weekday: parts.weekday || '',
    month: parts.month || '',
    day: parts.day || '',
    year: parts.year || '',
  };
}

const TODAY = todayParts();

const PROMPTS = [
  {
    id: 'greeting',
    text: 'Happy Friday buddy',
    checks: [
      { label: 'social reply', test: /friday|buddy|hey|happy|good to see|back/i },
      { label: 'no productivity pivot', test: (r) => !/\b(task|calendar|smallest visible step|deadline|schedule)\b/i.test(r) },
    ],
  },
  {
    id: 'date',
    text: 'What day is it today?',
    checks: [
      { label: 'correct weekday', test: (r) => new RegExp(`\\b${TODAY.weekday}\\b`, 'i').test(r) },
      { label: 'correct date', test: (r) => new RegExp(`${TODAY.month}\\s+${TODAY.day}\\b|\\b${TODAY.year}\\b`, 'i').test(r) },
    ],
  },
  {
    id: 'memory',
    text: "My wife's name is Beckie. Can you remember that?",
    checks: [
      { label: 'acknowledges Beckie', test: /Beckie/i },
      { label: 'remember action', test: /\[ACTION\]\s*\{\s*"type"\s*:\s*"remember"/i },
    ],
  },
  {
    id: 'calendar-disconnected',
    text: 'What is on my calendar today?',
    body: { features: { calendar: true }, context: { features: { calendar: true } } },
    checks: [
      { label: 'honest disconnected state', test: /calendar.*(not linked|connect|settings|not connected)|connect.*calendar/i },
      { label: 'no fake event', test: (r) => !/\b(9:|10:|11:|meeting with|appointment with)\b/i.test(r) },
    ],
  },
  {
    id: 'low-mood',
    text: 'I had a really rough day and I feel wiped out.',
    body: { userMood: 3 },
    checks: [
      { label: 'emotion first', test: /rough|wiped|exhaust|hard|heavy|sorry|sounds/i },
      { label: 'no productivity push', test: (r) => !/\b(task|calendar|to-do|deadline|small win|next step)\b/i.test(r) },
    ],
  },
  {
    id: 'simple-plan',
    text: 'I need to clean my desk, email Sam, and pay the power bill. Help me pick one.',
    checks: [
      { label: 'chooses one', test: /\b(email Sam|pay the power bill|clean my desk)\b/i },
      { label: 'keeps concise', test: (r) => r.split(/\s+/).filter(Boolean).length <= 90 },
    ],
  },
  {
    id: 'task-action',
    text: 'Remind me to replace the HDMI cable tomorrow.',
    checks: [
      { label: 'task or calendar action', test: /\[ACTION\]\s*\{[^}]*"type"\s*:\s*"(add_task|calendar)"/i },
      { label: 'mentions HDMI', test: /HDMI/i },
    ],
  },
  {
    id: 'correction',
    text: "If I say my wife's name is Sarah, correct me based on memory: it's Beckie.",
    checks: [
      { label: 'uses Beckie', test: /Beckie/i },
      { label: 'does not accept Sarah', test: (r) => !/Sarah is your wife/i.test(r) },
    ],
  },
  {
    id: 'concise-explain',
    text: 'Explain why local AI can be slower than OpenRouter in two short sentences.',
    checks: [
      { label: 'mentions local hardware', test: /local|hardware|CPU|GPU|device|Steam Deck/i },
      { label: 'mentions OpenRouter/cloud', test: /OpenRouter|cloud|server/i },
    ],
  },
  {
    id: 'json-discipline',
    text: 'Add a calendar event called Model Test tomorrow at 3pm for 30 minutes.',
    body: { features: { calendar: true }, context: { features: { calendar: true } } },
    checks: [
      { label: 'calendar action JSON', test: /\[ACTION\]\s*\{[^}]*"type"\s*:\s*"calendar"[^}]*"title"\s*:\s*"Model Test"/i },
      { label: 'has time', test: /"time"\s*:\s*"15:00"/i },
    ],
  },
];

function usage() {
  console.log(`Usage: node scripts/benchmark-ollama-models.js --target <url-or-host> [options]

Options:
  --models <csv|preset>      Models to benchmark (default preset: popular)
                             Presets: ${Object.keys(MODEL_PRESETS).join(', ')}
  --pull-missing             Ask Caroline to pull missing models first.
  --pull-timeout-ms <ms>     Wait for pulls (default: ${DEFAULT_PULL_TIMEOUT_MS})
  --timeout-ms <ms>          Per-prompt timeout (default: ${DEFAULT_TIMEOUT_MS})
  --out <path>               Write raw JSON report.
`);
}

function parseArgs(argv) {
  const opts = {
    target: '',
    models: DEFAULT_MODELS,
    pullMissing: false,
    pullTimeoutMs: DEFAULT_PULL_TIMEOUT_MS,
    timeoutMs: DEFAULT_TIMEOUT_MS,
    out: '',
  };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      usage();
      process.exit(0);
    }
    if (arg === '--pull-missing') {
      opts.pullMissing = true;
      continue;
    }
    const value = argv[++i];
    if (!value) throw new Error(`Missing value for ${arg}`);
    if (arg === '--target') opts.target = normalizeTarget(value);
    else if (arg === '--models') opts.models = parseModels(value);
    else if (arg === '--pull-timeout-ms') opts.pullTimeoutMs = Number(value);
    else if (arg === '--timeout-ms') opts.timeoutMs = Number(value);
    else if (arg === '--out') opts.out = value;
    else throw new Error(`Unknown option: ${arg}`);
  }
  if (!opts.target) throw new Error('Missing --target <url-or-host>.');
  return opts;
}

function parseModels(value) {
  const key = String(value || '').trim();
  if (MODEL_PRESETS[key]) return MODEL_PRESETS[key];
  return key.split(',').map((s) => s.trim()).filter(Boolean);
}

function normalizeTarget(value) {
  let baseUrl = value.trim();
  if (!/^https?:\/\//i.test(baseUrl)) baseUrl = `http://${baseUrl}`;
  const url = new URL(baseUrl);
  if (!url.port) url.port = '8080';
  url.pathname = url.pathname.replace(/\/+$/, '');
  return url.toString().replace(/\/+$/, '');
}

function makeAbort(timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return { signal: controller.signal, clear: () => clearTimeout(timer) };
}

async function requestJson(baseUrl, route, options = {}, timeoutMs = DEFAULT_TIMEOUT_MS) {
  const abort = makeAbort(timeoutMs);
  try {
    const response = await fetch(baseUrl + route, { ...options, signal: abort.signal });
    const text = await response.text();
    let body = null;
    try { body = text ? JSON.parse(text) : null; } catch (_) { body = text; }
    return { ok: response.ok, status: response.status, body };
  } finally {
    abort.clear();
  }
}

async function ollamaStatus(baseUrl) {
  const response = await requestJson(baseUrl, '/admin/ollama-status', {}, 15000);
  if (!response.ok) throw new Error(`/admin/ollama-status HTTP ${response.status}`);
  const models = Array.isArray(response.body?.models) ? response.body.models : [];
  return models.map((model) => model.name || model.model).filter(Boolean);
}

function installedModelName(present, requested) {
  if (present.includes(requested)) return requested;
  if (!requested.includes(':') && present.includes(`${requested}:latest`)) return `${requested}:latest`;
  const bare = requested.replace(/:latest$/, '');
  return present.find((model) => model === bare || model === `${bare}:latest`) || '';
}

async function pullMissingModels(opts) {
  const started = [];
  let present = await ollamaStatus(opts.target);
  for (const model of opts.models) {
    if (installedModelName(present, model)) continue;
    const response = await requestJson(opts.target, '/admin/ollama-pull', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ model }),
    }, 15000);
    if (!response.ok) throw new Error(`Pull ${model} failed: HTTP ${response.status} ${JSON.stringify(response.body)}`);
    started.push(model);
  }
  if (!started.length) return { started, present };

  const deadline = Date.now() + opts.pullTimeoutMs;
  while (Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 10000));
    present = await ollamaStatus(opts.target);
    const missing = opts.models.filter((model) => !installedModelName(present, model));
    console.log(`pull-poll present=${present.filter((m) => opts.models.includes(m)).join(',') || 'none'} missing=${missing.join(',') || 'none'}`);
    if (!missing.length) return { started, present };
  }
  throw new Error(`Timed out waiting for models: ${opts.models.filter((model) => !present.includes(model)).join(', ')}`);
}

function scoreReply(prompt, reply) {
  const results = prompt.checks.map((check) => {
    const passed = typeof check.test === 'function' ? check.test(reply) : check.test.test(reply);
    return { label: check.label, passed: !!passed };
  });
  const score = results.filter((item) => item.passed).length / results.length;
  return { score, checks: results };
}

async function askModel(opts, model, prompt) {
  const startedAt = Date.now();
  const body = {
    message: prompt.text,
    content: prompt.text,
    userName: 'Dave',
    aiName: 'Carl',
    aiProvider: 'ollama',
    ollamaModel: model,
    ...prompt.body,
  };
  const response = await requestJson(opts.target, '/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }, opts.timeoutMs);
  const elapsedMs = Date.now() - startedAt;
  const reply = typeof response.body === 'string'
    ? response.body
    : String(response.body?.reply || response.body?.content || response.body?.message || '');
  const scored = scoreReply(prompt, reply);
  return {
    id: prompt.id,
    prompt: prompt.text,
    ok: response.ok,
    status: response.status,
    elapsedMs,
    score: response.ok ? scored.score : 0,
    checks: response.ok ? scored.checks : [],
    reply,
  };
}

async function benchmarkModel(opts, model) {
  console.log(`\nmodel=${model}`);
  const prompts = [];
  for (const prompt of PROMPTS) {
    let result;
    try {
      result = await askModel(opts, model, prompt);
    } catch (error) {
      result = {
        id: prompt.id,
        prompt: prompt.text,
        ok: false,
        status: 0,
        elapsedMs: opts.timeoutMs,
        score: 0,
        checks: [],
        reply: '',
        error: error.message || String(error),
      };
    }
    prompts.push(result);
    const label = result.ok ? `${Math.round(result.score * 100)}%` : (result.status ? `HTTP ${result.status}` : 'ERROR');
    console.log(`  ${prompt.id.padEnd(21)} ${String(result.elapsedMs).padStart(6)}ms ${label}`);
  }
  const okPrompts = prompts.filter((p) => p.ok);
  const avgMs = Math.round(okPrompts.reduce((sum, p) => sum + p.elapsedMs, 0) / Math.max(okPrompts.length, 1));
  const avgScore = okPrompts.reduce((sum, p) => sum + p.score, 0) / Math.max(okPrompts.length, 1);
  const failures = prompts.flatMap((p) => p.checks.filter((c) => !c.passed).map((c) => `${p.id}: ${c.label}`));
  return { model, avgMs, avgScore, failures, prompts };
}

async function main() {
  const opts = parseArgs(process.argv);
  const health = await requestJson(opts.target, '/health', {}, 15000);
  if (!health.ok) throw new Error(`/health HTTP ${health.status}`);
  console.log(`target=${opts.target}`);
  console.log(`health=${health.body?.hostDeviceType || 'device'} provider=${health.body?.aiProvider || ''} model=${health.body?.ollamaModel || ''}`);

  let present = await ollamaStatus(opts.target);
  console.log(`installed=${present.filter((model) => opts.models.includes(model)).join(',') || 'none'}`);
  if (opts.pullMissing) {
    const pull = await pullMissingModels(opts);
    present = pull.present;
    if (pull.started.length) console.log(`pull-started=${pull.started.join(',')}`);
  }

  const models = opts.models
    .map((model) => installedModelName(present, model) || model)
    .filter((model, index, arr) => present.includes(model) && arr.indexOf(model) === index);
  if (!models.length) throw new Error('None of the requested models are installed.');
  if (models.length < opts.models.length) {
    console.log(`skipping-missing=${opts.models.filter((model) => !installedModelName(present, model)).join(',')}`);
  }

  const results = [];
  for (const model of models) results.push(await benchmarkModel(opts, model));
  const report = { target: opts.target, health: health.body, prompts: PROMPTS.map((p) => ({ id: p.id, text: p.text })), results };

  console.log('\nsummary');
  for (const result of results.slice().sort((a, b) => b.avgScore - a.avgScore || a.avgMs - b.avgMs)) {
    console.log(`  ${result.model.padEnd(15)} score=${(result.avgScore * 10).toFixed(1)}/10 avg=${result.avgMs}ms failures=${result.failures.length}`);
  }

  if (opts.out) {
    const outPath = path.resolve(opts.out);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, JSON.stringify(report, null, 2), 'utf8');
    console.log(`wrote=${outPath}`);
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
