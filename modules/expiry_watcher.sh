#!/bin/bash

# ── paths ──────────────────────────────────────────
DB="config/secrets.db.json"
LOG="logs/brain.log"
ALERT="modules/alert_engine.sh"

# ── colors ─────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── logger ─────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
  echo -e "$1"
}

# ── days calculator ─────────────────────────────────
days_until_expiry() {
  expiry_date=$1
  today=$(date '+%Y-%m-%d')
  expiry_sec=$(date -d "$expiry_date" '+%s')
  today_sec=$(date -d "$today" '+%s')
  echo $(( (expiry_sec - today_sec) / 86400 ))
}

log "${GREEN}Expiry Watcher starting...${NC}"

total=$(jq '.secrets | length' "$DB")
log "Monitoring $total secret(s)..."

for i in $(seq 0 $((total - 1))); do

  id=$(jq -r ".secrets[$i].id" "$DB")
  expiry=$(jq -r ".secrets[$i].expiry_date" "$DB")
  alert_sent=$(jq -r ".secrets[$i].alert_sent" "$DB")
  status=$(jq -r ".secrets[$i].status" "$DB")

  days=$(days_until_expiry "$expiry")

  # ── already expired ─────────────────────────────
  if [ "$days" -lt 0 ]; then
    log "${RED}EXPIRED: $id expired $((days * -1)) days ago!${NC}"
    bash "$ALERT" "CRITICAL" "$id" "Secret has already expired — rotate immediately"
    jq ".secrets[$i].status = \"expired\"" "$DB" > tmp.json && mv tmp.json "$DB"

  # ── 7 din ya kam baaki ──────────────────────────
  elif [ "$days" -le 7 ]; then
    log "${RED}URGENT: $id expires in $days days!${NC}"
    bash "$ALERT" "CRITICAL" "$id" "Secret expires in $days days — urgent rotation needed"
    jq ".secrets[$i].status = \"expiring_soon\"" "$DB" > tmp.json && mv tmp.json "$DB"
    jq ".secrets[$i].alert_sent = true" "$DB" > tmp.json && mv tmp.json "$DB"

  # ── 15 din ya kam baaki ──────────────────────────
  elif [ "$days" -le 15 ] && [ "$alert_sent" == "false" ]; then
    log "${YELLOW}WARNING: $id expires in $days days${NC}"
    bash "$ALERT" "WARNING" "$id" "Secret expires in $days days — plan rotation soon"
    jq ".secrets[$i].status = \"expiring_soon\"" "$DB" > tmp.json && mv tmp.json "$DB"
    jq ".secrets[$i].alert_sent = true" "$DB" > tmp.json && mv tmp.json "$DB"

  # ── 30 din ya kam baaki ──────────────────────────
  elif [ "$days" -le 30 ] && [ "$alert_sent" == "false" ]; then
    log "${YELLOW}NOTICE: $id expires in $days days${NC}"
    bash "$ALERT" "NOTICE" "$id" "Secret expires in $days days — rotation coming up"

  # ── sab theek hai ───────────────────────────────
  else
    log "${GREEN}OK: $id — $days days remaining${NC}"
  fi

done

log "${GREEN}Expiry Watcher complete.${NC}"
