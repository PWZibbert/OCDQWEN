#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-qwen2.5-coder:14b}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://ollama:11434}"
OPENCLAW_HOST="${OPENCLAW_HOST:-0.0.0.0}"
OPENCLAW_PORT="${OPENCLAW_PORT:-8080}"

log() {
  echo "[openclaw] $*"
}

log "start $(date -Iseconds)"
log "model=${MODEL}"
log "ollama=${OLLAMA_BASE_URL}"

for i in $(seq 1 60); do
  if curl -fsS "${OLLAMA_BASE_URL}/api/tags" >/dev/null 2>&1; then
    log "ollama reachable"
    break
  fi
  sleep 2
  if [[ "$i" -eq 60 ]]; then
    log "ERROR: ollama is not reachable"
    exit 1
  fi
done

if ! curl -fsS "${OLLAMA_BASE_URL}/api/tags" | jq -e --arg m "$MODEL" '.models[]?.name == $m' >/dev/null; then
  log "ERROR: model $MODEL is not found in Ollama. Pull it first: ollama pull $MODEL"
  exit 1
fi

if [[ ! -f /data/.openclaw_installed ]]; then
  log "install openclaw via official script"
  curl -fsSL https://openclaw.ai/install.sh -o /tmp/install.sh
  bash /tmp/install.sh > /tmp/install.log 2>&1 || {
    log "install failed; showing tail"
    tail -n 120 /tmp/install.log || true
    exit 1
  }
  touch /data/.openclaw_installed
fi

export PATH="/root/.local/bin:/root/.openclaw/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

if ! command -v openclaw >/dev/null 2>&1; then
  log "ERROR: openclaw binary not found in PATH=${PATH}"
  [[ -f /tmp/install.log ]] && tail -n 120 /tmp/install.log || true
  exit 1
fi

log "openclaw installed: $(command -v openclaw)"
openclaw --help >/tmp/openclaw-help.txt 2>&1 || true

if openclaw --help 2>&1 | grep -qE '(^|[[:space:]])serve([[:space:]]|$)'; then
  log "run: openclaw serve"
  exec openclaw serve --host "$OPENCLAW_HOST" --port "$OPENCLAW_PORT"
fi

if openclaw --help 2>&1 | grep -qE '(^|[[:space:]])start([[:space:]]|$)'; then
  log "run: openclaw start"
  exec openclaw start --host "$OPENCLAW_HOST" --port "$OPENCLAW_PORT"
fi

log "Could not detect runtime command (serve/start)."
log "Container stays alive for manual setup. See /tmp/openclaw-help.txt"
exec tail -f /dev/null
