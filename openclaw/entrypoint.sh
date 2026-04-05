#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-qwen2.5-coder:14b}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://ollama:11434}"
OPENCLAW_HOST="${OPENCLAW_HOST:-0.0.0.0}"
OPENCLAW_PORT="${OPENCLAW_PORT:-8080}"

log() {
  echo "[openclaw] $*"
}

# Позволяет запускать контейнер как утилитарный (например: docker compose run --rm openclaw bash)
if [[ "$#" -gt 0 ]]; then
  exec "$@"
fi

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

export PATH="/root/.local/bin:/root/.openclaw/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

find_openclaw_cmd() {
  if command -v openclaw >/dev/null 2>&1; then
    echo "openclaw"
    return
  fi
  if command -v claw >/dev/null 2>&1; then
    echo "claw"
    return
  fi
  echo ""
}


cleanup_node_conflicts() {
  if dpkg -s nodejs >/dev/null 2>&1 || dpkg -s libnode-dev >/dev/null 2>&1 || dpkg -s npm >/dev/null 2>&1; then
    log "remove distro node packages to avoid NodeSource conflicts"
    apt-get update >/dev/null 2>&1 || true
    apt-get remove -y nodejs libnode-dev nodejs-doc npm >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
    rm -rf /var/lib/apt/lists/* || true
  fi
}

install_openclaw() {
  log "install openclaw via official script"
  cleanup_node_conflicts
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh -o /tmp/install.sh
  if ! CI=1 OPENCLAW_NO_PROMPT=1 OPENCLAW_NO_ONBOARD=1 \
    bash /tmp/install.sh --no-prompt --no-onboard --install-method npm \
    2>&1 | tee /tmp/install.log; then
    log "install failed; showing tail"
    tail -n 120 /tmp/install.log || true
    return 1
  fi
  return 0
}

openclaw_cmd="$(find_openclaw_cmd)"

if [[ ! -f /data/.openclaw_installed ]] || [[ -z "$openclaw_cmd" ]]; then
  if ! install_openclaw; then
    exit 1
  fi
  openclaw_cmd="$(find_openclaw_cmd)"
  if [[ -n "$openclaw_cmd" ]]; then
    touch /data/.openclaw_installed
  fi
fi

if [[ -z "$openclaw_cmd" ]]; then
  log "ERROR: openclaw binary not found in PATH=${PATH}"
  [[ -f /tmp/install.log ]] && tail -n 120 /tmp/install.log || true
  exit 1
fi

log "openclaw CLI: ${openclaw_cmd}"
"${openclaw_cmd}" --help >/tmp/openclaw-help.txt 2>&1 || true

if "${openclaw_cmd}" --help 2>&1 | grep -qE '(^|[[:space:]])serve([[:space:]]|$)'; then
  log "run: ${openclaw_cmd} serve"
  exec "${openclaw_cmd}" serve --host "$OPENCLAW_HOST" --port "$OPENCLAW_PORT"
fi

if "${openclaw_cmd}" --help 2>&1 | grep -qE '(^|[[:space:]])start([[:space:]]|$)'; then
  log "run: ${openclaw_cmd} start"
  exec "${openclaw_cmd}" start --host "$OPENCLAW_HOST" --port "$OPENCLAW_PORT"
fi

log "Could not detect runtime command (serve/start)."
log "Container stays alive for manual setup. See /tmp/openclaw-help.txt"
exec tail -f /dev/null
