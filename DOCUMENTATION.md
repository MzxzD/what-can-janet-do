# What can Janet do? — Complete Documentation

Self-updating portfolio webpage for the Janet AI ecosystem. Pulls repo list, README descriptions, and release info from GitHub on a schedule. Designed for [heyjanet.org](https://heyjanet.org).

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Quick Start](#quick-start)
4. [Configuration](#configuration)
5. [Deployment](#deployment)
6. [Custom Domain (heyjanet.org)](#custom-domain-heyjanetorg)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

---

## Overview

**What can Janet do?** is a static, self-updating portfolio that showcases Janet-related GitHub repos. It:

- Fetches repo metadata, README excerpts, and latest releases from the GitHub API
- Renders a single-page HTML site using the janet_landing design (sky blue, dark theme, Syne + JetBrains Mono)
- Auto-updates every 6 hours via GitHub Actions
- Deploys to Cloudflare Pages

**Live URLs:**

| URL | Status |
|-----|--------|
| https://heyjanet.org | Primary (requires DNS setup) |
| https://what-can-janet-do.pages.dev | Fallback (live) |

**Repo:** https://github.com/MzxzD/what-can-janet-do

---

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│   GitHub API    │────▶│  build.mjs   │────▶│   index.html    │
│ (repos, README, │     │  (Node.js)   │     │ (static output) │
│   releases)     │     └──────────────┘     └────────┬────────┘
└─────────────────┘            │                      │
                               │                      ▼
                     ┌─────────┴─────────┐   ┌─────────────────┐
                     │  GitHub Actions   │   │ Cloudflare Pages│
                     │ (every 6h + push) │   │  (serves site)  │
                     └───────────────────┘   └─────────────────┘
```

**Data flow:**

1. `build.mjs` reads `config.json` and fetches GitHub API for each repo
2. Renders `template.html` with placeholders, writes `index.html`
3. GitHub Actions runs on push and every 6 hours; commits `index.html` if changed
4. Cloudflare Pages deploys from the repo (static, no build step)

---

## Quick Start

### Run locally

```bash
cd Janet-Projects/what-can-janet-do   # or: cd ~/Documents/Janet-Projects/what-can-janet-do
node build.mjs
```

Opens `index.html` in a browser, or serve with any static server:

```bash
python3 -m http.server 8080
# or: npx serve .
```

### Deploy (Cloudflare Pages)

1. Push the repo to GitHub
2. Cloudflare Dashboard → Pages → Create project → Connect to Git
3. Select `MzxzD/what-can-janet-do`
4. Build settings: no build command, output directory `/`
5. Save and Deploy

---

## Configuration

Edit `config.json`:

| Key | Description |
|-----|-------------|
| `domain` | Custom domain (e.g. `heyjanet.org`) |
| `title` | Page title |
| `tagline` | Hero tagline |
| `repos` | Array of `owner/repo` to fetch |
| `readmeMaxLength` | Max chars for README excerpt (default 400) |
| `showStars` | Show star count on cards |
| `showReleases` | Show latest release and download links |
| `footerLinks` | Links for footer |

**Example `repos`:**

```json
["MzxzD/Janet-Projects", "MzxzD/Janet-Awakening", "MzxzD/Janet-seed"]
```

---

## Deployment

### Cloudflare Pages

- **Project:** what-can-janet-do
- **Build command:** (leave empty)
- **Build output directory:** `/`
- **Root directory:** (default)

Deploy via Git: push to `main` triggers a new deploy. Or deploy manually:

```bash
cd ~/Documents/Janet-Projects/what-can-janet-do
wrangler pages deploy . --project-name=what-can-janet-do
```

(Requires Node 20+ and `wrangler` CLI.)

### GitHub Actions

Workflow: `.github/workflows/update.yml`

- **Triggers:** Push to `main`/`master`, and cron every 6 hours
- **Steps:** Checkout → `node build.mjs` → commit & push `index.html` if changed

Uses `GITHUB_TOKEN` for higher API rate limits.

---

## Custom Domain (heyjanet.org)

heyjanet.org is configured in `config.json` and `CNAME`. DNS is managed at Namecheap.

**Setup checklist:** See [HEYJANET_ORG_SETUP.md](HEYJANET_ORG_SETUP.md) for a step-by-step checklist.

### Option A: Cloudflare DNS (recommended)

1. Cloudflare Dashboard → Add site → `heyjanet.org`
2. Namecheap → Domain List → Manage → Nameservers → Custom DNS
3. Enter the Cloudflare nameservers (e.g. `ada.ns.cloudflare.com`, `bob.ns.cloudflare.com`)
4. Pages → what-can-janet-do → Custom domains → Set up a custom domain → `heyjanet.org`
5. Cloudflare will create the DNS record automatically

### Option B: Namecheap DNS

1. Pages → what-can-janet-do → Custom domains → Set up a custom domain → `heyjanet.org`
2. Cloudflare shows the CNAME target (e.g. `what-can-janet-do.pages.dev`)
3. Namecheap → Advanced DNS → Add record:
   - Type: CNAME
   - Host: `@` (for apex) or `www`
   - Value: `what-can-janet-do.pages.dev`
4. For apex `@`, Namecheap may require URL Redirect Record or ALIAS; use the exact instructions Cloudflare provides

---

## Verification

### Status

| URL | Status | Notes |
|-----|--------|-------|
| https://heyjanet.org | Primary | Requires DNS setup (see [Custom Domain](#custom-domain-heyjanetorg)) |
| https://what-can-janet-do.pages.dev | Fallback | Live (use if heyjanet.org DNS not yet configured) |

### What to verify

- Hero: "What can Janet do?"
- Vision section and blockquote
- 5 project cards with README excerpts
- Release links (e.g. Janet-Awakening v0.0.1)
- Principles grid
- Footer links (heyjanet.bot, ジャネット.com)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `cd Janet-Projects/what-can-janet-do` fails | Use full path: `cd ~/Documents/Janet-Projects/what-can-janet-do` or `cd ../what-can-janet-do` from janet-arm64-toolchain |
| Wrangler needs Node 20 | `nvm use 20` or upgrade Node |
| GitHub API rate limit | Set `GITHUB_TOKEN=ghp_xxx` when running `node build.mjs` |
| heyjanet.org shows parking page | DNS not yet pointed to Cloudflare Pages; follow [Custom Domain](#custom-domain-heyjanetorg) |
| index.html not updating | Check GitHub Actions tab; workflow may need `GITHUB_TOKEN` permissions |

---

**Last updated:** 2026-03-03
