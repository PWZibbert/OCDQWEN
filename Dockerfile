FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl ca-certificates bash git jq iproute2 procps findutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV MODEL=qwen2.5-coder:14b
ENV OLLAMA_BASE_URL=http://ollama:11434
ENV OPENAI_BASE_URL=http://ollama:11434/v1
ENV OPENAI_API_KEY=ollama

ENTRYPOINT ["/entrypoint.sh"]