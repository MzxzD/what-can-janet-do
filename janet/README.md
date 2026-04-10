# Janet mascot web — public home

Single-page static site introducing **Janet** with the operator mascot (transparent PNG). No build step, no trackers, system fonts only.

**Continuity / handoff:** [docs/THREADLOOM_HANDOFF.md](docs/THREADLOOM_HANDOFF.md) — codename **THREADLOOM** (repo + Pages + pending steps).

## Preview locally

```bash
open index.html
# or
python3 -m http.server 8765
# → http://127.0.0.1:8765
```

## Git (this folder is its own repo)

Canonical remote: **[github.com/MzxzD/janet-mascot-web](https://github.com/MzxzD/janet-mascot-web)** (`origin` → `main`). This directory is **not** deployed by `git push` from `Janet-Projects/` alone.

`Janet-Projects/.gitignore` lists `janet-mascot-web/` so the umbrella repo does not duplicate-track these files.

## Deploy (your choice)

| Target | Notes |
|--------|--------|
| **Cloudflare Pages (live)** | **https://janet-mascot-web.pages.dev** — production branch `main`. First upload was via CLI; see below for Git-triggered builds. |
| **CLI upload** | From this directory: `npx wrangler pages deploy . --project-name=janet-mascot-web --commit-dirty=true` (see `wrangler.toml`). |
| **Git → Pages (auto)** | Cloudflare Dashboard → **Workers & Pages** → **janet-mascot-web** → **Settings** → connect **GitHub** repo `MzxzD/janet-mascot-web`, production branch **main**. (Wrangler cannot attach Git for you.) |
| **Subdomain** e.g. `janet.heyjanet.org` | In Pages: **Custom domains**; set **og:image** in `index.html` to the **absolute** URL of your hero asset on that host. |
| **Path** e.g. `heyjanet.org/janet/` | Upload this folder under that path; fix asset paths if your host uses a subpath (or set `<base href="…">`). |

**heyjanet.org** currently serves the [what-can-janet-do](../what-can-janet-do/) portfolio; this site is meant to complement it (landing / story / mascot), not replace it unless you decide to merge.

## Singularity decision (launch strategy)

A **Singularity × JACK** run (Cursor Gather + synthesis) produced a recommended **first publish** plan (subdomain vs path, checklist, Phase 4 verification). See:

- [gather/20260409-janet-mascot-web-strategy/DECISION.md](../../gather/20260409-janet-mascot-web-strategy/DECISION.md) (mirrored: [Tools/singularity-gather-janet-web/DECISION.md](../../Tools/singularity-gather-janet-web/DECISION.md))

**Custom domain / final checklist** — see that document; the default `*.pages.dev` site can go live before a custom hostname is attached.

## Assets

- `assets/janet-hero-cityscape.png` — **hero** art (1024×665), used in the top hero and as the video poster / default social preview.
- `assets/janet-mascot-operator-transparent.png` — **updated** rainbow-operator cutout (1024×571); kept for touch icon, optional reuse, and parity with older docs.
- `assets/janet-screen-recording-2026-04-09.mp4` — **H.264** web clip (~3.4s); primary `<video>` source for Chrome/Firefox/Edge.
- `assets/janet-screen-recording-2026-04-09.mov` — original **QuickTime** screen recording from macOS (larger); fallback `<source>` for Safari.
- `assets/favicon.svg` — rainbow arc + star **favicon** (replaces plain “J” glyph).
- `assets/apple-touch-icon.png` — 180×180 generated from the transparent mascot.

**Regenerate MP4** after replacing the `.mov`:

```bash
ffmpeg -y -i assets/janet-screen-recording-2026-04-09.mov -c:v libx264 -crf 22 -pix_fmt yuv420p -movflags +faststart assets/janet-screen-recording-2026-04-09.mp4
```

## License

Align with your chosen repo license for Janet / Great Sage materials (e.g. MIT for site-only content).
