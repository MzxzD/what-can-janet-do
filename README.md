# What can Janet do?

Self-updating portfolio webpage for the Janet AI ecosystem. Pulls repo list, README descriptions, and release info from GitHub on a schedule.

**Live:** https://heyjanet.org (fallback: [what-can-janet-do.pages.dev](https://what-can-janet-do.pages.dev)) | **Docs:** [DOCUMENTATION.md](DOCUMENTATION.md)

## Quick Start

```bash
node build.mjs
```

Generates `index.html` from `template.html` and `config.json`.

## Config

Edit `config.json`:

- **domain** – Custom domain for CNAME (e.g. `heyjanet.org`)
- **repos** – List of `owner/repo` to fetch
- **readmeMaxLength** – Max chars for README excerpt (default 400)
- **showStars** / **showReleases** – Toggle badges and release links

## Deploy

### Cloudflare Pages

1. Create a repo (e.g. `MzxzD/what-can-janet-do`) and push this project
2. Connect to Cloudflare Pages (Build: none, output: root)
3. Add custom domain in Cloudflare Pages → Custom domains
4. Set `CNAME` file to your domain, or add domain in Pages settings

### GitHub Actions

The workflow runs:

- On push to `main` or `master`
- Every 6 hours (`cron: '0 */6 * * *'`)

It fetches GitHub data, rebuilds `index.html`, and commits if changed. Cloudflare Pages will redeploy on push.

## Custom Domain: heyjanet.org

heyjanet.org is configured in `config.json` and `CNAME`. To serve the site at heyjanet.org (currently on Namecheap):

**Option A: Use Cloudflare for DNS**
1. Add heyjanet.org to your Cloudflare account (Add site)
2. Change nameservers at Namecheap to Cloudflare's
3. In Pages → what-can-janet-do → Custom domains → add heyjanet.org

**Option B: Keep Namecheap DNS**
1. In Pages → Custom domains → Set up a custom domain → enter `heyjanet.org`
2. Cloudflare shows the CNAME target (e.g. `what-can-janet-do.pages.dev`)
3. At Namecheap: Domain List → Manage → Advanced DNS → add CNAME: `@` → target from Cloudflare
4. For apex (@), Namecheap may require URL Redirect or ALIAS; follow Cloudflare's exact instructions

## Verification

| URL | Status |
|-----|--------|
| https://heyjanet.org | Primary (requires DNS setup) |
| https://what-can-janet-do.pages.dev | Fallback (live) |

## Local Build

```bash
# Without token (60 req/hr limit)
node build.mjs

# With token for higher limits
GITHUB_TOKEN=ghp_xxx node build.mjs
```
