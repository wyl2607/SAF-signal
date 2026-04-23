#!/bin/bash
# JetScope Auto-Deploy Script
# Runs on production server (usa-vps) via cron every minute
# Pulls latest code from GitHub, builds, and restarts services

set -euo pipefail

DEPLOY_DIR="/opt/jetscope"
LOG="/var/log/jetscope-deploy.log"
BUILD_LOG="/var/log/jetscope-build.log"
LOCK_FILE="/tmp/jetscope-deploy.lock"

cd "$DEPLOY_DIR"

# Prevent concurrent deployments
if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "[$(date -Iseconds)] Deploy already running (PID $LOCK_PID). Skipping." >> "$LOG"
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Check if GitHub has new commits
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git ls-remote origin main | awk '{print $1}')

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    # No changes, exit silently (unless it's the 10-minute mark for a heartbeat)
    MINUTE=$(date +%M)
    if [ "${MINUTE:1:1}" = "0" ]; then
        echo "[$(date -Iseconds)] No changes. Local: ${LOCAL_COMMIT:0:8} = Remote: ${REMOTE_COMMIT:0:8}" >> "$LOG"
    fi
    exit 0
fi

echo "[$(date -Iseconds)] New commits detected! Local: ${LOCAL_COMMIT:0:8} → Remote: ${REMOTE_COMMIT:0:8}" | tee -a "$LOG"

# Stash local state (.env, data, etc.)
git stash push -m "auto-deploy-stash-$(date +%Y%m%d_%H%M%S)" --include-untracked >> "$LOG" 2>&1 || true

# Pull latest
echo "[$(date -Iseconds)] Pulling origin/main..." | tee -a "$LOG"
git pull origin main >> "$LOG" 2>&1

# Restore local state
git stash pop >> "$LOG" 2>&1 || true

# Build API (Docker)
echo "[$(date -Iseconds)] Building API..." | tee -a "$LOG"
docker-compose -f docker-compose.prod.yml up --build -d api >> "$LOG" 2>&1

# Wait for API to be ready
sleep 5
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/v1/health --connect-timeout 5 --max-time 10 2>/dev/null || echo "000")
if [ "$API_STATUS" != "200" ]; then
    echo "[$(date -Iseconds)] WARNING: API not healthy after build (status: $API_STATUS)" | tee -a "$LOG"
fi

# Build Web
echo "[$(date -Iseconds)] Building Web..." | tee -a "$LOG"
cd apps/web
rm -rf .next
nohup "$DEPLOY_DIR/node_modules/.bin/next" build --webpack > "$BUILD_LOG" 2>&1 &
BUILD_PID=$!

# Wait for build (max 10 minutes)
BUILD_TIMEOUT=600
BUILD_ELAPSED=0
while kill -0 "$BUILD_PID" 2>/dev/null; do
    sleep 10
    BUILD_ELAPSED=$((BUILD_ELAPSED + 10))
    if [ "$BUILD_ELAPSED" -ge "$BUILD_TIMEOUT" ]; then
        echo "[$(date -Iseconds)] ERROR: Web build timeout (${BUILD_TIMEOUT}s). Killing..." | tee -a "$LOG"
        kill -9 "$BUILD_PID" 2>/dev/null || true
        exit 1
    fi
done

# Check if build succeeded
if [ ! -f ".next/BUILD_ID" ]; then
    echo "[$(date -Iseconds)] ERROR: Web build failed. See $BUILD_LOG" | tee -a "$LOG"
    exit 1
fi

echo "[$(date -Iseconds)] Web build OK. Restarting service..." | tee -a "$LOG"
systemctl restart jetscope-web.service
sleep 3

# Verify
WEB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://saf.meichen.beauty/v1/health --connect-timeout 5 --max-time 10 2>/dev/null || echo "000")
if [ "$WEB_STATUS" = "200" ] || [ "$WEB_STATUS" = "307" ]; then
    echo "[$(date -Iseconds)] Deploy SUCCESS! Web: $WEB_STATUS, API: $API_STATUS" | tee -a "$LOG"
else
    echo "[$(date -Iseconds)] WARNING: Deploy completed but web health check failed (status: $WEB_STATUS)" | tee -a "$LOG"
fi

echo "[$(date -Iseconds)] Deploy complete." | tee -a "$LOG"
