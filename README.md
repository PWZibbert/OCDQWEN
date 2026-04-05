# Ollama (Qwen2.5:14B) + OpenClaw в Docker Compose

Готовая конфигурация из **2 основных контейнеров**:

1. `ollama` — локальная LLM на GPU (модель `qwen2.5-coder:14b`).
2. `openclaw` — агент, который использует Ollama как backend (`OPENAI_BASE_URL=http://ollama:11434/v1`).

Дополнительно есть одноразовый контейнер `ollama-init`, который автоматически подтягивает модель и делает smoke-test.

## Что нужно на хосте

- Docker + Docker Compose plugin.
- NVIDIA драйверы.
- NVIDIA Container Toolkit (чтобы `docker` видел GPU).

Проверка GPU в Docker:

```bash
docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi
```

## Быстрый запуск

```bash
docker compose up -d --build
```

Проверить статусы:

```bash
docker compose ps
```

Ожидаем:
- `ollama` — `healthy`
- `ollama-init` — `exited (0)`
- `openclaw` — `running`

## Как убедиться, что Qwen работает

### 1) Модель загружена

```bash
docker compose exec ollama ollama list
```

В списке должна быть `qwen2.5-coder:14b`.

### 2) Запрос к LLM через HTTP API

```bash
curl -s http://localhost:11434/api/generate \
  -d '{
    "model":"qwen2.5-coder:14b",
    "prompt":"Ответь одним словом: работает ли модель?",
    "stream": false
  }' | jq -r '.response'
```

### 3) Проверка OpenAI-совместимого endpoint

```bash
curl -s http://localhost:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer ollama' \
  -d '{
    "model": "qwen2.5-coder:14b",
    "messages": [{"role":"user","content":"Напиши OK"}],
    "temperature": 0
  }' | jq -r '.choices[0].message.content'
```

## Как настроен OpenClaw

В контейнер `openclaw` передаются переменные:

- `MODEL=qwen2.5-coder:14b`
- `OLLAMA_BASE_URL=http://ollama:11434`
- `OPENAI_BASE_URL=http://ollama:11434/v1`
- `OPENAI_API_KEY=ollama`

`entrypoint.sh` делает:
1. Ждёт доступность Ollama.
2. Проверяет, что модель уже существует в Ollama.
3. Ставит OpenClaw через официальный install script (в non-interactive режиме).
4. Если CLI уже установлен, повторной установки не делает.
5. Пытается запустить OpenClaw (`serve` или `start`).

## Важно для Windows PowerShell

В PowerShell `curl` — это alias на `Invoke-WebRequest` (не поддерживает флаги `-fsSL`).

Используйте:

```powershell
curl.exe -fsSL https://openclaw.ai/install.sh | bash
```

или запуск из Git Bash/WSL.

## Ручная донастройка OpenClaw

Если нужно зайти в контейнер без entrypoint, используйте:

```bash
docker compose run --rm --entrypoint bash openclaw
```

Проверка CLI:

```bash
openclaw --help || claw --help
cat /tmp/openclaw-help.txt
```

Логи:

```bash
docker compose logs -f openclaw
```

## Полезные команды

Остановить:

```bash
docker compose down
```

Остановить и удалить тома (полный сброс):

```bash
docker compose down -v
```
