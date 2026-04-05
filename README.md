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
- `openclaw` — `running` (или `running`, но может ждать ручной команды, если CLI отличается)

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

Если получен осмысленный ответ — контейнер с LLM готов к работе.

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
3. Ставит OpenClaw через официальный install script.
4. Пытается запустить OpenClaw (`serve` или `start`, если такая команда есть в вашей версии CLI).
5. Если команда запуска не найдена — оставляет контейнер живым для ручной настройки.

## Ручная донастройка OpenClaw (если понадобилась)

Посмотреть логи:

```bash
docker compose logs -f openclaw
```

Зайти внутрь контейнера:

```bash
docker compose exec openclaw bash
```

Посмотреть доступные команды:

```bash
openclaw --help
cat /tmp/openclaw-help.txt
```

Запустить вручную (пример):

```bash
openclaw serve --host 0.0.0.0 --port 8080
```

## Если хотите «в одном образе»

Технически возможно собрать единый кастомный образ с Ollama+OpenClaw, но это хуже для эксплуатации:
- сложнее обновлять и дебажить;
- нарушается принцип «один процесс = один контейнер»;
- труднее управлять GPU/перезапусками.

Текущая схема в одном `docker-compose.yaml` — минимально сложная и наиболее практичная.

## Полезные команды

Остановить:

```bash
docker compose down
```

Остановить и удалить тома (полный сброс):

```bash
docker compose down -v
```
