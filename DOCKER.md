# Docker Deployment Guide

This guide explains how to run Poll Master Bot using Docker for reliable 24/7 operation.

## Quick Start

### 1. Create `.env` file

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
TELEGRAM_BOT_TOKEN=your_token_here
POLLING_CHANNEL_ID=-1001003969510942
ADMIN_IDS=123456789

# Database credentials
DB_USER=pollmaster
DB_PASSWORD=securepassword123
DB_NAME=pollmasterbot
```

### 2. Build and Run with Docker Compose (Recommended)

```bash
# Build the image
docker-compose build

# Start services (bot + database)
docker-compose up -d

# View logs
docker-compose logs -f pollmasterbot

# Stop services
docker-compose down
```

### 3. Verify it's Running

```bash
# Check if container is running
docker-compose ps

# Test health endpoint
curl http://localhost:3000/health

# View bot logs
docker-compose logs pollmasterbot

# Connect to database (optional)
docker-compose exec postgres psql -U pollmaster -d pollmasterbot
```

---

## Manual Docker Commands

If you prefer not to use Docker Compose:

### Build Image

```bash
docker build -t pollmasterbot:latest .
```

### Run Bot Only (with existing database)

```bash
docker run -d \
  --name pollmasterbot \
  --restart unless-stopped \
  -e TELEGRAM_BOT_TOKEN="your_token" \
  -e POLLING_CHANNEL_ID="-1001003969510942" \
  -e DATABASE_URL="postgresql://user:password@db-host:5432/pollmasterbot" \
  -e NODE_ENV="production" \
  -v /path/to/logs:/app/logs \
  -p 3000:3000 \
  pollmasterbot:latest
```

### Run with PostgreSQL

```bash
# Create network
docker network create pollmaster-net

# Run PostgreSQL
docker run -d \
  --name pollmaster-db \
  --network pollmaster-net \
  --restart unless-stopped \
  -e POSTGRES_USER=pollmaster \
  -e POSTGRES_PASSWORD=securepassword \
  -e POSTGRES_DB=pollmasterbot \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:15-alpine

# Run bot
docker run -d \
  --name pollmasterbot \
  --network pollmaster-net \
  --restart unless-stopped \
  -e TELEGRAM_BOT_TOKEN="your_token" \
  -e POLLING_CHANNEL_ID="-1001003969510942" \
  -e DATABASE_URL="postgresql://pollmaster:securepassword@pollmaster-db:5432/pollmasterbot" \
  -v /path/to/logs:/app/logs \
  -p 3000:3000 \
  pollmasterbot:latest
```

---

## Container Management

### View Logs

```bash
# Real-time logs
docker logs -f pollmasterbot

# Last 100 lines
docker logs --tail 100 pollmasterbot

# Logs with timestamps
docker logs -f --timestamps pollmasterbot
```

### Container Status

```bash
# List all containers
docker ps -a

# Inspect container
docker inspect pollmasterbot

# Container stats
docker stats pollmasterbot
```

### Restart/Stop

```bash
# Restart container
docker restart pollmasterbot

# Stop container
docker stop pollmasterbot

# Start stopped container
docker start pollmasterbot

# Remove container
docker rm -f pollmasterbot
```

---

## Production Best Practices

### 1. Use Docker Compose

```bash
docker-compose up -d
```

Benefits:
- Manages both bot and database
- Automatic restart on failure
- Easy scaling and configuration
- Built-in networking

### 2. Volume Management

Persist data outside container:

```yaml
volumes:
  - ./logs:/app/logs          # Bot logs
  - postgres_data:/data       # Database
  - ./.env:/app/.env:ro       # Configuration (read-only)
```

### 3. Resource Limits

Set in `docker-compose.yml`:

```yaml
services:
  pollmasterbot:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### 4. Health Checks

Automatic monitoring:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

### 5. Restart Policies

```yaml
restart: unless-stopped    # Auto-restart on crash
```

Options:
- `no` - Don't restart
- `always` - Always restart
- `unless-stopped` - Restart unless explicitly stopped
- `on-failure` - Restart only on exit code

### 6. Logging

Automatic log rotation:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "50m"
    max-file: "10"
```

---

## Multi-Instance Deployment

Run multiple bots with different configurations:

```yaml
services:
  bot1:
    build: .
    container_name: bot1
    environment:
      TELEGRAM_BOT_TOKEN: ${BOT1_TOKEN}
      POLLING_CHANNEL_ID: ${BOT1_CHANNEL}
    # ... other config

  bot2:
    build: .
    container_name: bot2
    environment:
      TELEGRAM_BOT_TOKEN: ${BOT2_TOKEN}
      POLLING_CHANNEL_ID: ${BOT2_CHANNEL}
    # ... other config
```

---

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs pollmasterbot

# Check if port 3000 is in use
docker ps | grep 3000

# Check environment variables
docker inspect pollmasterbot | grep -A 20 "Env"
```

### Database connection error

```bash
# Test database connectivity
docker-compose exec pollmasterbot \
  psql -h postgres -U pollmaster -d pollmasterbot -c "SELECT 1"

# Check database logs
docker logs pollmaster-db
```

### Out of memory

```bash
# Check container memory usage
docker stats pollmasterbot

# Increase memory limit in docker-compose.yml
# Or restart container:
docker-compose down
docker-compose up -d
```

### Permission denied

```bash
# Fix volume permissions
docker exec pollmasterbot chmod 755 /app/logs
```

---

## Monitoring with External Tools

### Docker Hub Integration

```bash
# Tag image
docker tag pollmasterbot:latest username/pollmasterbot:latest

# Push to Docker Hub
docker push username/pollmasterbot:latest
```

### Portainer (GUI Management)

```bash
docker run -d \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  portainer/portainer-ce:latest
```

Then access at `http://localhost:9000`

### Prometheus Monitoring

Export metrics:

```bash
# Install container exporter
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
```

---

## Deployment to Cloud Services

### AWS ECS

1. Push image to ECR:
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

docker tag pollmasterbot:latest \
  <account>.dkr.ecr.us-east-1.amazonaws.com/pollmasterbot:latest

docker push <account>.dkr.ecr.us-east-1.amazonaws.com/pollmasterbot:latest
```

2. Create ECS task definition and service

### Azure Container Instances

```bash
az container create \
  --resource-group mygroup \
  --name pollmasterbot \
  --image pollmasterbot:latest \
  --environment-variables \
    TELEGRAM_BOT_TOKEN="token" \
    POLLING_CHANNEL_ID="-1001003969510942"
```

### Google Cloud Run

```bash
gcloud run deploy pollmasterbot \
  --image pollmasterbot:latest \
  --set-env-vars TELEGRAM_BOT_TOKEN="token",POLLING_CHANNEL_ID="-1001003969510942"
```

---

## Database Backup

### Backup PostgreSQL

```bash
# Docker Compose
docker-compose exec postgres \
  pg_dump -U pollmaster pollmasterbot > backup.sql

# Or with docker
docker exec pollmaster-db \
  pg_dump -U pollmaster pollmasterbot > backup.sql
```

### Restore PostgreSQL

```bash
# Stop running container
docker-compose down

# Remove old database
docker volume rm postgres_data

# Start services
docker-compose up -d

# Restore backup
docker-compose exec -T postgres \
  psql -U pollmaster pollmasterbot < backup.sql
```

---

## Cleanup

### Remove unused resources

```bash
# Remove unused images
docker image prune

# Remove unused containers
docker container prune

# Remove unused volumes
docker volume prune

# Remove all unused (images, containers, volumes, networks)
docker system prune -a
```

### Complete cleanup

```bash
# Stop and remove docker compose
docker-compose down

# Remove volumes
docker-compose down -v

# Remove image
docker rmi pollmasterbot:latest
```

---

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TELEGRAM_BOT_TOKEN` | Yes | - | Telegram bot token |
| `POLLING_CHANNEL_ID` | Yes | - | Default channel ID |
| `ADMIN_IDS` | No | - | Comma-separated admin IDs |
| `DATABASE_URL` | No | - | PostgreSQL connection string |
| `NODE_ENV` | No | production | Environment mode |
| `LOG_LEVEL` | No | info | Logging level |
| `DB_USER` | No | pollmaster | Database username (docker-compose) |
| `DB_PASSWORD` | No | changeme | Database password (docker-compose) |
| `DB_NAME` | No | pollmasterbot | Database name (docker-compose) |

---

## Performance Tips

1. **Use Alpine images** - Smaller, faster base images
2. **Multi-stage builds** - Reduce final image size
3. **Cache layers** - Order Dockerfile commands efficiently
4. **Resource limits** - Prevent resource exhaustion
5. **Health checks** - Enable automatic restarts
6. **Log rotation** - Prevent disk space issues

---

## Security Best Practices

1. **Don't hardcode secrets** - Use `.env` files
2. **Use .dockerignore** - Exclude sensitive files
3. **Run as non-root** - Add user in Dockerfile
4. **Security scanning** - `docker scan pollmasterbot`
5. **Private registry** - For production images
6. **Network isolation** - Use networks for services

---

## Further Reading

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Best Practices for Node.js/Python in Docker](https://docs.docker.com/language/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)

---

**Your bot is ready for containerized 24/7 deployment!** 🐳
