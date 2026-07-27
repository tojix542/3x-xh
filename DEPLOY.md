# 3x Forensics — Deployment Guide

Complete guide to hosting the 3x scanner on free platforms.

---

## Option 1: Render (RECOMMENDED — Free Tier Available)

**Best for:** Getting online for $0. Free tier spins down after 15min idle but works perfectly for a scanner dashboard.

### Step 1: Push to GitHub

```bash
git init
git add .
git commit -m "3x scanner v3.0"
# Create a new repo on GitHub, then:
git remote add origin https://github.com/YOURNAME/3x-scanner.git
git push -u origin main
```

### Step 2: Deploy on Render

1. Go to [render.com](https://render.com) and sign up (free, no credit card)
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repo
4. Configure:
   - **Name:** `3x-scanner`
   - **Runtime:** Node
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Plan:** Free
5. Click **"Create Web Service"**

### Step 3: Add Environment Variables

In Render dashboard → your service → **Environment** tab, add:

```
PORT=3000
NODE_ENV=production
DISCORD_CLIENT_ID=1519776355951055110
DISCORD_CLIENT_SECRET=HSyyjFoupwoK1mcCXp702HqDlonnq9r-
DISCORD_BOT_TOKEN=MTUxOTc3NjM1NTk1MTA1NTExMA.GMsurk.UctFDQse8x4BOK0BU0ZyISeFVWI9AiiGNrBhI8
WEBHOOK_URL=https://discordapp.com/api/webhooks/1531415558375870514/iKvz0QZQFHtZP7k1vusnZTA5URnF1WPYmdkQYDGiBQ7rOKzQLgobsQRxvEVz1a2Eljfj
OWNER_ID=827236167686291477
GUILD_ID=1527100025765625856
CUSTOMER_ROLE_ID=1531416721808949378
REDIRECT_URI=https://YOUR-RENDER-URL.onrender.com/api/auth/callback
```

> Replace `YOUR-RENDER-URL` with your actual Render URL (e.g., `3x-scanner.onrender.com`)

### Step 4: Update Discord OAuth Redirect

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Select your app → **OAuth2** → **Redirects**
3. Add: `https://YOUR-RENDER-URL.onrender.com/api/auth/callback`
4. Save

### Step 5: Update REDIRECT_URI in server.js

Edit `server.js` line 17:
```javascript
const REDIRECT_URI = 'https://YOUR-RENDER-URL.onrender.com/api/auth/callback';
```

Push the change:
```bash
git add server.js
git commit -m "update redirect uri"
git push
```

Render auto-deploys on push.

### Render Free Tier Notes
- Services spin down after 15 minutes of inactivity
- First request after idle takes ~30-60 seconds (cold start)
- 750 instance-hours/month free
- Perfect for a scanner dashboard that gets periodic use

---

## Option 2: Railway (Fastest Deploy)

**Best for:** Quick deploy, better cold-start performance than Render free tier. $5 trial credit, then $5/mo Hobby plan.

### Step 1: Install Railway CLI

```bash
npm install -g @railway/cli
railway login
```

### Step 2: Deploy

```bash
cd 3x-scanner-site
railway init
# Select "Deploy from directory"
railway up
```

### Step 3: Set Environment Variables

```bash
railway variables set PORT=3000
railway variables set NODE_ENV=production
railway variables set DISCORD_CLIENT_ID=1519776355951055110
railway variables set DISCORD_CLIENT_SECRET=HSyyjFoupwoK1mcCXp702HqDlonnq9r-
railway variables set DISCORD_BOT_TOKEN=MTUxOTc3NjM1NTk1MTA1NTExMA.GMsurk.UctFDQse8x4BOK0BU0ZyISeFVWI9AiiGNrBhI8
railway variables set WEBHOOK_URL=https://discordapp.com/api/webhooks/1531415558375870514/iKvz0QZQFHtZP7k1vusnZTA5URnF1WPYmdkQYDGiBQ7rOKzQLgobsQRxvEVz1a2Eljfj
railway variables set OWNER_ID=827236167686291477
railway variables set GUILD_ID=1527100025765625856
railway variables set CUSTOMER_ROLE_ID=1531416721808949378
railway variables set REDIRECT_URI=https://YOUR-RAILWAY-URL.up.railway.app/api/auth/callback
```

> Get your Railway URL from the dashboard after first deploy.

### Step 4: Update Discord OAuth + server.js

Same as Render steps 4-5.

---

## Option 3: Fly.io (Most Control)

**Best for:** Global edge deployment, Docker control. $5 trial credit.

### Step 1: Install Fly CLI

```bash
curl -L https://fly.io/install.sh | sh
fly auth login
```

### Step 2: Create fly.toml

```toml
app = "3x-scanner"
primary_region = "iad"

[build]
  builder = "heroku/buildpacks:20"

[env]
  PORT = "3000"
  NODE_ENV = "production"

[http_service]
  internal_port = 3000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0
  processes = ["app"]

[[vm]]
  memory = "512mb"
  cpu_kind = "shared"
  cpus = 1
```

### Step 3: Set Secrets

```bash
fly secrets set DISCORD_CLIENT_ID=1519776355951055110
fly secrets set DISCORD_CLIENT_SECRET=HSyyjFoupwoK1mcCXp702HqDlonnq9r-
fly secrets set DISCORD_BOT_TOKEN=MTUxOTc3NjM1NTk1MTA1NTExMA.GMsurk.UctFDQse8x4BOK0BU0ZyISeFVWI9AiiGNrBhI8
fly secrets set WEBHOOK_URL=https://discordapp.com/api/webhooks/1531415558375870514/iKvz0QZQFHtZP7k1vusnZTA5URnF1WPYmdkQYDGiBQ7rOKzQLgobsQRxvEVz1a2Eljfj
fly secrets set OWNER_ID=827236167686291477
fly secrets set GUILD_ID=1527100025765625856
fly secrets set CUSTOMER_ROLE_ID=1531416721808949378
fly secrets set REDIRECT_URI=https://3x-scanner.fly.dev/api/auth/callback
```

### Step 4: Deploy

```bash
fly deploy
```

---

## Static Frontend Hosting (Cloudflare Pages — FREE)

If you want to host just the HTML frontend separately (faster, always-on):

### Step 1: Build Static Export

The HTML files in `/public` are already static. Just upload them.

### Step 2: Deploy to Cloudflare Pages

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → **Pages**
2. Click **"Create a project"**
3. Connect your GitHub repo
4. Build settings:
   - **Framework preset:** None
   - **Build command:** (leave empty)
   - **Build output directory:** `public`
5. Deploy

### Step 3: Update API URLs

In each HTML file, update the API base URL to point to your backend:

```javascript
const API_BASE = 'https://your-backend.onrender.com';
```

> Or use relative paths if backend and frontend share the same domain.

---

## Post-Deployment Checklist

- [ ] Backend deployed and responding at root URL
- [ ] Discord OAuth redirect URI updated in Discord Developer Portal
- [ ] `REDIRECT_URI` in server.js matches deployed URL
- [ ] Bot token has `guilds.members.read` intent enabled
- [ ] Customer role exists in the server with ID `1531416721808949378`
- [ ] Bot is invited to server with proper permissions
- [ ] Webhook URL is valid and receiving test messages
- [ ] Agent script `-ApiUrl` parameter points to deployed backend
- [ ] Owner can access `/owner-panel.html` after login

---

## Testing the Deployment

### 1. Test Auth Flow
```
Visit: https://your-url.com/
Click "Continue with Discord"
Should redirect to dashboard after auth
```

### 2. Test Owner Panel
```
Login with owner Discord account (ID: 827236167686291477)
Visit: https://your-url.com/owner-panel.html
Should show scan logs table
```

### 3. Test Agent
```powershell
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File .x-agent.ps1 -ApiUrl "https://your-url.com" -Token "YOUR_JWT_TOKEN"
```

### 4. Test Ban System
```
Try scanning twice within 24h → should auto-ban
Try self-scan (same Discord ID as logged-in user) → should auto-ban
Check webhook for ban notifications
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Unauthorized" on API calls | JWT token expired — re-login via Discord |
| "not_in_guild" error | User not in controller server — invite them |
| "no_customer_role" error | Role ID mismatch — verify `CUSTOMER_ROLE_ID` |
| Webhook not firing | Check webhook URL is valid, not rate-limited |
| Agent won't submit | Verify `-ApiUrl` matches deployed URL exactly |
| Owner panel 403 | Must login with owner Discord account |
| Cold starts on Render | Normal for free tier — first request takes 30-60s |

---

## Production Notes

### Database (Replace In-Memory)
The current `server.js` uses in-memory storage. For production, add SQLite/PostgreSQL:

```bash
npm install sqlite3
```

Replace `db` object with SQLite queries. The schema is simple:
- `users` table: discord_id, username, avatar, role, banned, ban_reason
- `scans` table: id, discord_id, username, risk_score, findings, discord_token, hwid, target_discord_id, mode, violation, banned, created_at
- `cooldowns` table: discord_id, scan_times (JSON array)

### HTTPS
All three platforms (Render, Railway, Fly.io) provide free SSL certificates automatically.

### Rate Limiting
Add `express-rate-limit` for additional API protection:
```bash
npm install express-rate-limit
```

### Session Store
Replace memory sessions with Redis or database-backed sessions for multi-instance deployments.
