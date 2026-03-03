#!/usr/bin/env bash
#
# Heyjanet.org Setup Automation
# Configures heyjanet.org as a custom domain for the what-can-janet-do Pages project.
#
# Usage:
#   ./setup-heyjanet-org.sh --option-a   # Cloudflare DNS (recommended)
#   ./setup-heyjanet-org.sh --option-b   # Namecheap DNS
#   ./setup-heyjanet-org.sh --verify-only
#   ./setup-heyjanet-org.sh --dry-run [--option-a|--option-b]
#
# Prerequisites: Copy scripts/.env.example to scripts/.env and fill in credentials.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
DOMAIN="${DOMAIN:-heyjanet.org}"
SLD="heyjanet"
TLD="org"
PAGES_PROJECT="${CLOUDFLARE_PAGES_PROJECT:-what-can-janet-do}"
PAGES_CNAME="${PAGES_CNAME_TARGET:-what-can-janet-do.pages.dev}"

# -----------------------------------------------------------------------------
# Load environment
# -----------------------------------------------------------------------------
load_env() {
    local skip_validation="${1:-false}"
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "Error: $ENV_FILE not found. Copy scripts/.env.example to scripts/.env and fill in credentials."
        exit 1
    fi
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a

    if [[ "$skip_validation" != "true" ]]; then
        if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
            echo "Error: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID must be set in .env"
            exit 1
        fi

        if [[ -z "${NAMECHEAP_API_USER:-}" || -z "${NAMECHEAP_API_KEY:-}" || -z "${NAMECHEAP_USERNAME:-}" ]]; then
            echo "Error: NAMECHEAP_API_USER, NAMECHEAP_API_KEY, NAMECHEAP_USERNAME must be set in .env"
            exit 1
        fi
    fi

    NAMECHEAP_CLIENT_IP="${NAMECHEAP_CLIENT_IP:-}"
    if [[ -z "$NAMECHEAP_CLIENT_IP" ]]; then
        NAMECHEAP_CLIENT_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")
        if [[ -z "$NAMECHEAP_CLIENT_IP" && "$skip_validation" != "true" ]]; then
            echo "Error: Could not auto-detect IP. Set NAMECHEAP_CLIENT_IP in .env (must be whitelisted in Namecheap)."
            exit 1
        fi
        [[ -n "$NAMECHEAP_CLIENT_IP" ]] && echo "Auto-detected NAMECHEAP_CLIENT_IP: $NAMECHEAP_CLIENT_IP"
    fi
}

# -----------------------------------------------------------------------------
# Cloudflare: Create zone (Option A)
# -----------------------------------------------------------------------------
cf_create_zone() {
    local dry_run="${1:-false}"
    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Would create Cloudflare zone for $DOMAIN"
        echo "  curl -X POST 'https://api.cloudflare.com/client/v4/zones' \\"
        echo "    -H 'Authorization: Bearer \$CLOUDFLARE_API_TOKEN' \\"
        echo "    -H 'Content-Type: application/json' \\"
        echo "    -d '{\"name\":\"$DOMAIN\",\"account\":{\"id\":\"$CLOUDFLARE_ACCOUNT_ID\"},\"jump_start\":true}'"
        return 0
    fi

    local resp
    resp=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$DOMAIN\",\"account\":{\"id\":\"$CLOUDFLARE_ACCOUNT_ID\"},\"jump_start\":true}")

    if ! echo "$resp" | jq -e '.success == true' >/dev/null 2>&1; then
        echo "Cloudflare create zone failed:"
        echo "$resp" | jq '.' 2>/dev/null || echo "$resp"
        return 1
    fi

    local zone_id nameservers
    zone_id=$(echo "$resp" | jq -r '.result.id')
    nameservers=$(echo "$resp" | jq -r '.result.name_servers | join(",")')
    echo "Created zone $DOMAIN (ID: $zone_id)"
    echo "Nameservers: $nameservers"
    echo "$nameservers"
}

# -----------------------------------------------------------------------------
# Cloudflare: Add custom domain to Pages project
# -----------------------------------------------------------------------------
cf_add_pages_domain() {
    local dry_run="${1:-false}"
    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Would add custom domain $DOMAIN to Pages project $PAGES_PROJECT"
        echo "  Manual fallback: Dashboard → Workers & Pages → $PAGES_PROJECT → Settings → Custom domains"
        return 0
    fi

    local url="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${PAGES_PROJECT}/domains"
    local resp
    resp=$(curl -s -X POST "$url" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$DOMAIN\"}" 2>/dev/null || echo '{"success":false}')

    if echo "$resp" | jq -e '.success == true' >/dev/null 2>&1; then
        echo "Added custom domain $DOMAIN to Pages project $PAGES_PROJECT"
    else
        echo "WARNING: Pages custom domain API may not be available. Add manually:"
        echo "  Dashboard → Workers & Pages → $PAGES_PROJECT → Settings → Custom domains → Set up custom domain → $DOMAIN"
        echo "  API response: $resp"
    fi
}

# -----------------------------------------------------------------------------
# Namecheap: Set custom nameservers (Option A)
# -----------------------------------------------------------------------------
namecheap_set_custom_ns() {
    local ns_list="$1"
    local dry_run="${2:-false}"

    local url="https://api.namecheap.com/xml.response?ApiUser=${NAMECHEAP_API_USER}&ApiKey=${NAMECHEAP_API_KEY}&UserName=${NAMECHEAP_USERNAME}&ClientIp=${NAMECHEAP_CLIENT_IP}&Command=namecheap.domains.dns.setCustom&SLD=${SLD}&TLD=${TLD}&Nameservers=${ns_list// /}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Would set Namecheap custom nameservers: $ns_list"
        echo "  Command: namecheap.domains.dns.setCustom"
        return 0
    fi

    local resp
    resp=$(curl -s "$url")

    if echo "$resp" | grep -q 'Status="OK"'; then
        echo "Set Namecheap nameservers to: $ns_list"
    else
        echo "Namecheap setCustom failed:"
        echo "$resp"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Namecheap: Option B - getHosts + setHosts (add CNAME www, URL301 for apex)
# setHosts overwrites ALL records; we preserve existing and add CNAME + URL301
# -----------------------------------------------------------------------------
namecheap_option_b() {
    local dry_run="${1:-false}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Would fetch hosts, add CNAME www + URL301 @, then setHosts"
        return 0
    fi

    python3 << 'PYTHON_SCRIPT'
import os
import sys
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET

api_user = os.environ["NAMECHEAP_API_USER"]
api_key = os.environ["NAMECHEAP_API_KEY"]
username = os.environ["NAMECHEAP_USERNAME"]
client_ip = os.environ["NAMECHEAP_CLIENT_IP"]
sld = "heyjanet"
tld = "org"
target = "what-can-janet-do.pages.dev"
domain = "heyjanet.org"

def api_call(cmd, extra_params=None):
    params = {
        "ApiUser": api_user, "ApiKey": api_key, "UserName": username, "ClientIp": client_ip,
        "Command": cmd, "SLD": sld, "TLD": tld
    }
    if extra_params:
        params.update(extra_params)
    url = "https://api.namecheap.com/xml.response?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read().decode()

# Get existing hosts
resp = api_call("namecheap.domains.dns.getHosts")
root = ET.fromstring(resp)
if root.get("Status") != "OK":
    err = root.find(".//{http://api.namecheap.com/xml.response}Error")
    print("getHosts failed:", err.get("Number") if err is not None else resp, file=sys.stderr)
    sys.exit(1)

ns = "{http://api.namecheap.com/xml.response}"
hosts = []
for h in root.findall(f".//{ns}Host"):
    name, rtype, addr = h.get("Name"), h.get("Type"), h.get("Address")
    ttl = h.get("TTL", "1800")
    if name == "www" and rtype == "CNAME":
        continue
    if name == "@" and rtype in ("URL301", "URL"):
        continue
    if name and rtype and addr:
        hosts.append((name, rtype, addr, ttl))

hosts.append(("www", "CNAME", target, "1800"))
hosts.append(("@", "URL301", f"https://www.{domain}", "1800"))

# setHosts
params = {}
for i, (name, rtype, addr, ttl) in enumerate(hosts, 1):
    params[f"HostName{i}"] = name
    params[f"RecordType{i}"] = rtype
    params[f"Address{i}"] = addr
    params[f"TTL{i}"] = ttl

resp = api_call("namecheap.domains.dns.setHosts", params)
root = ET.fromstring(resp)
if root.get("Status") != "OK":
    err = root.find(".//{http://api.namecheap.com/xml.response}Error")
    print("setHosts failed:", err.get("Number") if err is not None else resp, file=sys.stderr)
    sys.exit(1)

print(f"Set DNS: www CNAME -> {target}, @ URL301 -> https://www.{domain}")
PYTHON_SCRIPT
}

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------
verify() {
    echo "Verifying heyjanet.org..."
    echo ""

    if command -v dig &>/dev/null; then
        echo "DNS (dig):"
        dig +short heyjanet.org || true
        dig +short www.heyjanet.org || true
        echo ""
    else
        echo "DNS: install dig for DNS checks, or use: host heyjanet.org"
        echo ""
    fi

    echo "HTTPS:"
    local code
    code=$(curl -sI -o /dev/null -w "%{http_code}" "https://heyjanet.org" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
        echo "  https://heyjanet.org -> $code OK"
    else
        echo "  https://heyjanet.org -> $code (check manually; DNS may still be propagating)"
    fi

    code=$(curl -sI -o /dev/null -w "%{http_code}" "https://www.heyjanet.org" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
        echo "  https://www.heyjanet.org -> $code OK"
    else
        echo "  https://www.heyjanet.org -> $code (check manually)"
    fi

    echo ""
    echo "DNS propagation can take 5-30 minutes. Test in incognito: https://heyjanet.org"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    local option_a=false option_b=false dry_run=false verify_only=false

    for arg in "$@"; do
        case "$arg" in
            --option-a) option_a=true ;;
            --option-b) option_b=true ;;
            --dry-run)  dry_run=true ;;
            --verify-only) verify_only=true ;;
            -h|--help)
                head -20 "${BASH_SOURCE[0]}" | tail -15
                exit 0
                ;;
        esac
    done

    if [[ "$verify_only" == "true" ]]; then
        verify
        exit 0
    fi

    if [[ "$option_a" != "true" && "$option_b" != "true" ]]; then
        echo "Usage: $0 --option-a | --option-b | --verify-only [--dry-run]"
        echo "  --option-a   Cloudflare DNS (recommended)"
        echo "  --option-b   Namecheap DNS"
        echo "  --verify-only  Only run verification checks"
        echo "  --dry-run    Print actions without executing"
        exit 1
    fi

    load_env "$dry_run"

    if [[ "$option_a" == "true" ]]; then
        echo "=== Option A: Cloudflare DNS ==="
        local ns_list
        if [[ "$dry_run" == "true" ]]; then
            cf_create_zone "$dry_run"
            cf_add_pages_domain "$dry_run"
            echo "[DRY RUN] Would set Namecheap nameservers (from zone creation)"
        else
            ns_list=$(cf_create_zone "$dry_run")
            if [[ -n "$ns_list" ]]; then
                cf_add_pages_domain "$dry_run"
                namecheap_set_custom_ns "$ns_list" "$dry_run"
            fi
        fi
    fi

    if [[ "$option_b" == "true" ]]; then
        echo "=== Option B: Namecheap DNS ==="
        cf_add_pages_domain "$dry_run"
        namecheap_option_b "$dry_run"
    fi

    echo ""
    echo "Done. Run with --verify-only after DNS propagates (5-30 min)."
}

main "$@"
