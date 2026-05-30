#!/usr/bin/env node
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const DEFAULTS = {
  host: 'steamdeck',
  user: 'deck',
  remoteDir: '/home/deck/caroline',
  port: '8080',
  outDir: path.join(ROOT, '.deploy', 'steamos'),
};

function usage() {
  console.log(`Usage: node scripts/deploy-steamos.js [options]

Options:
  --host <host>          Steam Deck host/IP (default: ${DEFAULTS.host})
  --user <user>          SSH user (default: ${DEFAULTS.user})
  --remote-dir <path>    Caroline dir on Deck (default: ${DEFAULTS.remoteDir})
  --port <port>          Caroline/Node-RED port (default: ${DEFAULTS.port})
  --out-dir <path>       Prepared payload dir (default: .deploy/steamos)
  --prepare-only         Build Deck-safe files but do not copy/restart
  --no-restart           Copy files but do not restart caroline.service
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
    else if (arg === '--port') opts.port = next;
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

function gitValue(args, fallback = 'unknown') {
  const result = spawnSync('git', args, { cwd: ROOT, encoding: 'utf8' });
  if (result.status !== 0) return fallback;
  return (result.stdout || '').trim() || fallback;
}

function projectVersion() {
  const install = fs.readFileSync(path.join(ROOT, 'install.sh'), 'utf8');
  const match = install.match(/^CAROLINE_VERSION="([^"]+)"/m);
  return match ? match[1] : '0.3.0-dev';
}

function stampBuildMetadata(opts) {
  const remote = `${opts.user}@${opts.host}`;
  const script = [
    `BUILD_FILE=${shellQuote(`${opts.remoteDir}/caroline_build.json`)} \\`,
    `BUILD_VERSION=${shellQuote(projectVersion())} \\`,
    `BUILD_COMMIT=${shellQuote(gitValue(['rev-parse', '--short', 'HEAD']))} \\`,
    `BUILD_BRANCH=${shellQuote('nightly')} \\`,
    `BUILD_CHANNEL=${shellQuote('nightly')} \\`,
    `BUILD_REPO=${shellQuote(gitValue(['config', '--get', 'remote.origin.url'], 'https://github.com/Project-Caroline/project-caroline.git'))} \\`,
    `node <<'NODE'`,
    `const fs = require('fs');`,
    `const file = process.env.BUILD_FILE;`,
    `let build = {};`,
    `try { build = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (error) { build = {}; }`,
    `build.version = process.env.BUILD_VERSION;`,
    `build.commit = process.env.BUILD_COMMIT;`,
    `build.branch = process.env.BUILD_BRANCH;`,
    `build.channel = process.env.BUILD_CHANNEL;`,
    `build.repo = process.env.BUILD_REPO;`,
    `build.installedAt = new Date().toISOString();`,
    `fs.writeFileSync(file, JSON.stringify(build, null, 2) + '\\n');`,
    `NODE`,
  ].join('\n');
  run(command('ssh'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    remote,
    script,
  ]);
  return {
    version: projectVersion(),
    commit: gitValue(['rev-parse', '--short', 'HEAD']),
    branch: 'nightly',
    channel: 'nightly',
  };
}

function transformString(value, opts) {
  return value
    .replaceAll('/home/davee/caroline', opts.remoteDir)
    .replaceAll('127.0.0.1:1880', `127.0.0.1:${opts.port}`)
    .replaceAll('localhost:1880', `localhost:${opts.port}`);
}

function transformValue(value, opts) {
  if (typeof value === 'string') return transformString(value, opts);
  if (Array.isArray(value)) return value.map(item => transformValue(item, opts));
  if (value && typeof value === 'object') {
    const out = {};
    for (const [key, nested] of Object.entries(value)) out[key] = transformValue(nested, opts);
    return out;
  }
  return value;
}

function makeSteamOsFlow(opts) {
  const sourcePath = path.join(ROOT, 'flows.json');
  const unsupportedTypes = new Set(['gauth', 'google-credentials']);
  const raw = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
  if (!Array.isArray(raw)) throw new Error('flows.json must be a Node-RED flow array');

  const flow = [];
  let removedUnsupported = 0;
  for (const originalNode of raw) {
    if (!originalNode || unsupportedTypes.has(originalNode.type)) {
      removedUnsupported += 1;
      continue;
    }
    const node = transformValue(originalNode, opts);
    if (node.type === 'global-config' && node.modules) {
      delete node.modules['node-red-contrib-google-calendar'];
      delete node.modules['node-red-contrib-google-sheets'];
      if (Object.keys(node.modules).length === 0) delete node.modules;
    }
    if (node.id === '2d3a474f10541125' && node.type === 'exec') {
      node.name = 'Restart Caroline user service';
      node.command = "bash -lc 'nohup bash -lc \"sleep 1; systemctl --user restart caroline.service\" >/tmp/caroline-restart.log 2>&1 &'";
    }
    flow.push(node);
  }
  return { flow, removedUnsupported };
}

function preparePayload(opts) {
  fs.mkdirSync(opts.outDir, { recursive: true });
  const indexOut = path.join(opts.outDir, 'index.html');
  const flowsOut = path.join(opts.outDir, 'flows.json');
  fs.copyFileSync(path.join(ROOT, 'index.html'), indexOut);
  const { flow, removedUnsupported } = makeSteamOsFlow(opts);
  fs.writeFileSync(flowsOut, JSON.stringify(flow, null, 2) + os.EOL);
  return {
    indexOut,
    flowsOut,
    removedUnsupported,
    hashes: {
      'index.html': sha256(indexOut),
      'flows.json': sha256(flowsOut),
    },
  };
}

function verifyRemote(opts, payload) {
  const remote = `${opts.user}@${opts.host}`;
  const output = run(command('ssh'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    remote,
    `sha256sum ${shellQuote(`${opts.remoteDir}/index.html`)} ${shellQuote(`${opts.remoteDir}/flows.json`)}; if [ -f ${shellQuote(`${opts.remoteDir}/public/index.html`)} ]; then sha256sum ${shellQuote(`${opts.remoteDir}/public/index.html`)}; fi; systemctl --user is-active caroline.service`,
  ], { capture: true });
  const lines = output.trim().split(/\r?\n/).filter(Boolean);
  const remoteHashes = {};
  for (const line of lines) {
    const match = line.match(/^([0-9a-f]{64})\s+(.+)$/i);
    if (match) remoteHashes[path.basename(match[2])] = match[1].toLowerCase();
  }
  for (const [file, hash] of Object.entries(payload.hashes)) {
    if (remoteHashes[file] !== hash) {
      throw new Error(`${file} hash mismatch: remote ${remoteHashes[file] || 'missing'} !== local ${hash}`);
    }
  }
  const serviceState = lines[lines.length - 1];
  if (opts.restart && serviceState !== 'active') throw new Error(`caroline.service is ${serviceState || 'unknown'}`);
  return { remoteHashes, serviceState };
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
      `if [ -f ${shellQuote(`${opts.remoteDir}/public/index.html`)} ]; then cp -p ${shellQuote(`${opts.remoteDir}/public/index.html`)} ${shellQuote(`${opts.remoteDir}/public/index.html.codex-backup-${ts}`)}; fi`,
    ].join('; '),
  ]);
  run(command('scp'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    payload.indexOut,
    payload.flowsOut,
    `${remote}:${opts.remoteDir}/`,
  ]);
  run(command('ssh'), [
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=8',
    remote,
    `if [ -d ${shellQuote(`${opts.remoteDir}/public`)} ]; then cp -p ${shellQuote(`${opts.remoteDir}/index.html`)} ${shellQuote(`${opts.remoteDir}/public/index.html`)}; fi`,
  ]);
  stampBuildMetadata(opts);
  if (opts.restart) {
    run(command('ssh'), [
      '-o', 'BatchMode=yes',
      '-o', 'ConnectTimeout=8',
      remote,
      `rm -f ${shellQuote(`${opts.remoteDir}/.config.runtime.json`)} ${shellQuote(`${opts.remoteDir}/.config.nodes.json`)}; systemctl --user restart caroline.service; sleep 4`,
    ]);
  }
  return ts;
}

function main() {
  const opts = parseArgs(process.argv);
  const payload = preparePayload(opts);
  console.log(`Prepared SteamOS payload in ${path.relative(ROOT, opts.outDir)}`);
  console.log(`Removed unsupported config nodes: ${payload.removedUnsupported}`);
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
