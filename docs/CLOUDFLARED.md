# Cloudflared tunnel — quick setup

1) Install (macOS):

```bash
brew install cloudflared
```

2) Ephemeral tunnel (quick, prints a public URL):

```bash
cloudflared tunnel --url http://localhost:3000
```

You can also use the helper script added to the repo:

```bash
chmod +x scripts/start_cloudflared.sh
./scripts/start_cloudflared.sh
```

3) Persistent tunnel (optional)

- Create a named tunnel and get credentials:

```bash
cloudflared tunnel create my-tunnel
```

- Configure ingress (example in `.cloudflared/config.yml.example`) and run:

```bash
cloudflared tunnel run my-tunnel
```

Path-based routing example (route backend at /api/*):

1. Edit `.cloudflared/config.yml` (example in `.cloudflared/config.yml.example`) to contain:

```yaml
ingress:
	- hostname: app.example.com
		path: /api/*
		service: http://localhost:5000
	- hostname: app.example.com
		service: http://localhost:3000
	- service: http_status:404
```

2. Ensure you point DNS for `app.example.com` to Cloudflare (or use the random Cloudflare subdomain), then run:

```bash
# run named tunnel using the config
cloudflared tunnel run my-tunnel --config .cloudflared/config.yml
```

This exposes your frontend on `/` and backend on `/api/*` through the same hostname.

4) Notes

- Ephemeral mode is easiest for local dev; persistent tunnels require a Cloudflare account and a registered hostname (or use Cloudflare's random subdomain by configuring DNS/ingress accordingly).
- If `cloudflared` isn't in your PATH, install with Homebrew or download from Cloudflare releases.
