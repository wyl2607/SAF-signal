#!/bin/bash
# JetScope 发布脚本 — 从 jetscope 去敏后同步到 GitHub，验证并 push
# 用法: ./scripts/publish-to-github.sh
#
# 分离原则:
# - 本地: 完整代码 + 内部规划 + 历史文档
# - GitHub: 可运行代码 + 复刻指南 + API 文档
# 详见: docs/GITHUB_PUBLISH_POLICY.md

set -e

SRC="/Users/yumei/projects/jetscope/"
DEST="/Users/yumei/projects/SAF-signal/"

echo "=== JetScope Publish to GitHub ==="
echo "Source: $SRC"
echo "Dest:   $DEST"
echo ""

# 1. Sync production code to SAF-signal (sanitized)
echo "[1/4] Syncing production code (sanitized)..."

rsync -avz --delete \
  --exclude='.git' \
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
  --exclude='.env' \
  --exclude='.env.local' \
  --exclude='.env.webhook' \
  --exclude='.env.api-keys' \
  --exclude='.jetscope-root' \
  --exclude='.safvsoil-root' \
  --exclude='scripts/auto-sync-cluster.sh' \
  --exclude='scripts/publish-to-github.sh' \
  --exclude='scripts/deploy/' \
  --exclude='scripts/verify/' \
  --exclude='docs/archive/' \
  --exclude='docs/notion-*' \
  --exclude='PROJECT_PROGRESS*.md' \
  --exclude='PROJECT_AUDIT*.md' \
  --exclude='DAY*_*' \
  --exclude='EXECUTE*' \
  --exclude='SAF_DEVELOPMENT_ANALYSIS_REPORT.md' \
  --exclude='CHANGELOG.md' \
  --exclude='ROADMAP.md' \
  --exclude='*.log' \
  --exclude='convert_batch.log' \
  --exclude='build-logs/' \
  --exclude='wave3-execution-logs/' \
  --exclude='logs/' \
  --exclude='webhook-logs/' \
  "$SRC" "$DEST"

echo "[1/4] ✅ Sync complete"
echo ""

# 2. Remove any internal docs that may have leaked
echo "[2/4] Removing internal docs from publish target..."
cd "$DEST"
rm -f CLUSTER_*.md LANE*.md WEBHOOK_*.md DELIVERY_*.md DELIVERABLES*.md \
  COMPLETE_*.md COMPLETION_*.md FINAL_*.md DEPLOY_*.md DEPLOYMENT_*.md \
  FAQ_*.md START_HERE_*.md SQLITE_*.md 00_*.md REALTIME_*.md \
  FILE_MANIFEST*.md PHASE*.md README_LANE*.md QUICK_*.md SAFVSOIL_*.md \
  .safvsoil-root .jetscope-root
rm -rf docs/archive/ docs/notion-*/
echo "[2/4] ✅ Internal docs cleaned"
echo ""

# 3. Verify build
echo "[3/4] Verifying build..."
cd "$DEST"
npm run web:gate
echo "[3/4] ✅ Build passes"
echo ""

# 4. Commit
echo "[4/4] Committing changes..."
cd "$DEST"
git add -A
if git diff --cached --quiet; then
  echo "[4/4] ⚠️  No changes to commit"
  exit 0
fi

git commit -m "sync: production update from jetscope ($(date +%Y-%m-%d %H:%M))"
echo "[4/4] ✅ Committed"
echo ""

# 5. Push to GitHub
echo "[5/5] Pushing to GitHub..."

# Temporarily disable global insteadOf to allow HTTPS push
GITCONFIG_BACKUP=""
if git config --global --get url.git@github.com:.insteadof >/dev/null 2>&1; then
  cp ~/.gitconfig ~/.gitconfig.bak
  GITCONFIG_BACKUP="1"
  sed -i '' '/insteadOf/d' ~/.gitconfig
fi

PUSH_OK="0"
if git -c credential.helper='!/opt/homebrew/bin/gh auth git-credential' push https://github.com/wyl2607/jetscope.git main; then
  PUSH_OK="1"
fi

# Restore gitconfig
if [[ -n "$GITCONFIG_BACKUP" ]]; then
  cp ~/.gitconfig.bak ~/.gitconfig
  rm ~/.gitconfig.bak
fi

if [[ "$PUSH_OK" == "1" ]]; then
  echo "[5/5] ✅ Pushed to https://github.com/wyl2607/jetscope"
else
  echo "[5/5] ❌ Push failed"
  echo "Hint: Run 'gh auth login' if token expired"
  exit 1
fi

echo ""
echo "=== Publish complete ==="
