#!/bin/bash
# JetScope Rollback Script
# Reverts to the previous git commit and rebuilds

set -euo pipefail

DEPLOY_DIR="/opt/jetscope"
LOG="/var/log/jetscope-deploy.log"
BUILD_LOG="/var/log/jetscope-build.log"

cd "$DEPLOY_DIR"

echo "[$(date -Iseconds)] ROLLBACK initiated..." | tee -a "$LOG"

# Show current and previous commit
echo "Current commit: $(git log --oneline -1)" | tee -a "$LOG"
echo "Rolling back to: $(git log --oneline -2 | tail -1)" | tee -a "$LOG"

# Stash local state
git stash push -m "rollback-stash-$(date +%Y%m%d_%H%M%S)" --include-untracked >> "$LOG" 2>&1 || true

# Roll back one commit
git reset --hard HEAD~1 >> "$LOG" 2>&1

# Restore local state
git stash pop >> "$LOG" 2>&1 || true

# Rebuild API
echo "[$(date -Iseconds)] Rebuilding API..." | tee -a "$LOG"
docker-compose -f docker-compose.prod.yml down >> "$LOG" 2>&1 || true
docker rm -f jetscope-api >> "$LOG" 2>&1 || true
docker-compose -f docker-compose.prod.yml up --build -d api >> "$LOG" 2>&1
sleep 5

# Rebuild Web
echo "[$(date -Iseconds)] Rebuilding Web..." | tee -a "$LOG"
cd apps/web
rm -rf .next
nohup "$DEPLOY_DIR/node_modules/.bin/next" build --webpack > "$BUILD_LOG" 2>&1 &
BUILD_PID=$!

# Wait for build
while kill -0 "$BUILD_PID" 2>/dev/null; do
    sleep 10
done

if [ ! -f ".next/BUILD_ID" ]; then
    echo "[$(date -Iseconds)] ERROR: Rollback build failed!" | tee -a "$LOG"
    exit 1
fi

systemctl restart jetscope-web.service
sleep 3

# Verify
WEB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://saf.meichen.beauty --connect-timeout 5 --max-time 10 2>/dev/null || echo "000")
echo "[$(date -Iseconds)] Rollback complete. Web status: $WEB_STATUS" | tee -a "$LOG"
