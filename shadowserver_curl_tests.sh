#!/bin/bash
# =============================================================================
# Shadowserver API - curl Test Sheet
# Purpose : Test all major Shadowserver API endpoints before configuring
#           them as DNIF native webhook endpoints
# Auth    : Each request needs your API key in the JSON body + HMAC-SHA256
#           header computed from the request body using your secret
# Docs    : https://github.com/The-Shadowserver-Foundation/api_utils/wiki
# =============================================================================

# ----------------------------------------------------------------------------
# STEP 1 — Fill in your credentials
# ----------------------------------------------------------------------------
API_KEY="YOUR_API_KEY_HERE"
SECRET="YOUR_SECRET_HERE"
BASE_URL="https://transform.shadowserver.org/api2"

# ----------------------------------------------------------------------------
# Helper function — builds the HMAC and fires the curl call
# Usage: call_api <endpoint> <json_body>
# ----------------------------------------------------------------------------
call_api() {
  local ENDPOINT="$1"
  local BODY="$2"

  # Inject apikey into body
  local FULL_BODY=$(echo "$BODY" | python3 -c "
import sys, json
body = json.load(sys.stdin)
body['apikey'] = '$API_KEY'
print(json.dumps(body))
")

  # Compute HMAC-SHA256
  local HMAC=$(echo -n "$FULL_BODY" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

  echo ""
  echo "======================================================================"
  echo "ENDPOINT : $BASE_URL/$ENDPOINT"
  echo "BODY     : $FULL_BODY"
  echo "======================================================================"
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "HMAC2: $HMAC" \
    -d "$FULL_BODY" \
    "$BASE_URL/$ENDPOINT" | python3 -m json.tool
  echo ""
}


# ===========================================================================
# 1. CONNECTIVITY TEST
#    Verify your key and connection are working before anything else
# ===========================================================================

echo ">>> TEST 1: Ping"
call_api "test/ping" '{}'

echo ">>> TEST 2: Key Info (quota, access groups, expiry)"
call_api "key/info" '{}'


# ===========================================================================
# 2. REPORTS — What are you subscribed to?
#    Run these first — they tell you which report types and filters apply
#    to YOUR account. Queries must match your org's filter (ASN / geo / IP).
# ===========================================================================

echo ">>> TEST 3: Reports Subscribed (your lists)"
call_api "reports/subscribed" '{}'

echo ">>> TEST 4: Reports Types (all report types available to you)"
call_api "reports/types" '{}'

echo ">>> TEST 5: Reports Types with detail (description + URL per type)"
call_api "reports/types" '{"detail": true}'


# ===========================================================================
# 3. REPORTS LIST — What report files are available for today?
#    Replace the date below with today or yesterday (YYYY-MM-DD)
# ===========================================================================

DATE_TODAY=$(date +%Y-%m-%d)
DATE_YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)

echo ">>> TEST 6: Reports List for yesterday ($DATE_YESTERDAY) — first 5 files"
call_api "reports/list" "{\"date\": \"$DATE_YESTERDAY\", \"limit\": 5}"

echo ">>> TEST 7: Reports List — blocklist type only"
call_api "reports/list" "{\"type\": \"blocklist\", \"date\": \"$DATE_YESTERDAY\"}"

echo ">>> TEST 8: Reports List — sinkhole events"
call_api "reports/list" "{\"type\": \"event4_sinkhole\", \"date\": \"$DATE_YESTERDAY\"}"


# ===========================================================================
# 4. REPORTS QUERY — Live query of event data
#    IMPORTANT: The query must contain a field that matches your org's
#    filter (geo / asn / ip / domain). Replace "IN" with your country code
#    or replace geo with asn / ip as appropriate for your account.
# ===========================================================================

GEO_FILTER="IN"   # <-- Change to your country code or use asn/ip filter

echo ">>> TEST 9: Reports Query — latest scan events (limit 3)"
call_api "reports/query" "{\"date\": \"$DATE_YESTERDAY\", \"query\": {\"geo\": \"$GEO_FILTER\"}, \"limit\": 3}"

echo ">>> TEST 10: Reports Query — sinkhole events only"
call_api "reports/query" "{\"date\": \"$DATE_YESTERDAY\", \"query\": {\"geo\": \"$GEO_FILTER\", \"type\": \"sinkhole\"}, \"limit\": 3}"

echo ">>> TEST 11: Reports Query — honeypot events only"
call_api "reports/query" "{\"date\": \"$DATE_YESTERDAY\", \"query\": {\"geo\": \"$GEO_FILTER\", \"type\": \"honeypot\"}, \"limit\": 3}"

echo ">>> TEST 12: Reports Query — blocklist events"
call_api "reports/query" "{\"date\": \"$DATE_YESTERDAY\", \"query\": {\"geo\": \"$GEO_FILTER\", \"infection\": \"blocklist\"}, \"limit\": 3}"

echo ">>> TEST 13: Reports Query — RDP scan events"
call_api "reports/query" "{\"date\": \"$DATE_YESTERDAY\", \"query\": {\"geo\": \"$GEO_FILTER\", \"tag\": \"rdp\"}, \"limit\": 3}"

echo ">>> TEST 14: Reports Query — tag frequency facet (top threats)"
call_api "reports/query" "{\"date\": \"$DATE_YESTERDAY\", \"query\": {\"geo\": \"$GEO_FILTER\"}, \"facet\": \"tag\", \"limit\": 10}"

echo ">>> TEST 15: Reports Query — available query fields (help)"
call_api "reports/query" '{"help": true}'


# ===========================================================================
# 5. REPORTS STATS — Historical event counts per report type
# ===========================================================================

echo ">>> TEST 16: Reports Stats — last 3 days"
call_api "reports/stats" '{"date": "-3:now"}'

echo ">>> TEST 17: Reports Stats — sinkhole last 7 days"
call_api "reports/stats" '{"type": "event4_sinkhole", "date": "-7:now"}'


# ===========================================================================
# 6. MALWARE QUERY — Hash / IP malware lookups (no auth filter needed)
# ===========================================================================

echo ">>> TEST 18: Malware Query — lookup by MD5 hash (sample)"
call_api "malware/query" '{"md5": "ae3b6578d90c1c7d97e39b0c08180d17"}'

echo ">>> TEST 19: Malware Query — help (available fields)"
call_api "malware/query" '{"help": true}'


# ===========================================================================
# 7. HONEYPOT — Honeypot event queries
# ===========================================================================

echo ">>> TEST 20: Honeypot Query — help (available fields)"
call_api "honeypot/query" '{"help": true}'

echo ">>> TEST 21: Honeypot Query — brute force events for your geo"
call_api "honeypot/query" "{\"date\": \"$DATE_YESTERDAY\", \"query\": {\"geo\": \"$GEO_FILTER\", \"type\": \"brute_force\"}, \"limit\": 3}"


# ===========================================================================
# 8. ASN / NETWORK QUERIES — Lookup ASN info, prefix, peers
#    These are public (no auth filter restriction)
# ===========================================================================

echo ">>> TEST 22: ASN Info — lookup AS13335 (Cloudflare as a sample)"
call_api "asn/info" '{"asn": 13335}'

echo ">>> TEST 23: ASN Prefix — get prefixes for AS13335"
call_api "asn/prefix" '{"asn": 13335}'

echo ">>> TEST 24: Network Info — lookup an IP prefix"
call_api "network/info" '{"ip": "1.1.1.0/24"}'


# ===========================================================================
# 9. SCAN — Internet-wide scan data (public, no filter needed)
# ===========================================================================

echo ">>> TEST 25: Scan Query — help (available fields)"
call_api "scan/query" '{"help": true}'

echo ">>> TEST 26: Scan Query — open RDP (port 3389) sample"
call_api "scan/query" "{\"query\": {\"port\": 3389, \"geo\": \"$GEO_FILTER\"}, \"limit\": 3}"


# ===========================================================================
# DONE
# Review the output above and note which endpoints return data for your
# account. Those are the ones to configure as DNIF webhook endpoints.
# ===========================================================================
echo ""
echo "======================================================================"
echo "All tests complete. Check output above for non-empty responses."
echo "Endpoints with data → configure as DNIF webhooks."
echo "======================================================================"
