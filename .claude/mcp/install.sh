#!/bin/bash
# Instala os servidores MCP music21 e philosophy nos commits auditados (os mesmos do
# scripts/instalar-extensoes-claude.ps1). Uso: install.sh [music21|philosophy|all]
# Idempotente: se ja estiver instalado no commit certo, sai em menos de 1 segundo.
# Usado pelo hook de inicio de sessao e pelo launch.sh (que instala sob demanda).
set -uo pipefail

BASE="$HOME/claude-extensoes"
MUSIC21_SHA=dd2ca1b10187e1363f5e3c8a9c0c06d40b4f1470
PHILO_SHA=96a39290ac7095db0fe8895b08d3e288c088c73f
VENV="$BASE/music21-venv"
PHILO_DIR="$BASE/src/philosophy-mcp"
PHILO_JS="$PHILO_DIR/dist/index.js"
mkdir -p "$BASE/src"

log() { echo "[claude-extensoes] $*" >&2; }

install_music21() {
  [ -x "$VENV/bin/python" ] || python3 -m venv "$VENV" || return 1
  if [ "$(cat "$VENV/.pin" 2>/dev/null)" != "$MUSIC21_SHA" ]; then
    "$VENV/bin/pip" install -q --upgrade pip >&2 &&
    "$VENV/bin/pip" install -q "git+https://github.com/brightlikethelight/music21-mcp-server.git@$MUSIC21_SHA" >&2 &&
    echo "$MUSIC21_SHA" > "$VENV/.pin" || return 1
  fi
}

# Patches nossos sobre o commit auditado (versionados em patches/, aplicados em ordem).
PATCHES=("$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/patches/philosophy-*.patch)

install_philosophy() {
  if [ ! -d "$PHILO_DIR/.git" ]; then
    git init -q "$PHILO_DIR" && git -C "$PHILO_DIR" remote add origin https://github.com/sea9401/philosophy-mcp.git || return 1
  fi
  local stale=0 p
  [ "$(git -C "$PHILO_DIR" rev-parse HEAD 2>/dev/null)" = "$PHILO_SHA" ] && [ -f "$PHILO_JS" ] || stale=1
  for p in "${PATCHES[@]}"; do   # patch ainda nao aplicado => reinstala
    [ -f "$p" ] && ! git -C "$PHILO_DIR" apply --check --reverse "$p" 2>/dev/null && stale=1
  done
  if [ $stale = 1 ]; then
    { git -C "$PHILO_DIR" fetch -q --depth 1 origin "$PHILO_SHA" || [ "$(git -C "$PHILO_DIR" rev-parse HEAD 2>/dev/null)" = "$PHILO_SHA" ]; } &&
    git -C "$PHILO_DIR" checkout -q -f "$PHILO_SHA" || return 1
    for p in "${PATCHES[@]}"; do
      [ -f "$p" ] && { git -C "$PHILO_DIR" apply "$p" || return 1; }
    done
    (cd "$PHILO_DIR" && npm install --no-audit --no-fund --loglevel=error) >&2 || return 1   # "prepare" ja roda o build
  fi
  [ -f "$PHILO_JS" ]
}

run() {
  if "install_$1"; then log "$1: OK"; else log "$1: FALHOU"; return 1; fi
}

# Hook e launch.sh podem rodar ao mesmo tempo: a trava faz o segundo esperar o primeiro.
exec 9>"$BASE/.install.lock"
command -v flock >/dev/null && flock 9

case "${1:-all}" in
  music21|philosophy) run "$1" ;;
  all) rc=0; run music21 || rc=1; run philosophy || rc=1; exit $rc ;;
  *) log "uso: install.sh [music21|philosophy|all]"; exit 2 ;;
esac
