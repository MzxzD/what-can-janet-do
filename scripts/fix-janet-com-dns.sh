#!/usr/bin/env bash
#
# Fix Cloudflare Error 1000 for ジャネット.com (xn--yckwaps3i.com)
# Removes A records pointing to prohibited Cloudflare IPs and ensures CNAME to tunnel.
#
# Usage: ./fix-janet-com-dns.sh
# Prerequisites: scripts/.env with CLOUDFLARE_API_TOKEN
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
ZONE_NAME="xn--yckwaps3i.com"
TUNNEL_CNAME="69067bfd-f27c-4a86-a5f9-8c2bc839e952.cfargotunnel.com"

# Cloudflare IPv4 ranges (prohibited - cause Error 1000)
CF_IP_RANGES=(
  "173.245.48.0/20"
  "103.21.244.0/22"
  "103.22.200.0/22"
  "103.31.4.0/22"
  "141.101.64.0/18"
  "108.162.192.0/18"
  "190.93.240.0/20"
  "188.114.96.0/20"
  "197.234.240.0/22"
  "198.41.128.0/17"
  "162.158.0.0/15"
  "104.16.0.0/13"
  "104.24.0.0/14"
  "172.64.0.0/13"
  "131.0.72.0/22"
)

# Load env
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found. Add CLOUDFLARE_API_TOKEN"
  exit 1
fi
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "Error: CLOUDFLARE_API_TOKEN must be set in scripts/.env"
  echo "Create token: https://dash.cloudflare.com/profile/api-tokens"
  echo "Permissions: Zone - Zone: Read, Zone - DNS: Edit"
  exit 1
fi

# Token should be 40 chars; short tokens often indicate truncation
if [[ ${#CLOUDFLARE_API_TOKEN} -lt 35 ]]; then
  echo "Warning: CLOUDFLARE_API_TOKEN looks short. Create a new token at:"
  echo "  https://dash.cloudflare.com/profile/api-tokens"
  echo "  Permissions: Zone - Zone: Read, Zone - DNS: Edit"
fi

AUTH_HEADER="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"

# Get zone ID (use CLOUDFLARE_ZONE_ID from env if set)
if [[ -z "$ZONE_ID" ]]; then
  echo "Fetching zone for $ZONE_NAME..."
  ZONE_RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${ZONE_NAME}" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json")
  if ! echo "$ZONE_RESP" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "Failed to get zone:"
    echo "$ZONE_RESP" | jq '.' 2>/dev/null || echo "$ZONE_RESP"
    exit 1
  fi
  ZONE_ID=$(echo "$ZONE_RESP" | jq -r '.result[0].id')
  if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
    echo "Zone $ZONE_NAME not found. Set CLOUDFLARE_ZONE_ID in .env"
    exit 1
  fi
fi
echo "Zone ID: $ZONE_ID"

# List DNS records
echo ""
echo "Fetching DNS records..."
RECORDS_RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json")

if ! echo "$RECORDS_RESP" | jq -e '.success == true' >/dev/null 2>&1; then
  echo "Failed to list records:"
  echo "$RECORDS_RESP" | jq '.' 2>/dev/null || echo "$RECORDS_RESP"
  exit 1
fi

# Check if IP is in Cloudflare range (causes Error 1000)
is_cloudflare_ip() {
  local ip="$1"
  python3 -c "
import ipaddress
ip = ipaddress.ip_address('$ip')
ranges = [
    '173.245.48.0/20', '103.21.244.0/22', '103.22.200.0/22', '103.31.4.0/22',
    '141.101.64.0/18', '108.162.192.0/18', '190.93.240.0/20', '188.114.96.0/20',
    '197.234.240.0/22', '198.41.128.0/17', '162.158.0.0/15', '104.16.0.0/13',
    '104.24.0.0/14', '172.64.0.0/13', '131.0.72.0/22'
]
for r in ranges:
    if ip in ipaddress.ip_network(r):
        exit(0)
exit(1)
" 2>/dev/null
}

# Process A and AAAA records
for type in A AAAA; do
  echo ""
  echo "Checking $type records..."
  echo "$RECORDS_RESP" | jq -r --arg t "$type" '.result[] | select(.type == $t) | "\(.name)|\(.type)|\(.content)|\(.id)"' | while IFS='|' read -r name rtype content rec_id; do
    [[ -z "$name" ]] && continue
    echo "  $name $rtype -> $content (id: $rec_id)"
    # A/AAAA pointing to Cloudflare IP causes Error 1000
    if is_cloudflare_ip "$content" 2>/dev/null; then
      echo "  ⚠️  PROHIBITED: $content is a Cloudflare IP - deleting..."
      DEL_RESP=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${rec_id}" \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json")
      if echo "$DEL_RESP" | jq -e '.success == true' >/dev/null 2>&1; then
        echo "  ✅ Deleted"
      else
        echo "  ❌ Delete failed: $DEL_RESP"
      fi
    fi
  done
done

# Ensure CNAME exists for apex
echo ""
echo "Ensuring CNAME for @ -> $TUNNEL_CNAME..."
EXISTING_CNAME=$(echo "$RECORDS_RESP" | jq -r '.result[] | select(.type == "CNAME" and (.name == "xn--yckwaps3i.com" or .name == "@" or .name == $ZONE_NAME)) | "\(.id)|\(.content)"' --arg ZONE_NAME "$ZONE_NAME" | head -1)

if [[ -n "$EXISTING_CNAME" && "$EXISTING_CNAME" != "null" ]]; then
  rec_id="${EXISTING_CNAME%%|*}"
  target="${EXISTING_CNAME#*|}"
  echo "  Found CNAME -> $target"
  if [[ "$target" != "$TUNNEL_CNAME" ]]; then
    echo "  Updating to tunnel target..."
    UPD_RESP=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${rec_id}" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"CNAME\",\"name\":\"@\",\"content\":\"${TUNNEL_CNAME}\",\"ttl\":1,\"proxied\":true}")
    echo "$UPD_RESP" | jq -e '.success == true' >/dev/null 2>&1 && echo "  ✅ Updated" || echo "  Response: $UPD_RESP"
  fi
else
  echo "  Adding CNAME @ -> $TUNNEL_CNAME..."
  ADD_RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"CNAME\",\"name\":\"@\",\"content\":\"${TUNNEL_CNAME}\",\"ttl\":1,\"proxied\":true}")
  if echo "$ADD_RESP" | jq -e '.success == true' >/dev/null 2>&1; then
    echo "  ✅ Added"
  else
    echo "  Response: $ADD_RESP"
  fi
fi

echo ""
echo "Done. DNS may take 1–2 minutes to propagate."
echo "Test: curl -I https://xn--yckwaps3i.com"
echo "Or visit: https://ジャネット.com"
