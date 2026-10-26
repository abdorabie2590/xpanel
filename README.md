# XPanel

A self-hosted web panel to run and manage [Xray-core](https://github.com/XTLS/Xray-core) proxy servers, in the spirit of 3x-ui. One static Go binary, no database server, no external dependencies at build time.

## Features

- **Protocols**: VLESS, VMess, Trojan, Shadowsocks (incl. 2022), SOCKS, HTTP, Dokodemo-door
- **Transports**: TCP, WebSocket, gRPC, HTTPUpgrade, XHTTP, mKCP · **Security**: TLS, REALITY (key pair generator included)
- **Clients**: per-client traffic limit, expiry (fixed date or "N days after first use"), IP limit, automatic periodic traffic reset, comment, Telegram id
- **Enforcement**: depleted/expired/over-IP-limit clients are removed from the running Xray immediately (no restart)
- **Share**: links + QR codes per client, and **subscription URLs** (base64, with `Subscription-Userinfo` for usage display in clients)
- **Dashboard**: CPU, RAM, disk, swap, network speed/total, connections, uptime, online clients
- **Xray management**: install/switch versions (SHA-256 verified), geo data update, template editor validated by Xray, live logs
- **Security**: PBKDF2 password hashing, signed HttpOnly SameSite=Strict sessions, login throttling, TOTP two-factor, random port + base path on first run, optional TLS, CSRF header check, strict CSP
- **Telegram bot**: expiry/traffic warnings, daily report, daily backup, `/status /online /usage /backup /restart …`
- **Backup / restore** of the whole database from the UI
- Light and dark theme, responsive

## Install (Linux, systemd)

```bash
tar xzf xpanel-1.0.0.tar.gz && cd xpanel
sudo ./install.sh
journalctl -u xpanel -n 20 --no-pager   # shows the generated username, password, port and path
```

Open `http://SERVER_IP:PORT/PATH/`, sign in, go to **Xray** → *Fetch versions* → *Install / switch*. The panel needs outbound access to `github.com` for that (or put an `xray` binary plus `geoip.dat`/`geosite.dat` into `/etc/xpanel/bin/`).

Then change the credentials (**Settings → Security**), enable two-factor, and configure a TLS certificate (**Settings → Panel**) or place the panel behind a TLS reverse proxy.

Upgrade: run `sudo ./install.sh` again from the new release; data in `/etc/xpanel` is kept.
Uninstall: `sudo ./install.sh uninstall`.

## Command line

```
XPANEL_DATA=/etc/xpanel xpanel setting -show
XPANEL_DATA=/etc/xpanel xpanel setting -username admin -password 'new-strong-pass'
XPANEL_DATA=/etc/xpanel xpanel setting -port 2053 -path /secret/
XPANEL_DATA=/etc/xpanel xpanel setting -resetTwoFactor
```

Changes made with `setting` are picked up by the running panel within a few seconds.

## Build from source

```bash
go build -o xpanel .        # needs Go 1.24+, no third-party modules
./build.sh                  # linux amd64 + arm64 release bundle in dist/
go test ./...
```

Run locally: `XPANEL_DATA=./data ./xpanel` (credentials are printed on first start).

## Layout

| File | Purpose |
|------|---------|
| `main.go` | entry point, `setting` CLI, lifecycle |
| `store.go` | JSON database, validation, backup import |
| `api.go` | HTTP API, auth middleware, settings, subscription endpoint |
| `xray.go` | config generation, process supervision, stats API, installer |
| `traffic.go` | traffic accounting, limits, online users, notifications |
| `links.go` | share links and subscriptions |
| `tgbot.go` | Telegram bot |
| `auth.go` | password hashing, sessions, TOTP, key generation |
| `web/` | embedded single-page UI (vanilla JS, no build step) |

## Notes and limits

- Data is stored in one JSON file (`xpanel.db.json`), written atomically. This is fine for thousands of clients; it is not meant for huge multi-tenant installs.
- Traffic is read from Xray every 10 s, so limits are enforced with up to ~10 s delay.
- IP limits rely on Xray's access log and are approximate.
- Automatic Xray download supports Linux only. The panel itself builds for other OSes, but system metrics are Linux-only.
- Use the panel only for traffic and users you are entitled to serve, and follow the laws that apply to you.
