#!/usr/bin/env node
// Inicia um servidor MCP instalado em ~/claude-extensoes. Uso: node launch.mjs <music21|philosophy>
// Funciona nos dois lugares onde o repositorio e usado:
//   - Windows: usa o que scripts/instalar-extensoes-claude.ps1 instalou;
//   - Linux (sessoes na nuvem): se ainda nao estiver instalado, roda install.sh antes.
// stdout e o canal do protocolo MCP: tudo que nao for do servidor vai para stderr.
import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const name = process.argv[2];
const base = join(homedir(), 'claude-extensoes');
const win = process.platform === 'win32';

const servers = {
  music21: {
    file: win ? join(base, 'music21-venv', 'Scripts', 'python.exe') : join(base, 'music21-venv', 'bin', 'python'),
    args: ['-m', 'music21_mcp.server_minimal'],
  },
  philosophy: {
    file: join(base, 'src', 'philosophy-mcp', 'dist', 'index.js'),
    args: [],
  },
};

const server = servers[name];
if (!server) {
  console.error(`uso: node launch.mjs <${Object.keys(servers).join('|')}>`);
  process.exit(2);
}

if (!existsSync(server.file)) {
  if (win) {
    console.error(`${name} nao instalado. Rode: powershell -ExecutionPolicy Bypass -File scripts\\instalar-extensoes-claude.ps1`);
    process.exit(1);
  }
  const installer = join(dirname(fileURLToPath(import.meta.url)), 'install.sh');
  spawnSync('bash', [installer, name], { stdio: ['ignore', 2, 2] });
  if (!existsSync(server.file)) process.exit(1);
}

const [cmd, args] = name === 'philosophy'
  ? [process.execPath, [server.file, ...server.args]]
  : [server.file, server.args];
const child = spawn(cmd, args, { stdio: 'inherit' });
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => child.kill(sig));
child.on('exit', (code, sig) => process.exit(sig ? 1 : code ?? 0));
