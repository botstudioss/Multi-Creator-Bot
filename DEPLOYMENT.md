# Poll Master Bot - 24/7 Production Deployment Guide

This guide explains how to run the Poll Master Bot 24/7 with MCP server support.

## Quick Start

### Prerequisites

1. **Python 3.8+** - Required for the Telegram bot
2. **Node.js 18+** - Required for the API server
3. **PostgreSQL** - Recommended for persistent state across restarts
4. **Git Bash** (Windows only) - For running shell scripts

### Environment Setup

1. **Copy and configure `.env` file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your settings:**
   ```
   TELEGRAM_BOT_TOKEN=your_token_here
   POLLING_CHANNEL_ID=-1001003969510942
   ADMIN_IDS=your_admin_ids_here
   DATABASE_URL=postgresql://user:password@localhost:5432/pollmasterbot
   NODE_ENV=production
   ```

3. **Verify MCP servers configuration in `mcp-servers.json`:**
   The file already contains your X-User-Identity token for justrunmy.app

---

## Windows Deployment (24/7 with Windows Service)

### Option 1: Automated Setup (Recommended)

1. **Download and install NSSM:**
   - Download from: https://nssm.cc/download
   - Extract to `C:\nssm`
   - Or modify the path in `install-service-windows.bat`

2. **Install as Windows Service:**
   - Right-click `install-service-windows.bat` → Run as Administrator
   - The script will:
     - Install the service named "PollMasterBot"
     - Configure auto-start on boot
     - Set up automatic restarts on failure
     - Create log directory

3. **Verify service is running:**
   ```bash
   net start PollMasterBot
   net stop PollMasterBot
   ```

4. **View logs:**
   - Check `logs/pollmasterbot.log` for normal output
   - Check `logs/pollmasterbot.error.log` for errors

### Option 2: Manual Windows Service Setup

If you prefer manual setup:

```powershell
# Install NSSM first (see above)

# Navigate to project directory
cd C:\Users\rolan\Downloads\Poll-Master-Bot

# Install service
C:\nssm\nssm.exe install PollMasterBot "C:\Program Files\Git\bin\bash.exe" -c "cd /d $(pwd) && bash start.sh"

# Configure service
C:\nssm\nssm.exe set PollMasterBot Start SERVICE_AUTO_START
C:\nssm\nssm.exe set PollMasterBot AppDirectory "C:\Users\rolan\Downloads\Poll-Master-Bot"
C:\nssm\nssm.exe set PollMasterBot AppStdout "C:\Users\rolan\Downloads\Poll-Master-Bot\logs\stdout.log"
C:\nssm\nssm.exe set PollMasterBot AppStderr "C:\Users\rolan\Downloads\Poll-Master-Bot\logs\stderr.log"

# Start service
net start PollMasterBot
```

### Management Commands (Windows)

```powershell
# Start service
net start PollMasterBot

# Stop service
net stop PollMasterBot

# View status
nssm status PollMasterBot

# Remove service (if needed)
nssm remove PollMasterBot confirm
```

Or use **Services.msc** for GUI management.

---

## Linux Deployment (24/7 with systemd)

### Setup Instructions

1. **Copy project to production location:**
   ```bash
   sudo cp -r /path/to/Poll-Master-Bot /opt/Poll-Master-Bot
   sudo chown -R pollmasterbot:pollmasterbot /opt/Poll-Master-Bot
   ```

2. **Create system user (optional):**
   ```bash
   sudo useradd -r -s /bin/bash pollmasterbot
   ```

3. **Copy systemd service file:**
   ```bash
   sudo cp pollmasterbot.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

4. **Enable and start service:**
   ```bash
   sudo systemctl enable pollmasterbot
   sudo systemctl start pollmasterbot
   ```

5. **Verify service is running:**
   ```bash
   sudo systemctl status pollmasterbot
   ```

### Management Commands (Linux)

```bash
# Start service
sudo systemctl start pollmasterbot

# Stop service
sudo systemctl stop pollmasterbot

# Restart service
sudo systemctl restart pollmasterbot

# View status
sudo systemctl status pollmasterbot

# View logs
sudo journalctl -u pollmasterbot -f

# Disable auto-start
sudo systemctl disable pollmasterbot
```

---

## Docker Deployment (Optional)

If you want to run in Docker:

```bash
# Build image
docker build -t pollmasterbot:latest .

# Run container with 24/7 restart
docker run -d \
  --name pollmasterbot \
  --restart unless-stopped \
  -e TELEGRAM_BOT_TOKEN="your_token" \
  -e POLLING_CHANNEL_ID="-1001003969510942" \
  -e DATABASE_URL="postgresql://user:password@host:5432/db" \
  -v /path/to/logs:/app/logs \
  pollmasterbot:latest
```

---

## MCP Server Integration

The bot now includes support for MCP (Model Context Protocol) servers:

### Configuration

Your MCP server configuration is stored in `mcp-servers.json`:

```json
{
  "mcpServers": {
    "justrunmy.app": {
      "url": "https://justrunmy.app/api/mcp",
      "headers": {
        "X-User-Identity": "your_token_here"
      }
    }
  }
}
```

### Usage in Bot Code

To integrate MCP functionality in `bot.py`:

```python
import json
from pathlib import Path

# Load MCP configuration
mcp_config_path = Path("mcp-servers.json")
if mcp_config_path.exists():
    mcp_config = json.loads(mcp_config_path.read_text())
    mcp_servers = mcp_config.get("mcpServers", {})
    # Use mcp_servers in your code
```

---

## Monitoring & Health Checks

### Log Files

**Windows:**
- `logs/pollmasterbot.log` - Normal output
- `logs/pollmasterbot.error.log` - Error output
- `logs/pollmasterbot.pid` - Process ID

**Linux:**
```bash
# View logs
sudo journalctl -u pollmasterbot -f

# View last 100 lines
sudo journalctl -u pollmasterbot -n 100
```

### Health Check Endpoint

The API server includes a health check endpoint:
- **URL:** `http://localhost:3000/health`
- **Response:** `{"status": "ok"}`

### Monitoring Best Practices

1. **Enable PostgreSQL for persistent state:**
   - Ensures configuration survives restarts
   - Persists poll history and user data

2. **Monitor service restarts:**
   - Check logs for repeated crashes
   - Indicates configuration or resource issues

3. **Set up log rotation:**
   - Use `logrotate` (Linux) or built-in Windows log management
   - Prevents disk space issues

---

## Troubleshooting

### Service won't start

1. **Check environment variables:**
   ```bash
   # Windows
   echo %TELEGRAM_BOT_TOKEN%
   
   # Linux
   echo $TELEGRAM_BOT_TOKEN
   ```

2. **Verify .env file:**
   - Check permissions: `ls -la .env`
   - Ensure all required variables are set

3. **Check logs:**
   - Windows: `logs/pollmasterbot.error.log`
   - Linux: `sudo journalctl -u pollmasterbot`

### Bot not responding

1. **Check if processes are running:**
   ```bash
   # Windows
   tasklist | findstr "python node"
   
   # Linux
   ps aux | grep -E "python|node"
   ```

2. **Verify network connectivity:**
   - Check firewall rules
   - Test API with: `curl http://localhost:3000/health`

3. **Check database connection:**
   ```bash
   psql "$DATABASE_URL" -c "SELECT 1"
   ```

### High resource usage

1. **Check process memory:**
   ```bash
   # Linux
   ps aux --sort=-%mem | head -10
   ```

2. **Adjust systemd limits (Linux):**
   ```ini
   # In pollmasterbot.service
   MemoryLimit=2G
   CPUQuota=50%
   ```

---

## Auto-Restart Features

The bot now includes multiple levels of automatic restart:

1. **Service-level restart:** Windows Service or systemd handles process crashes
2. **Script-level restart:** `start.sh` includes exponential backoff
   - Max 10 restart attempts
   - Backoff delay starts at 5 seconds, increases with each restart
   - Resets after 30 seconds of stable operation

3. **MCP server resilience:** Configuration is loaded from `mcp-servers.json`
   - Persistent across restarts
   - No downtime required for updates

---

## Production Checklist

Before going live:

- [ ] PostgreSQL database set up and accessible
- [ ] Environment variables configured in `.env`
- [ ] MCP server credentials valid in `mcp-servers.json`
- [ ] Service installed and verified running
- [ ] Logs directory created with proper permissions
- [ ] Firewall rules allow API server port (3000)
- [ ] Telegram bot token is valid
- [ ] Admin IDs configured
- [ ] Database backups scheduled
- [ ] Monitoring/alerting set up

---

## Additional Resources

- **Telegram Bot API:** https://core.telegram.org/bots/api
- **NSSM:** https://nssm.cc/
- **Systemd:** https://www.freedesktop.org/software/systemd/man/systemd.service.html
- **PostgreSQL:** https://www.postgresql.org/docs/
- **MCP Protocol:** https://modelcontextprotocol.io/

---

## Support

For issues or questions:

1. Check logs first (Windows: `logs/` directory, Linux: `journalctl`)
2. Verify all environment variables are set
3. Ensure database connectivity
4. Check network and firewall settings
