# JetScope 开发 SOP — GitOps 工作流

> **版本**: v1.0  
> **生效日期**: 2026-04-23  
> **适用范围**: 本机 + coco + mac-mini + usa-vps

---

## 核心原则

| # | 原则 | 说明 |
|---|------|------|
| 1 | **Git 是唯一真值来源** | 所有代码、配置、脚本必须在 Git 中。服务器不手动编辑文件。 |
| 2 | **本地 → GitHub → 服务器** | 单向流动。禁止在服务器上直接修改代码。 |
| 3 | **自动部署** | 服务器通过 cron 每分钟检测 git 变更，自动 pull/build/restart。 |
| 4 | **敏感信息隔离** | `.env` 文件永不进 Git，通过 `.env.example` 模板管理。 |
| 5 | **回滚能力** | 每次部署保留上一个版本，30 秒内可回滚。 |

---

## 文件归属规范

### 必须在 Git 中（代码/配置）

```
apps/api/          # Python API 源码
apps/web/          # Next.js 前端源码
infra/server/      # 服务器配置模板（nginx、systemd、docker-compose）
scripts/deploy.sh  # 自动部署脚本
.env.example       # 环境变量模板（含说明，不含真实值）
docs/              # 文档
```

### 永不进 Git（敏感/环境相关）

```
.env               # 真实环境变量（密码、token）
.env.webhook       # webhook 专用配置
data/market.db     # SQLite 数据库（运行时生成）
.next/             # Next.js 构建产物
dist/              # 静态导出产物
node_modules/      # npm 依赖
.omx/              # AI 会话日志
```

### 服务器本地文件（由模板生成）

```
/opt/jetscope/.env                    # 从 .env.example 复制后填入真实值
/etc/nginx/sites-available/jetscope   # 从 infra/server/nginx.conf 复制
/etc/systemd/system/jetscope-web.service  # 从 infra/server/jetscope-web.service 复制
/opt/jetscope/docker-compose.prod.yml    # 从 infra/server/docker-compose.prod.yml 复制
```

---

## 开发工作流

### 本地开发 → GitHub

```bash
# 1. 在本地开发（~/projects/jetscope）
# 修改代码...

# 2. 本地验证
npm run web:gate      # 前端 build + typecheck + lint
npm run api:check     # Python 编译检查

# 3. 提交到本地 Git
git add .
git commit -m "feat(scope): description"

# 4. Push 到 GitHub
git push origin main
# → 触发服务器自动部署（cron 每分钟检测）
```

### 服务器自动部署流程

```
GitHub main 分支更新
    ↓
服务器 cron (每分钟): git fetch origin main
    ↓
如果有新 commit:
    1. git stash 保存本地状态（如 .env）
    2. git pull origin main
    3. git stash pop 恢复本地状态
    4. docker-compose up --build -d api
    5. cd apps/web && npm run build
    6. systemctl restart jetscope-web.service
    7. nginx -t && systemctl reload nginx
    8. 记录部署日志
```

---

## 服务器首次部署（一次性）

```bash
# 1. 克隆仓库
sudo mkdir -p /opt/jetscope
sudo chown $USER:$USER /opt/jetscope
cd /opt/jetscope
git clone https://github.com/wyl2607/jetscope.git .

# 2. 复制配置模板
sudo cp infra/server/nginx.conf /etc/nginx/sites-available/jetscope
sudo ln -sf /etc/nginx/sites-available/jetscope /etc/nginx/sites-enabled/
sudo cp infra/server/jetscope-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable jetscope-web.service

# 3. 创建 .env（从模板复制，填入真实值）
cp .env.example .env
# 编辑 .env，填入 POSTGRES_PASSWORD 和 JETSCOPE_ADMIN_TOKEN

# 4. 启动服务
docker-compose -f docker-compose.prod.yml up --build -d api
systemctl start jetscope-web.service
nginx -t && sudo systemctl reload nginx

# 5. 启用自动部署 cron
crontab -l | grep -v "jetscope-auto-deploy" ; echo "* * * * * bash /opt/jetscope/scripts/auto-deploy.sh >> /var/log/jetscope-deploy.log 2>&1" | crontab -
```

---

## 紧急回滚

```bash
# 在服务器上
bash /opt/jetscope/scripts/rollback.sh

# 或在本地
ssh root@192.227.130.69 "bash /opt/jetscope/scripts/rollback.sh"
```

回滚脚本会：
1. `git reset --hard HEAD~1`
2. 重新 build + restart
3. 恢复上一个稳定版本

---

## 多设备同步规则

| 设备 | 角色 | 同步方向 |
|------|------|---------|
| **本机** (~/projects/jetscope) | 主开发 + GitHub push | 唯一写入 GitHub 的入口 |
| **usa-vps** (/opt/jetscope) | 生产服务器 | 只从 GitHub pull，永不 push |
| **coco** (~/jetscope) | 文档/备份 | 从 GitHub pull，独立开发文档 |
| **mac-mini** (~/jetscope) | 后端测试 | 从 GitHub pull，测试后反馈到本机 |
| **windows-pc** | Windows 兼容 | 从本机 sync-to-nodes |

**禁止操作**:
- ❌ 在 usa-vps 上直接修改代码
- ❌ 在 usa-vps 上 git commit / git push
- ❌ 将 .env 提交到 Git
- ❌ 将 PROJECT_PROGRESS*.md 提交到 Git

---

## 故障排查

### 服务器没有自动部署

```bash
# 检查 cron 是否运行
crontab -l | grep jetscope

# 检查部署日志
tail -50 /var/log/jetscope-deploy.log

# 手动触发一次部署
bash /opt/jetscope/scripts/auto-deploy.sh
```

### 本地 push 后服务器没有更新

```bash
# 1. 检查 GitHub 是否收到 push
git log --oneline origin/main -3

# 2. 检查服务器是否能访问 GitHub
ssh root@192.227.130.69 "curl -s https://api.github.com/repos/wyl2607/jetscope/commits/main | head -5"

# 3. 手动在服务器上 pull
ssh root@192.227.130.69 "cd /opt/jetscope && git pull origin main"
```

### 构建失败

```bash
# 检查构建日志
ssh root@192.227.130.69 "tail -50 /var/log/jetscope-build.log"

# 常见原因：
# - next.config.mjs 有 distDir: 'dist'（已修复）
# - node_modules 损坏（删除重装）
# - .env 缺失（从 .env.example 复制）
```

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-04-23 | v1.0 | 初始 SOP，建立 GitOps 工作流 |
