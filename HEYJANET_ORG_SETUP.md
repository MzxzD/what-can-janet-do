# Complete heyjanet.org Setup (Manual Steps)

The codebase changes are done. To make heyjanet.org live and avoid LinkedIn's block on `what-can-janet-do.pages.dev`, complete these manual steps.

## Automated Setup (Optional)

You can automate the setup using Cloudflare and Namecheap APIs.

1. Copy `scripts/.env.example` to `scripts/.env` and fill in your credentials.
2. Add `scripts/.env` to `.gitignore` (already done; never commit secrets).
3. Run:
   - **Option A (Cloudflare DNS, recommended):** `./scripts/setup-heyjanet-org.sh --option-a`
   - **Option B (Namecheap DNS):** `./scripts/setup-heyjanet-org.sh --option-b`
   - **Dry run:** `./scripts/setup-heyjanet-org.sh --dry-run --option-a`
   - **Verify only:** `./scripts/setup-heyjanet-org.sh --verify-only`

Prerequisites: Cloudflare API token (Pages + Zone + DNS Edit), Namecheap API enabled with IP whitelisted. See `scripts/.env.example` for details.

## 1. Add Custom Domain in Cloudflare Pages

- [ ] Open [Cloudflare Dashboard](https://dash.cloudflare.com) → **Workers & Pages**
- [ ] Select project **what-can-janet-do**
- [ ] Go to **Settings** → **Custom domains** → **Set up custom domain**
- [ ] Enter `heyjanet.org`
- [ ] Optionally add `www.heyjanet.org`
- [ ] Note the CNAME target Cloudflare shows (e.g. `what-can-janet-do.pages.dev`)

## 2. Configure DNS for heyjanet.org

### Option A: Use Cloudflare for DNS (recommended)

- [ ] In Cloudflare: **Websites** → **Add a site** → enter `heyjanet.org`
- [ ] Choose Free plan
- [ ] Cloudflare shows nameservers (e.g. `ada.ns.cloudflare.com`, `bob.ns.cloudflare.com`)
- [ ] In Namecheap: **Domain List** → heyjanet.org → **Manage** → **Nameservers** → **Custom DNS**
- [ ] Enter Cloudflare's two nameservers
- [ ] In Cloudflare Pages: add custom domain `heyjanet.org`; Cloudflare will create DNS records

### Option B: Keep Namecheap DNS

- [ ] In Namecheap: **Advanced DNS** for heyjanet.org
- [ ] Add **CNAME Record**: Host `@` or `www`, Value `what-can-janet-do.pages.dev` (or Cloudflare's exact target)
- [ ] For apex (`@`), use **ALIAS** or **URL Redirect Record** if CNAME is not supported; follow Cloudflare's instructions

## 3. Verify

- [ ] Visit [https://heyjanet.org](https://heyjanet.org) (use a private/incognito window)
- [ ] Confirm the what-can-janet-do portfolio loads
- [ ] Test the link on LinkedIn; it should no longer be blocked
