# THREADLOOM — handoff (Janet web weave)

**Codename:** **THREADLOOM** — *weaving the public web threads* (Great Sage ↔ Hey Janet ↔ mascot landing) into deployable, documented strands without losing which repo owns which weft.

**Last updated:** 2026-04-09  
**Scope:** Standalone **`janet-mascot-web`** repo, Cloudflare Pages, GitHub, parent `Janet-Projects` carve-out, API expectations, and “what’s not pushed yet.”

---

## What shipped (this thread)

| Piece | Status |
|--------|--------|
| **Own git repo** in `Janet-Projects/janet-mascot-web/` | `main`, `.gitignore`, `wrangler.toml`, full static tree committed |
| **GitHub remote** | [github.com/MzxzD/janet-mascot-web](https://github.com/MzxzD/janet-mascot-web) — **`origin`**, **`main` pushed** (includes README deploy docs) |
| **Cloudflare Pages project** | `janet-mascot-web`, production branch `main` |
| **First production deploy (CLI)** | `npx wrangler pages deploy . --project-name=janet-mascot-web --commit-dirty=true` — **30 files**; live at **https://janet-mascot-web.pages.dev** |
| **Parent monorepo ignore** | `Janet-Projects/.gitignore` → `janet-mascot-web/` under standalone-repos comment |

---

## Not done yet (resume here)

1. **`Janet-Projects` remote** — Local commit **`4faf3a9`** (`chore: ignore janet-mascot-web`) is **ahead of `origin/main` by 1** and was **never pushed**. Pushing requires your normal `Janet-Projects` workflow (many other local changes exist; push only that commit if you cherry-pick or isolate, or push when you’re ready with a broader snapshot).
2. **Git → Pages auto-builds** — Wrangler does **not** attach GitHub. In **Cloudflare Dashboard**: Workers & Pages → **janet-mascot-web** → Settings → **Connect to Git** → `MzxzD/janet-mascot-web`, branch **`main`**. Optional: Cloudflare REST API can configure `source` **after** the GitHub app is authorized once.
3. **Custom domain** (e.g. `janet.heyjanet.org`) — Add in Pages; then set **`og:image` / canonical** in `index.html` to absolute URLs on that host (see README + Singularity decision below).

---

## Commands cheat sheet

```bash
# Repo root (local path may differ)
cd Janet-Projects/janet-mascot-web   # or your clone

git status
git pull origin main

# Manual Pages upload (no Git hook required)
npx wrangler pages deploy . --project-name=janet-mascot-web --commit-dirty=true
```

---

## API reality check (agent + Cloudflare)

- **Cursor / agent** does not hold your Cloudflare API token unless **`CLOUDFLARE_API_TOKEN`** is set in the shell; **`gh`** and **`wrangler`** use *your* logged-in sessions on the machine.
- **Cloudflare Pages REST API** exists for projects, deployments, and project **`source`** (`type: github`, `repo_name`, `owner`, etc.) — see [Pages projects API](https://developers.cloudflare.com/api/resources/pages/subresources/projects/methods/edit/). Initial **GitHub ↔ Cloudflare** authorization is still normally a **dashboard / OAuth** step; then further automation is easier.

---

## Related docs & sites

| Resource | Role |
|----------|------|
| Repo **README.md** (root) | Live URLs, Git + Pages table |
| **wrangler.toml** | Project name + deploy one-liner |
| Singularity strategy | [gather/20260409-janet-mascot-web-strategy/DECISION.md](../../../gather/20260409-janet-mascot-web-strategy/DECISION.md) (paths relative to `Janet-Projects` if present) |
| Portfolio | [what-can-janet-do](https://github.com/MzxzD/what-can-janet-do) — **heyjanet.org** |
| Great Sage | **greatsage.org** / repo `greatsage-org` |

---

## Pre-deploy reminders (sibling sites, from same weave)

When pushing **greatsage-web** or **what-can-janet-do**, confirm tracked assets match what HTML references (e.g. **`css/apex-nav.css`**, **`css/tokens.css`**) so production does not 404. Portfolio **`node build.mjs`** can fail on GitHub API rate limits; verify `index.html` was not overwritten empty before deploy.

---

## Continuation prompt (paste for next session)

> **THREADLOOM resume:** `janet-mascot-web` is live on GitHub + `janet-mascot-web.pages.dev`. Read `docs/THREADLOOM_HANDOFF.md`. Next: (optional) push `Janet-Projects` commit `4faf3a9`; connect Git on Cloudflare Pages; custom domain + meta absolutes.

---

*THREADLOOM — keep the threads labeled: one repo, one Pages project, one weave.*
