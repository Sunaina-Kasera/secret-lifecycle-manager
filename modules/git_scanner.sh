#!/bin/bash

# ── paths ──────────────────────────────────────────
DB="config/secrets.db.json"
LOG="logs/brain.log"
ALERT="modules/alert_engine.sh"

# ── colors ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── logger ─────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
  echo -e "$1"
}

log "${GREEN}Git Scanner starting...${NC}"

# ── patterns jo detect karne hain ──────────────────
patterns=(
  "AKIA[0-9A-Z]{16}"
  "aws_secret_access_key"
  "password\s*=\s*['\"][^'\"]{8,}"
  "api_key\s*=\s*['\"][^'\"]{8,}"
  "secret\s*=\s*['\"][^'\"]{8,}"
  "token\s*=\s*['\"][^'\"]{8,}"
  "private_key"
  "BEGIN RSA PRIVATE KEY"
  "BEGIN OPENSSH PRIVATE KEY"
)

# ── last commit ki changes scan karo ───────────────
log "Scanning last commit for leaked secrets..."

found=0

for pattern in "${patterns[@]}"; do
  result=$(git diff HEAD~1 HEAD 2>/dev/null | grep -iE "$pattern")

  if [ -n "$result" ]; then
    found=1
    log "${RED}LEAKED SECRET FOUND!${NC}"
    log "${YELLOW}Pattern matched: $pattern${NC}"

    # brain ko batao — status compromised karo
    total=$(jq '.secrets | length' "$DB")
    for i in $(seq 0 $((total - 1))); do
      type=$(jq -r ".secrets[$i].type" "$DB")
      if echo "$pattern" | grep -q "AKIA\|aws_secret"; then
        if [ "$type" == "aws_access_key" ]; then
          jq ".secrets[$i].status = \"compromised\"" "$DB" > tmp.json && mv tmp.json "$DB"
          log "${RED}Status updated to compromised in DB${NC}"
          bash "$ALERT" "CRITICAL" "aws-main-key" "AWS key leaked in git commit — immediate action needed"
        fi
      else
        jq ".secrets[$i].status = \"compromised\"" "$DB" > tmp.json && mv tmp.json "$DB"
        bash "$ALERT" "CRITICAL" "unknown-secret" "Secret pattern leaked in git commit — check immediately"
      fi
    done
  fi
done

# ── .env files bhi check karo ──────────────────────
log "Checking for accidentally committed .env files..."

env_files=$(git diff HEAD~1 HEAD --name-only 2>/dev/null | grep -E "\.env|\.pem|\.key|id_rsa")

if [ -n "$env_files" ]; then
  found=1
  log "${RED}Sensitive file committed: $env_files${NC}"
  bash "$ALERT" "CRITICAL" "sensitive-file" "Sensitive file committed to git: $env_files"
fi

# ── result ─────────────────────────────────────────
if [ "$found" -eq 0 ]; then
  log "${GREEN}Git scan complete — no secrets found. All clear.${NC}"
else
  log "${RED}Git scan complete — issues found! Check alerts above.${NC}"
fi
