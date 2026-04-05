#!/usr/bin/env bash
set -euo pipefail

echo "[openclaw] start $(date -Iseconds)"

# Ожидание Ollama
for i in $(seq 1 30); do
  if curl -fsS "${OLLAMA_BASE_URL:-http://ollama:11434}/api/tags" >/dev/null 2>&1; then
    echo "[openclaw] ollama reachable"
    break
  fi
  sleep 2
done

# Установка (если нет маркера)
if [[ ! -f /data/.openclaw_installed ]]; then
  echo "[openclaw] installing..."
  curl -fsSL https://openclaw.ai/install.sh -o /tmp/install.sh
  bash -x /tmp/install.sh > /tmp/install.log 2>&1 || {
    echo "[openclaw] install failed; tail log:"
    tail -n 120 /tmp/install.log || true
    exit 1
  }
  touch /data/.openclaw_installed
fi

# Подхватываем типовые пути
export PATH="/root/.local/bin:/root/.openclaw/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Проверка наличия CLI
if ! command -v openclaw >/dev/null 2>&1; then
  echo "[openclaw] ERROR: openclaw not found in PATH"
  echo "[openclaw] PATH=$PATH"
  echo "[openclaw] searching candidate files..."
  find / -type f \( -name "openclaw" -o -name "*claw*" \) 2>/dev/null | head -n 200 || true
  [[ -f /tmp/install.log ]] && tail -n 120 /tmp/install.log || true
  exit 1
fi

openclaw --help || true

# Когда узнаем точную команду из --help, запускаем сервис:
# exec openclaw serve --host 0.0.0.0 --port 8080
exec tail -f /dev/null