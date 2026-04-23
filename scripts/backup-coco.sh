#!/bin/bash
# coco 备份脚本 — 每日凌晨自动备份 jetscope 完整代码
# 用法: 手动执行或配置 cron: 0 3 * * * ~/jetscope/scripts/backup-coco.sh

set -e

SRC="$HOME/jetscope/"
BACKUP_DIR="$HOME/jetscope-backups"
DATE=$(date +%Y%m%d)
BACKUP_FILE="$BACKUP_DIR/jetscope-$DATE.tar.gz"

echo "=== coco Backup ==="
echo "Source: $SRC"
echo "Backup: $BACKUP_FILE"
echo ""

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_FILE" \
  --exclude='node_modules' \
  --exclude='apps/web/.next' \
  --exclude='apps/web/dist' \
  --exclude='apps/api/.venv' \
  --exclude='.omx' \
  --exclude='.automation' \
  --exclude='test-results' \
  --exclude='*.tar.gz' \
  --exclude='apps/web/tsconfig.tsbuildinfo' \
  --exclude='apps/web/next-env.d.ts' \
  -C "$HOME" jetscope/

echo "✅ Backup complete: $BACKUP_FILE"

# Keep only last 7 backups
echo "Cleaning old backups (keep 7 days)..."
cd "$BACKUP_DIR"
ls -t jetscope-*.tar.gz | tail -n +8 | xargs -r rm -f
echo "✅ Cleanup complete"

echo ""
echo "Current backups:"
ls -lh "$BACKUP_DIR"
