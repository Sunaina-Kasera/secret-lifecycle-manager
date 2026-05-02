#!/bin/bash

# ── paths ──────────────────────────────────────────
DB="config/secrets.db.json"
LOG="logs/brain.log"
ALERT="modules/alert_engine.sh"

# ── colors for terminal output ──────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── logger ─────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
  echo -e "$1"
}

# ── check karo kitne din baaki hain expiry mein ────
days_until_expiry() {
  expiry_date=$1
  today=$(date '+%Y-%m-%d')
  expiry_sec=$(date -d "$expiry_date" '+%s')
  today_sec=$(date -d "$today" '+%s')
  echo $(( (expiry_sec - today_sec) / 86400 ))
}

# ── main logic ─────────────────────────────────────
log "${GREEN}Brain starting...${NC}"

total=$(jq '.secrets | length' "$DB")
log "Total secrets found: $total"

for i in $(seq 0 $((total - 1))); do

  id=$(jq -r ".secrets[$i].id" "$DB")
  status=$(jq -r ".secrets[$i].status" "$DB")
  expiry=$(jq -r ".secrets[$i].expiry_date" "$DB")
  alert_sent=$(jq -r ".secrets[$i].alert_sent" "$DB")

  days=$(days_until_expiry "$expiry")

  log "Checking: $id | Status: $status | Days left: $days"

  # ── leaked secret ───────────────────────────────
  if [ "$status" == "compromised" ]; then
    log "${RED}ALERT: $id is compromised! Rotating immediately...${NC}"
    bash "$ALERT" "CRITICAL" "$id" "Secret is compromised — immediate rotation needed"

  # ── expiry 15 din se kam ────────────────────────
  elif [ "$days" -le 15 ] && [ "$alert_sent" == "false" ]; then
    log "${YELLOW}WARNING: $id expires in $days days${NC}"
    bash "$ALERT" "WARNING" "$id" "Secret expires in $days days"

    # alert_sent true kar do
    jq ".secrets[$i].alert_sent = true" "$DB" > tmp.json && mv tmp.json "$DB"
    jq ".secrets[$i].status = \"expiring_soon\"" "$DB" > tmp.json && mv tmp.json "$DB"

  # ── sab theek hai ───────────────────────────────
  else
    log "${GREEN}OK: $id is healthy — $days days remaining${NC}"
  fi

done

log "${GREEN}Brain check complete.${NC}"#!/bin/bash

# ── paths ──────────────────────────────────────────
DB="config/secrets.db.json"
LOG="logs/brain.log"
ALERT="modules/alert_engine.sh"

# ── colors for terminal output ──────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── logger ─────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
  echo -e "$1"
}

# ── check karo kitne din baaki hain expiry mein ────
days_until_expiry() {
  expiry_date=$1
  today=$(date '+%Y-%m-%d')
  expiry_sec=$(date -d "$expiry_date" '+%s')
  today_sec=$(date -d "$today" '+%s')
  echo $(( (expiry_sec - today_sec) / 86400 ))
}

# ── main logic ─────────────────────────────────────
log "${GREEN}Brain starting...${NC}"

total=$(jq '.secrets | length' "$DB")
log "Total secrets found: $total"

for i in $(seq 0 $((total - 1))); do

  id=$(jq -r ".secrets[$i].id" "$DB")
  status=$(jq -r ".secrets[$i].status" "$DB")
  expiry=$(jq -r ".secrets[$i].expiry_date" "$DB")
  alert_sent=$(jq -r ".secrets[$i].alert_sent" "$DB")

  days=$(days_until_expiry "$expiry")

  log "Checking: $id | Status: $status | Days left: $days"

  # ── leaked secret ───────────────────────────────
  if [ "$status" == "compromised" ]; then
    log "${RED}ALERT: $id is compromised! Rotating immediately...${NC}"
    bash "$ALERT" "CRITICAL" "$id" "Secret is compromised — immediate rotation needed"

  # ── expiry 15 din se kam ────────────────────────
  elif [ "$days" -le 15 ] && [ "$alert_sent" == "false" ]; then
    log "${YELLOW}WARNING: $id expires in $days days${NC}"
    bash "$ALERT" "WARNING" "$id" "Secret expires in $days days"

    # alert_sent true kar do
    jq ".secrets[$i].alert_sent = true" "$DB" > tmp.json && mv tmp.json "$DB"
    jq ".secrets[$i].status = \"expiring_soon\"" "$DB" > tmp.json && mv tmp.json "$DB"

  # ── sab theek hai ───────────────────────────────
  else
    log "${GREEN}OK: $id is healthy — $days days remaining${NC}"
  fi

done

log "${GREEN}Brain check complete.${NC}"
