# Cloudflare Origin CA 证书配置指南

## 当前状态

- **域名**: `saf.meichen.beauty`
- **服务器**: `192.227.130.69` (us-vps)
- **代理状态**: ✅ Cloudflare 已代理（橙色云）
- **HTTP 访问**: ✅ 已可用 http://saf.meichen.beauty

## 为什么需要 Origin CA 证书

由于 Cloudflare 代理已开启，外部流量先到达 Cloudflare，再由 Cloudflare 转发到我们的服务器。为了加密 Cloudflare → 服务器这一段连接，需要在服务器上配置 SSL 证书。

Cloudflare Origin CA 证书是**免费**的，**15 年有效期**，专为这种场景设计。

---

## 配置步骤

### 第 1 步：在 Cloudflare Dashboard 生成证书

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com)
2. 选择域名 `meichen.beauty`
3. 进入 **SSL/TLS** → **Origin Server**
4. 点击 **Create Certificate**
5. 选择：
   - **Let Cloudflare generate a private key and a CSR**: ✅ 勾选
   - **Private key type**: RSA (2048)
   - **Hostnames**: 
     - `saf.meichen.beauty`
     - `*.saf.meichen.beauty` (可选)
6. 点击 **Create**
7. 复制显示的 **Origin Certificate** 和 **Private Key**

### 第 2 步：将证书上传到服务器

把证书内容保存为两个文件，发送给我，我会帮你配置到服务器：

1. `saf.meichen.beauty.pem` — Origin Certificate（以 `-----BEGIN CERTIFICATE-----` 开头）
2. `saf.meichen.beauty.key` — Private Key（以 `-----BEGIN PRIVATE KEY-----` 开头）

**安全提示**: 私钥非常敏感，不要发送到公共频道。可以通过安全的私聊发送。

### 第 3 步：配置 Cloudflare SSL 模式

在 Cloudflare Dashboard：
1. 进入 **SSL/TLS** → **Overview**
2. 将 SSL/TLS encryption mode 设为 **Full (strict)**

### 第 4 步：我帮你配置服务器

收到证书后，我会：
1. 上传证书到 `/etc/nginx/ssl/`
2. 更新 Nginx 配置启用 HTTPS
3. 重载 Nginx
4. 测试 `https://saf.meichen.beauty`

---

## 临时方案（立即启用 HTTPS）

如果你希望立即使用 HTTPS 而不用等待 Origin CA，可以：

1. 在 Cloudflare Dashboard → **SSL/TLS** → **Overview**
2. 选择 **Flexible** 模式
3. 这样浏览器 → Cloudflare 是 HTTPS，Cloudflare → 服务器是 HTTP

⚠️ **注意**: Flexible 模式不如 Full (strict) 安全，建议尽快切换到 Origin CA。

---

## 验证

配置完成后，访问：
- https://saf.meichen.beauty
- https://saf.meichen.beauty/v1/health

应该显示绿色锁图标（证书有效）。
