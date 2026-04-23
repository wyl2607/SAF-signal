#!/bin/bash
# JetScope 发布脚本 — 安全去敏后推送到 GitHub
# 用法: ./scripts/publish-to-github.sh
#
# 安全边界: 本地开发 → SAF-signal (去敏目标) → GitHub
# 复用检查逻辑: security_check.sh + review_push_guard.sh

set -euo pipefail

SRC="/Users/yumei/projects/jetscope/"
DEST="/Users/yumei/projects/SAF-signal/"
FOUND_SENSITIVE=0

echo "=== JetScope Secure Publish to GitHub ==="
echo "Source: $SRC"
echo "Dest:   $DEST"
echo "Remote: wyl2607/jetscope"
echo ""

# ============================================================
# STEP 0: 安全审计 (复用 security_check.sh 逻辑)
# ============================================================
echo "[0/5] 🔒 Security Audit..."

# 0a. 扫描本地目录中的敏感文件（即使不在 git 索引中）
SENSITIVE_PATTERNS=(
  "\.env$"
  "\.env\.local$"
  "\.env\.production$"
  "\.env\.webhook$"
  "\.env\.api-keys$"
  ".*_key$"
  ".*_secret$"
  "credentials\.json"
  "secrets\.json"
  "api-keys"
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
  matches=$(find "$SRC" -maxdepth 3 -type f | grep -E "$pattern" | grep -v node_modules | grep -v .venv | grep -v .next | grep -v .git || true)
  if [ -n "$matches" ]; then
    echo "  ⚠️  Sensitive file found in source: $matches"
    # 不阻断，因为 .env.webhook.example 是允许的
  fi
done

# 0b. 扫描源代码中的硬编码 API key
echo "  Scanning for API keys in source..."
if grep -r -E "(api[_-]?key|secret[_-]?key|openai[_-]?key|anthropic[_-]?key)\s*=\s*['\"][a-zA-Z0-9_\-]{20,}" \
  "$SRC/apps" "$SRC/packages" "$SRC/infra" "$SRC/scripts" \
  --include="*.py" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.sh" --include="*.json" \
  2>/dev/null | grep -v "example" | grep -v "test" | head -5; then
  echo "  ❌ Found possible API key hardcoded in source!"
  FOUND_SENSITIVE=1
fi

# 0c. 扫描第三方/中转 API 端点
echo "  Scanning for relay/third-party API endpoints..."
if grep -r -E "(relay\.nf\.video|api\.longcat\.chat|ark\.cn-beijing\.volces\.com)" \
  "$SRC" --include="*.py" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.sh" --include="*.toml" --include="*.yaml" --include="*.yml" --include="*.json" \
  2>/dev/null | grep -v node_modules | grep -v .venv | head -3; then
  echo "  ❌ Found relay/third-party API endpoint!"
  FOUND_SENSITIVE=1
fi

# 0d. 扫描内网 IP 地址
echo "  Scanning for internal IPs..."
if grep -r -E "(192\.168\.[0-9]{1,3}\.[0-9]{1,3}|10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})" \
  "$SRC" --include="*.py" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.sh" --include="*.yaml" --include="*.yml" --include="*.json" --include="*.md" \
  2>/dev/null | grep -v node_modules | grep -v .venv | grep -v "test" | head -3; then
  echo "  ❌ Found internal IP address!"
  FOUND_SENSITIVE=1
fi

# 0e. 扫描绝对路径 (可能泄露用户名)
echo "  Scanning for absolute paths..."
if grep -r -E "/Users/[^/]+/" "$SRC" --include="*.py" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.sh" --include="*.yaml" --include="*.yml" --include="*.json" \
  2>/dev/null | grep -v node_modules | grep -v .venv | grep -v "/Users/yumei/" | head -3; then
  echo "  ❌ Found absolute path with other username!"
  FOUND_SENSITIVE=1
fi

# 0f. 检查 .guard/local-only-files.txt 中的文件是否存在于源目录
if [ -f "$SRC/.guard/local-only-files.txt" ]; then
  echo "  Checking local-only file list..."
  while IFS= read -r local_only; do
    [ -z "$local_only" ] && continue
    case "$local_only" in \#*) continue ;; esac
    if [ -e "$SRC/$local_only" ]; then
      echo "  ⚠️  Local-only file exists: $local_only"
    fi
  done < "$SRC/.guard/local-only-files.txt"
fi

if [ $FOUND_SENSITIVE -eq 1 ]; then
  echo ""
  echo "❌ SECURITY AUDIT FAILED!"
  echo "Fix the issues above before publishing."
  echo "If you're sure it's safe, run with SKIP_SECURITY=1 (not recommended)"
  exit 1
fi

echo "[0/5] ✅ Security audit passed"
echo ""

# ============================================================
# STEP 1: Sync to DEST (sanitized)
# ============================================================
echo "[1/5] Syncing production code (sanitized)..."

rsync -avz --delete \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='apps/web/.next' \
  --exclude='apps/web/dist' \
  --exclude='apps/api/.venv' \
  --exclude='.omx' \
  --exclude='.automation' \
  --exclude='.pytest_cache' \
  --exclude='.ruff_cache' \
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

echo "[1/5] ✅ Sync complete"
echo ""

# ============================================================
# STEP 2: Post-sync cleanup (二次去敏)
# ============================================================
echo "[2/5] Post-sync cleanup..."

cd "$DEST"

# 2a. 删除可能 rsync 遗漏的内部文档
rm -f CLUSTER_*.md LANE*.md WEBHOOK_*.md DELIVERY_*.md DELIVERABLES*.md \
  COMPLETE_*.md COMPLETION_*.md FINAL_*.md DEPLOY_*.md DEPLOYMENT_*.md \
  FAQ_*.md START_HERE_*.md SQLITE_*.md 00_*.md REALTIME_*.md \
  FILE_MANIFEST*.md PHASE*.md README_LANE*.md QUICK_*.md SAFVSOIL_*.md \
  .safvsoil-root .jetscope-root

# 2b. 删除内部目录
rm -rf docs/archive/ docs/notion-*/ .guard/

# 2c. 删除 .env 文件（即使被 rsync exclude 遗漏）
find "$DEST" -maxdepth 3 -name ".env*" -type f | grep -v ".env.example" | xargs -r rm -f

# 2d. 删除可能包含敏感信息的缓存
rm -rf .next/ .pytest_cache/ .ruff_cache/

echo "[2/5] ✅ Cleanup complete"
echo ""

# ============================================================
# STEP 3: Verify DEST has no sensitive files
# ============================================================
echo "[3/5] Verifying DEST has no sensitive files..."

# 3a. 检查 .env 文件
if find "$DEST" -maxdepth 3 -name ".env*" -type f | grep -v ".env.example" | grep -q .; then
  echo "❌ ERROR: .env files still present in DEST!"
  find "$DEST" -maxdepth 3 -name ".env*" -type f | grep -v ".env.example"
  exit 1
fi

# 3b. 检查内部文档模式
if find "$DEST" -maxdepth 2 -name "CLUSTER_*" -o -name "LANE*" -o -name "WEBHOOK_*" -o -name "DELIVERY_*" 2>/dev/null | grep -q .; then
  echo "❌ ERROR: Internal docs still present in DEST!"
  find "$DEST" -maxdepth 2 -name "CLUSTER_*" -o -name "LANE*" -o -name "WEBHOOK_*" | head -5
  exit 1
fi

# 3c. 检查 .omx / .automation
if [ -d "$DEST/.omx" ] || [ -d "$DEST/.automation" ]; then
  echo "❌ ERROR: Internal tool directories still present!"
  exit 1
fi

# 3d. 扫描 DEST 中的 API key
echo "  Scanning DEST for API keys..."
if grep -r -E "(api[_-]?key|secret[_-]?key)\s*=\s*['\"][a-zA-Z0-9_\-]{20,}" \
  "$DEST" --include="*.py" --include="*.ts" --include="*.js" --include="*.sh" --include="*.json" \
  2>/dev/null | grep -v node_modules | grep -v "example" | head -3; then
  echo "❌ ERROR: API key found in DEST!"
  exit 1
fi

echo "[3/5] ✅ DEST is clean"
echo ""

# ============================================================
# STEP 4: Verify build
# ============================================================
echo "[4/5] Verifying build..."
cd "$DEST"
npm run web:gate
echo "[4/5] ✅ Build passes"
echo ""

# ============================================================
# STEP 5: Commit and push
# ============================================================
echo "[5/5] Committing and pushing..."
cd "$DEST"

# 确保 remote 指向正确的仓库
git remote set-url origin https://github.com/wyl2607/jetscope.git 2>/dev/null || true

git add -A
if git diff --cached --quiet; then
  echo "[5/5] ℹ️ No changes to commit"
else
  git commit -m "publish: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  # Push with HTTPS override for insteadOf
  git -c url."https://github.com/".insteadOf="git@github.com:" push https://github.com/wyl2607/jetscope.git main
  echo "[5/5] ✅ Pushed to wyl2607/jetscope"
fi

echo ""
echo "=== Publish Complete ==="
