FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    bash \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    findutils \
    git \
    iproute2 \
    jq \
    procps \
    python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV MODEL=qwen2.5-coder:14b
ENV OLLAMA_BASE_URL=http://ollama:11434
ENV OPENAI_BASE_URL=http://ollama:11434/v1
ENV OPENAI_API_KEY=ollama
ENV OPENCLAW_HOST=0.0.0.0
ENV OPENCLAW_PORT=8080

ENTRYPOINT ["/entrypoint.sh"]
