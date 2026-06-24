#!/usr/bin/env bash
# Start the Telegram bot in the background, then run the API server in the foreground.
# The API server keeps the process alive and handles health checks.
python bot.py &
exec node --enable-source-maps artifacts/api-server/dist/index.mjs
#!/usr/bin/env bash
set -e

# ============================================================================
# Poll Master Bot - 24/7 Production Launcher
# ============================================================================
# This script runs the bot and API server with:
# - Automatic restarts on failure
# - Proper logging
# - MCP server support
# - Health checks
# ============================================================================

# Configuration
MAX_RESTARTS=10
RESTART_DELAY=5
LOG_DIR="${LOG_DIR:-.}"
LOG_FILE="${LOG_DIR}/pollmasterbot.log"
ERROR_LOG="${LOG_DIR}/pollmasterbot.error.log"
PID_FILE="${LOG_DIR}/pollmasterbot.pid"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
	echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $@" | tee -a "$LOG_FILE"
}

log_error() {
	echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $@" | tee -a "$ERROR_LOG"
}

log_success() {
	echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $@" | tee -a "$LOG_FILE"
}

log_warn() {
	echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $@" | tee -a "$LOG_FILE"
}

# Cleanup on exit
cleanup() {
	log "Shutting down gracefully..."
	if [ -f "$PID_FILE" ]; then
		kill $(cat "$PID_FILE") 2>/dev/null || true
		rm -f "$PID_FILE"
	fi
	# Kill any remaining python processes (bot)
	pkill -f "python.*bot.py" || true
	exit 0
}

trap cleanup SIGTERM SIGINT

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

log "========================================"
log "Starting Poll Master Bot (24/7 Mode)"
log "========================================"

# Check prerequisites
if ! command -v python &> /dev/null && ! command -v python3 &> /dev/null; then
	log_error "Python is not installed or not in PATH"
	exit 1
fi

if ! command -v node &> /dev/null; then
	log_error "Node.js is not installed or not in PATH"
	exit 1
fi

log "✓ Python available: $(python --version 2>/dev/null || python3 --version)"
log "✓ Node.js available: $(node --version)"

# Check for required environment variables
if [ -z "$TELEGRAM_BOT_TOKEN" ] && [ -z "$BOT_TOKEN" ]; then
	log_error "TELEGRAM_BOT_TOKEN or BOT_TOKEN environment variable not set"
	exit 1
fi

if [ -z "$POLLING_CHANNEL_ID" ]; then
	log_error "POLLING_CHANNEL_ID environment variable not set"
	exit 1
fi

log "✓ Environment variables configured"

# Load mcp-servers.json if present (for MCP server configuration)
if [ -f "mcp-servers.json" ]; then
	log "✓ MCP servers configuration loaded from mcp-servers.json"
else
	log_warn "mcp-servers.json not found - MCP servers may not be configured"
fi

# Main service loop with auto-restart
RESTART_COUNT=0
LAST_RESTART=$(date +%s)

while true; do
	RESTART_COUNT=$((RESTART_COUNT + 1))
    
	if [ $RESTART_COUNT -gt $MAX_RESTARTS ]; then
		log_error "Maximum restart attempts ($MAX_RESTARTS) reached. Stopping service."
		exit 1
	fi
    
	log "Starting services... (Attempt $RESTART_COUNT/$MAX_RESTARTS)"
    
	# Start Python bot in background with output logging
	log "→ Starting Telegram Bot..."
	python bot.py >> "$LOG_FILE" 2>> "$ERROR_LOG" &
	BOT_PID=$!
	echo $BOT_PID > "$PID_FILE"
	log "  Bot PID: $BOT_PID"
    
	# Give bot a moment to initialize
	sleep 2
    
	# Check if bot is still running
	if ! kill -0 $BOT_PID 2>/dev/null; then
		log_error "Bot process terminated immediately"
		sleep $RESTART_DELAY
		continue
	fi
    
	log "→ Starting API Server..."

	# Build API server if the dist bundle is missing.
	if [ ! -f "artifacts/api-server/dist/index.mjs" ]; then
		log_warn "API server bundle not found. Building artifacts/api-server..."
		if ! command -v pnpm &> /dev/null; then
			log_error "pnpm is required to build the API server but is not installed"
			exit 1
		fi
		if ! pnpm --filter @workspace/api-server run build >> "$LOG_FILE" 2>> "$ERROR_LOG"; then
			log_error "Failed to build api-server bundle"
			exit 1
		fi
		log_success "API server built successfully"
	fi

	# Run API server in foreground (blocking)
	if node --enable-source-maps artifacts/api-server/dist/index.mjs >> "$LOG_FILE" 2>> "$ERROR_LOG"; then
		log_success "API Server exited normally"
	else
		API_EXIT_CODE=$?
		log_error "API Server exited with code $API_EXIT_CODE"
	fi
    
	# Kill bot if still running
	kill $BOT_PID 2>/dev/null || true
	wait $BOT_PID 2>/dev/null || true
    
	# Calculate restart delay (exponential backoff if failing repeatedly)
	CURRENT_TIME=$(date +%s)
	TIME_SINCE_RESTART=$((CURRENT_TIME - LAST_RESTART))
    
	if [ $TIME_SINCE_RESTART -lt 30 ]; then
		# Services crashed quickly - use exponential backoff
		DELAY=$((RESTART_DELAY * RESTART_COUNT))
		if [ $DELAY -gt 300 ]; then
			DELAY=300  # Cap at 5 minutes
		fi
		log_warn "Services crashed quickly. Waiting ${DELAY}s before restart..."
	else
		# Services ran for a reasonable time - reset counter and use base delay
		log_warn "Services stopped. Restarting in ${RESTART_DELAY}s..."
		RESTART_COUNT=0
		DELAY=$RESTART_DELAY
	fi
    
	LAST_RESTART=$CURRENT_TIME
	sleep $DELAY
done
