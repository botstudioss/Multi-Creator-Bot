FROM python:3.11-slim as python-base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY artifacts ./artifacts
COPY lib ./lib

# Install Node dependencies
RUN npm install -g pnpm && \
    pnpm install --frozen-lockfile

# Build the API server artifacts inside the image
RUN pnpm --filter @workspace/api-server run build

# Install Python dependencies
COPY pyproject.toml requirements.txt* ./
RUN pip install --no-cache-dir -q \
    python-telegram-bot \
    psycopg[binary] \
    python-dotenv

# Copy application files
COPY bot.py main.py start.sh ./
COPY bots.json mcp-servers.json* ./
COPY lib ./lib

# Make scripts executable
RUN chmod +x start.sh

# Create logs directory
RUN mkdir -p logs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Set environment variables
ENV NODE_ENV=production
ENV LOG_LEVEL=info
ENV LOG_DIR=/app/logs

# Expose API server port
EXPOSE 3000

# Run the bot
CMD ["bash", "start.sh"]
