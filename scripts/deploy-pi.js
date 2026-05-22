#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const DEFAULTS = {
  host: 'caroline-pi',
  user: 'davee',
  remoteDir: '/home/davee/caroline',
  service: 'caroline.service',
  outDir: path.join(ROOT, '.deploy', 'pi'),
};

function usage() {
  console.log(`Usage: node scripts/deploy-pi.js [options]

Options:
  --host <host>          Raspberry Pi host/IP (default: ${DEFAULTS.host})
  --user <user>          SSH user (default: ${DEFAULTS.user})
  --remote-dir <path>    Caroline dir on Pi (default: ${DEFAULTS.remoteDir})
  --service <name>       systemd service name (default: ${DEFAULTS.service})
  --out-dir <path>       Prepared payload dir (default: .deploy/pi)
  --prepare-only         Build deploy files but do not copy/restart
  --no-restart           Copy files but do not restart ${DEFAULTS.service}
  --help                 Show this help
`);
}

function parseArgs(argv) {
  const opts = { ...DEFAULTS, prepareOnly: false, restart: true };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      usage();
      process.exit(0);
    }
    if (arg === '--prepare-only') {
      opts.prepareOnly = true;
      continue;
    }
    if (arg === '--no-restart') {
      opts.restart = false;
      continue;
    }
    const next = argv[++i];
    if (!next) throw new Error(`Missing value for ${arg}`);
    if (arg === '--host') opts.host = next;
    else if (arg === '--user') opts.user = next;
    else if (arg === '--remote-dir') opts.remoteDir = next;
    else if (arg === '--service') opts.service = next;
    else if (arg === '--out-dir') opts.outDir = path.resolve(next);
    else throw new Error(`Unknown option: ${arg}`);
  }
  return opts;
}

function command(name) {
  if (process.platform === 'win32' && (name === 'ssh' || name === 'scp')) {
    return `C:\\Windows\\System32\\OpenSSH\\${name}.exe`;
  }
  return name;
}

function run(cmd, args, options = {}) {
  const result = spawnSync(cmd, args, {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: options.capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
  });
  if (result.error) {
    throw new Error(`${path.basename(cmd)} failed to start: ${result.error.message}`);
  }
  if (result.status !== 0) {
    const detail = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
    const code = result.status === null ? `signal ${result.signal || 'unknown'}` : result.status;
    throw new Error(`${path.basename(cmd)} failed (${code})${detail ? `\n${detail}` : ''}`);
  }
  return result.stdout || '';
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function preparePayload(opts) {
  fs.mkdirSync(opts.outDir, { recursive: true });
  const indexOut = path.join(opts.outDir, 'index.html');
  const flowsOut = path.join(opts.outDir, 'flows.json');
  fs.copyFileSync(path.join(ROOT, 'index.html'), indexOut);
  const sourceFlows = path.join(ROOT, 'flows.json');
  const flows = JSON.parse(fs.readFileSync(sourceFlows, 'utf8'));
  if (!Array.isArray(flows)) throw new Error('flows.json must be a Node-RED flow array');
  fs.copyFileSync(sourceFlows, flowsOut);
  return {
    indexOut,
    flowsOut,
    hashes: {
      'index.html': sha256(indexOut),
      'flows.json': sha256(flowsOut),
    },
  };
}

function parseHashes(output) {
  const hashes = {};
  for (const line of output.trim().split(/\r?\n/).filter(Boolean)) {
    const match = line.match(/^([0-9a-f]{64})\s+(.+)$/i);
    if (match) hashes[path.basename(match[2])] = match[1].toLowerCase();
  }
  return hashes;
}

function serviceState(opts) {
  const remote = `${opts.user}@${opts.host}`;
  return run(command('ssh'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    remote,
    `systemctl --no-pager --plain is-active ${shellQuote(opts.service)}`,
  ], { capture: true }).trim();
}

function verifyRemote(opts, payload) {
  const remote = `${opts.user}@${opts.host}`;
  const output = run(command('ssh'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    remote,
    `sha256sum ${shellQuote(`${opts.remoteDir}/index.html`)} ${shellQuote(`${opts.remoteDir}/flows.json`)}`,
  ], { capture: true });
  const remoteHashes = parseHashes(output);
  for (const [file, hash] of Object.entries(payload.hashes)) {
    if (remoteHashes[file] !== hash) {
      throw new Error(`${file} hash mismatch: remote ${remoteHashes[file] || 'missing'} !== local ${hash}`);
    }
  }
  const state = opts.restart ? serviceState(opts) : 'not-checked';
  if (opts.restart && state !== 'active') throw new Error(`${opts.service} is ${state || 'unknown'}`);
  return { remoteHashes, serviceState: state };
}

function restartService(opts) {
  const remote = `${opts.user}@${opts.host}`;
  const script = [
    'set -e',
    `rm -f ${shellQuote(`${opts.remoteDir}/.config.runtime.json`)} ${shellQuote(`${opts.remoteDir}/.config.nodes.json`)}`,
    `oldpid="$(systemctl --no-pager --plain show ${shellQuote(opts.service)} -p MainPID --value 2>/dev/null || true)"`,
    `if ! sudo -n systemctl restart ${shellQuote(opts.service)} 2>/tmp/caroline-restart-sudo.err; then pid="$oldpid"; case "$pid" in ""|0|*[!0-9]*) echo "Could not determine service MainPID" >&2; cat /tmp/caroline-restart-sudo.err >&2; exit 1;; esac; kill -KILL "$pid"; fi`,
    'sleep 2',
    `i=0; while [ "$i" -lt 40 ]; do state="$(systemctl --no-pager --plain is-active ${shellQuote(opts.service)} 2>/dev/null || true)"; newpid="$(systemctl --no-pager --plain show ${shellQuote(opts.service)} -p MainPID --value 2>/dev/null || true)"; if [ "$state" = "active" ] && [ "$newpid" != "0" ] && [ "$newpid" != "$oldpid" ]; then exit 0; fi; i=$((i+1)); sleep 1; done`,
    `systemctl --no-pager --plain status ${shellQuote(opts.service)} >&2 || true`,
    'exit 1',
  ].join('; ');
  run(command('ssh'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    remote,
    script,
  ]);
}

function deploy(opts, payload) {
  const remote = `${opts.user}@${opts.host}`;
  const ts = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
  run(command('ssh'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    remote,
    [
      'set -e',
      `test -d ${shellQuote(opts.remoteDir)}`,
      `for f in index.html flows.json; do cp -p ${shellQuote(opts.remoteDir)}/$f ${shellQuote(opts.remoteDir)}/$f.codex-backup-${ts}; done`,
    ].join('; '),
  ]);
  run(command('scp'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    payload.indexOut,
    payload.flowsOut,
    `${remote}:${opts.remoteDir}/`,
  ]);
  if (opts.restart) restartService(opts);
  return ts;
}

function main() {
  const opts = parseArgs(process.argv);
  const payload = preparePayload(opts);
  console.log(`Prepared Pi payload in ${path.relative(ROOT, opts.outDir)}`);
  console.log(`Hashes: ${JSON.stringify(payload.hashes)}`);
  if (opts.prepareOnly) return;
  const backupSuffix = deploy(opts, payload);
  const verified = verifyRemote(opts, payload);
  console.log(JSON.stringify({
    host: opts.host,
    user: opts.user,
    remoteDir: opts.remoteDir,
    backupSuffix: `codex-backup-${backupSuffix}`,
    hashes: verified.remoteHashes,
    service: verified.serviceState,
  }, null, 2));
}

try {
  main();
} catch (error) {
  console.error(error.message || error);
  process.exit(1);
}
