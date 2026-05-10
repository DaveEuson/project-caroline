#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..');
const FLOWS_PATH = path.join(ROOT, 'flows.json');
const flows = JSON.parse(fs.readFileSync(FLOWS_PATH, 'utf8'));

const NODES = {
  wsBuild: '62b80b5a9fdb1cf3',
  wsParse: '98a844825c10c91e',
  httpBuild: '1f1f522ed0b2f628',
  httpParse: '4a770c4d047aa23d',
  handleAction: '0cbd504f3c3054fd',
};

const tests = [];

function test(name, fn) {
  tests.push({ name, fn });
}

function findNode(id) {
  const node = flows.find((n) => n.id === id);
  if (!node) throw new Error(`Missing flow node ${id}`);
  return node;
}

function createStore(initial = {}) {
  return Object.assign({
    aiProvider: 'ollama',
    ollamaModel: 'qwen2.5:1.5b',
    timezone: 'America/Los_Angeles',
    userName: 'Dave',
    aiName: 'Caroline',
  }, initial);
}

function runNode(id, msg, initialStore = {}) {
  const node = findNode(id);
  const store = createStore(initialStore);
  const writes = {};
  const sandbox = {
    msg,
    fs: {
      existsSync: (p) => Object.prototype.hasOwnProperty.call(writes, p),
      readFileSync: (p) => writes[p] || '[]',
      writeFileSync: (p, value) => { writes[p] = String(value); },
      appendFileSync: (p, value) => { writes[p] = (writes[p] || '') + String(value); },
      chmodSync: () => {},
    },
    node: { warn: () => {}, error: () => {}, log: () => {} },
    global: { get: (k) => store[k], set: (k, v) => { store[k] = v; } },
    flow: { get: (k) => store[k], set: (k, v) => { store[k] = v; } },
    URL,
    Buffer,
    Date,
    JSON,
    Math,
    Number,
    String,
    RegExp,
    Object,
    Array,
    console,
  };
  return vm.runInNewContext(`(function(){\n${node.func}\n})()`, sandbox, { timeout: 1500 });
}

function directCommand(nodeId, text, payload = {}) {
  const out = runNode(nodeId, { payload: Object.assign({ content: text, aiProvider: 'ollama' }, payload) });
  return Array.isArray(out) ? out.find((item) => item && (item.action || item.payload)) : out;
}

function directAction(nodeId, text) {
  const out = runNode(nodeId, { payload: { content: text, aiProvider: 'ollama' } });
  const msg = Array.isArray(out) ? out.find((item) => item && item.action) : out;
  return msg && msg.action;
}

function parseAction(nodeId, userMessage, rawReply) {
  const payload = nodeId === NODES.wsParse
    ? { choices: [{ message: { content: rawReply } }] }
    : { response: rawReply };
  const out = runNode(nodeId, { userMessage, payload });
  const msg = Array.isArray(out) ? out.find((item) => item && item.action) : out;
  return msg && msg.action;
}

function handleAction(action) {
  return runNode(NODES.handleAction, { action });
}

function expectAction(actual, expected, label) {
  assert(actual, `${label}: expected an action`);
  for (const [key, value] of Object.entries(expected)) {
    assert.strictEqual(actual[key], value, `${label}: ${key}`);
  }
}

function assertNoAction(nodeId, text, expectedReplyPart) {
  const msg = directCommand(nodeId, text);
  assert(msg, `${nodeId} ${text}: expected response`);
  assert(!msg.action, `${nodeId} ${text}: did not expect action`);
  if (expectedReplyPart) {
    assert(String(msg.payload && msg.payload.reply || '').includes(expectedReplyPart), `${nodeId} ${text}: reply should include ${expectedReplyPart}`);
  }
}

const buildNodes = [
  ['websocket', NODES.wsBuild],
  ['http', NODES.httpBuild],
];

for (const [surface, nodeId] of buildNodes) {
  test(`${surface}: calendar add variants`, () => {
    const cases = [
      ['Can you add Eat dinner to my caliender at 9pm?', { type: 'calendar', title: 'Eat dinner', time: '21:00', duration_minutes: 60 }],
      ['Can you add Eat dinner to my calendar at 9pm?', { type: 'calendar', title: 'Eat dinner', time: '21:00', duration_minutes: 60 }],
      ['Add dentist appointment to my calender tomorrow at 2pm', { type: 'calendar', title: 'dentist appointment', time: '14:00', duration_minutes: 60 }],
      ['Put "Call mom" on my google calendar tomorrow at 10am', { type: 'calendar', title: 'Call mom', time: '10:00', duration_minutes: 60 }],
      ['Schedule Project Caroline release event Friday at 6pm for 30 minutes', { type: 'calendar', title: 'Project Caroline release event', time: '18:00', duration_minutes: 30 }],
      ['Book demo walkthrough Friday at 3pm', { type: 'calendar', title: 'demo walkthrough', time: '15:00', duration_minutes: 60 }],
    ];
    for (const [text, expected] of cases) expectAction(directAction(nodeId, text), expected, `${surface} calendar: ${text}`);
  });

  test(`${surface}: calendar delete variants`, () => {
    const cases = [
      ['Cancel Team standup from my calendar', { type: 'calendar_delete', title: 'Team standup' }],
      ['Delete Codex qwen model smoke test from my calendar tomorrow', { type: 'calendar_delete', title: 'Codex qwen model smoke test' }],
      ['delete the calendar event "Dentist appointment"', { type: 'calendar_delete', title: 'Dentist appointment' }],
      ['remove clean install notes off my schedule', { type: 'calendar_delete', title: 'clean install notes' }],
    ];
    for (const [text, expected] of cases) expectAction(directAction(nodeId, text), expected, `${surface} delete: ${text}`);
  });

  test(`${surface}: task variants`, () => {
    const cases = [
      ['Add buy milk to my task list', { type: 'add_task', task: 'Buy Milk' }],
      ['put publish release notes on my todo list', { type: 'add_task', task: 'Publish Release Notes' }],
      ['remind me to file taxes', { type: 'add_task', task: 'File Taxes' }],
      ['I finished buy milk', { type: 'complete_task', task: 'Buy Milk' }],
      ['mark publish release notes done', { type: 'complete_task', task: 'Publish Release Notes' }],
    ];
    for (const [text, expected] of cases) expectAction(directAction(nodeId, text), expected, `${surface} task: ${text}`);
  });

  test(`${surface}: Hue variants`, () => {
    const cases = [
      ['turn the Hue lights off', { type: 'hue', mode: 'off' }],
      ['switch the lamps on', { type: 'hue', mode: 'on' }],
      ['set lights to party mode', { type: 'hue', mode: 'party' }],
      ['dim the lamps', { type: 'hue', mode: 'dim' }],
      ['make the lights cozy', { type: 'hue', mode: 'relax' }],
      ['focus lighting please', { type: 'hue', mode: 'focus' }],
      ['night lights', { type: 'hue', mode: 'night' }],
    ];
    for (const [text, expected] of cases) expectAction(directAction(nodeId, text), expected, `${surface} Hue: ${text}`);
  });

  test(`${surface}: feedback does not become calendar read`, () => {
    expectAction(directAction(nodeId, 'feedback: calendar panel is too cramped'), {
      type: 'feedback',
      feedback: 'calendar panel is too cramped',
    }, `${surface} feedback calendar wording`);
    expectAction(directAction(nodeId, 'bug: calendar panel is broken'), {
      type: 'feedback',
      category: 'bug',
      feedback: 'calendar panel is broken',
    }, `${surface} bug calendar wording`);
  });

  test(`${surface}: safe non-action replies`, () => {
    assertNoAction(nodeId, 'I have feedback', 'what Dave should change');
    assertNoAction(nodeId, 'what is on my calendar today', 'calendar today');
    assertNoAction(nodeId, 'why are your responses so slow', 'local Ollama');
    assertNoAction(nodeId, 'hello', "I'm here");
  });
}

for (const [surface, nodeId] of [['websocket parse', NODES.wsParse], ['http parse', NODES.httpParse]]) {
  test(`${surface}: inferred action after model misses action block`, () => {
    expectAction(parseAction(nodeId, 'Can you add Eat dinner to my caliender at 9pm?', 'Sure, working on it.'), {
      type: 'calendar',
      title: 'Eat dinner',
      time: '21:00',
    }, `${surface} inferred calendar`);
    expectAction(parseAction(nodeId, 'turn hue lights off', 'Sure.'), { type: 'hue', mode: 'off' }, `${surface} inferred hue`);
  });

  test(`${surface}: model JSON action variants normalize`, () => {
    const calendarReply = 'Working on it. [ACTION]{"type":"calendar","title":"Eat dinner to my caliender","date":"2026-05-09","time":"21:00"}[/ACTION]';
    expectAction(parseAction(nodeId, 'Can you add Eat dinner to my caliender at 9pm?', calendarReply), {
      type: 'calendar',
      title: 'Eat dinner',
      date: '2026-05-09',
      time: '21:00',
    }, `${surface} JSON calendar`);

    const taskReply = 'Yep. [ACTION]{"type":"add_task","task":"Check beta links"}[/ACTION]';
    expectAction(parseAction(nodeId, 'add check beta links to my task list', taskReply), {
      type: 'add_task',
      task: 'Check beta links',
    }, `${surface} JSON task`);

    const deleteReply = 'Working on it. [ACTION]{"type":"calendar_delete","title":"Codex qwen model smoke test from my calendar tomorrow"}[/ACTION]';
    expectAction(parseAction(nodeId, 'Delete Codex qwen model smoke test from my calendar tomorrow', deleteReply), {
      type: 'calendar_delete',
      title: 'Codex qwen model smoke test',
    }, `${surface} JSON calendar delete`);
  });
}

test('final action router sanitizes and routes all action types', () => {
  const calendar = handleAction({ type: 'calendar', title: 'Eat dinner to my caliender', date: '2026-05-09', time: '21:00' });
  assert.strictEqual(calendar[0].calAction.title, 'Eat dinner');
  assert.strictEqual(calendar[1], null);

  const addTask = handleAction({ type: 'add_task', task: 'Check beta links' });
  assert.strictEqual(addTask[1].taskToAdd, 'Check beta links');

  const completeTask = handleAction({ type: 'complete_task', task: 'Check beta links' });
  assert.strictEqual(completeTask[2].taskToDelete, 'Check beta links');

  const hue = handleAction({ type: 'hue', mode: 'party' }, { hueIp: '192.168.1.2', hueKey: 'abc', hueGroup: '1' });
  assert.strictEqual(hue[3], null, 'Hue should safely skip without configured shared state in this isolated harness');

  const deleteEvent = handleAction({ type: 'calendar_delete', title: 'Codex qwen model smoke test from my calendar tomorrow' });
  assert.strictEqual(deleteEvent[4].calDeleteAction.title, 'Codex qwen model smoke test');
});

let passed = 0;
for (const { name, fn } of tests) {
  try {
    fn();
    passed += 1;
    console.log(`PASS ${name}`);
  } catch (err) {
    console.error(`FAIL ${name}`);
    console.error(err && err.stack ? err.stack : err);
    process.exitCode = 1;
    break;
  }
}

if (!process.exitCode) {
  console.log(`\n${passed} command language tests passed.`);
}
