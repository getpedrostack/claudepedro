#!/bin/bash
# Prepara as sessoes do Claude Code na nuvem com o que scripts/instalar-extensoes-claude.ps1
# instala no Windows. As skills (d3-viz, webapp-testing) ja vem em .claude/skills e os servidores
# MCP sao declarados em .mcp.json; aqui so se adianta a instalacao para nao atrasar a 1a chamada.
# Cada etapa e independente: se uma falhar, as outras continuam e a sessao abre mesmo assim.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

log() { echo "[session-start] $*" >&2; }
DIR="$CLAUDE_PROJECT_DIR/.claude"

# ---------- 1. Servidores MCP music21 e philosophy ----------
bash "$DIR/mcp/install.sh" all

# ---------- 2. Playwright para Python (skill webapp-testing) ----------
# O Chromium ja vem no container (/opt/pw-browsers); so falta o pacote Python,
# na mesma versao do Playwright pre-instalado para que ele encontre esse navegador.
if python3 -c 'import playwright' >/dev/null 2>&1; then
  log "playwright (python): OK"
else
  PW_VER=$(node -e 'console.log(require("playwright/package.json").version)' 2>/dev/null || true)
  if pip install -q --root-user-action=ignore --break-system-packages "playwright${PW_VER:+==$PW_VER}" >&2 ||
     pip install -q --root-user-action=ignore --break-system-packages playwright >&2; then
    log "playwright (python): OK"
  else
    log "playwright (python): FALHOU"
  fi
fi

# ---------- 3. Plugin superpowers ----------
# .claude/settings.json ja declara o marketplace e habilita o plugin, mas sessoes sem
# interacao nao baixam plugins sozinhas; instalar aqui garante que ele esteja la.
if claude plugin list 2>/dev/null | grep -q 'superpowers@superpowers-marketplace'; then
  log "superpowers: OK"
elif (claude plugin marketplace add obra/superpowers-marketplace >/dev/null 2>&1 || true) &&
     claude plugin install superpowers@superpowers-marketplace >/dev/null 2>&1; then
  log "superpowers: OK"
else
  log "superpowers: FALHOU"
fi

exit 0
