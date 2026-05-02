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

log "${GREEN}Auto Rotator starting...${NC}"

total=$(jq '.secrets | length' "$DB")

for i in $(seq 0 $((total - 1))); do

  id=$(jq -r ".secrets[$i].id" "$DB")
  type=$(jq -r ".secrets[$i].type" "$DB")
  status=$(jq -r ".secrets[$i].status" "$DB")

  # ── sirf compromised ya expiring_soon ko rotate karo
  if [ "$status" == "compromised" ] || [ "$status" == "expiring_soon" ] || [ "$status" == "expired" ]; then

    log "${YELLOW}Rotating: $id (type: $type, status: $status)${NC}"

    if [ "$type" == "aws_access_key" ]; then

      # ── Step 1: current IAM user pata karo ─────────
      IAM_USER=$(aws iam get-user --query 'User.UserName' --output text 2>/dev/null)

      if [ -z "$IAM_USER" ]; then
        log "${RED}ERROR: AWS CLI not configured properly${NC}"
        bash "$ALERT" "ERROR" "$id" "Auto rotation failed — AWS CLI not configured"
        continue
      fi

      log "IAM User found: $IAM_USER"

      # ── Step 2: naya key banao ──────────────────────
      log "Creating new AWS access key..."
      NEW_KEY=$(aws iam create-access-key --user-name "$IAM_USER" 2>/dev/null)

      if [ -z "$NEW_KEY" ]; then
        log "${RED}ERROR: Could not create new key${NC}"
        bash "$ALERT" "ERROR" "$id" "Auto rotation failed — could not create new AWS key"
        continue
      fi

      NEW_ACCESS_KEY=$(echo "$NEW_KEY" | jq -r '.AccessKey.AccessKeyId')
      NEW_SECRET_KEY=$(echo "$NEW_KEY" | jq -r '.AccessKey.SecretAccessKey')

      log "${GREEN}New key created: $NEW_ACCESS_KEY${NC}"

      # ── Step 3: SSM Parameter Store mein save karo ─
      log "Saving new key to SSM Parameter Store..."
      aws ssm put-parameter \
        --name "/secret-lifecycle-manager/aws-access-key-id" \
        --value "$NEW_ACCESS_KEY" \
        --type "SecureString" \
        --overwrite 2>/dev/null

      aws ssm put-parameter \
        --name "/secret-lifecycle-manager/aws-secret-access-key" \
        --value "$NEW_SECRET_KEY" \
        --type "SecureString" \
        --overwrite 2>/dev/null

      log "${GREEN}New key saved to SSM Parameter Store${NC}"

      # ── Step 4: DB update karo ──────────────────────
      today=$(date '+%Y-%m-%d')
      new_expiry=$(date -d "+90 days" '+%Y-%m-%d')

      jq ".secrets[$i].status = \"active\"" "$DB" > tmp.json && mv tmp.json "$DB"
      jq ".secrets[$i].alert_sent = false" "$DB" > tmp.json && mv tmp.json "$DB"
      jq ".secrets[$i].last_rotated = \"$today\"" "$DB" > tmp.json && mv tmp.json "$DB"
      jq ".secrets[$i].expiry_date = \"$new_expiry\"" "$DB" > tmp.json && mv tmp.json "$DB"

      log "${GREEN}DB updated — new expiry: $new_expiry${NC}"

      # ── Step 5: alert bhejo ─────────────────────────
      bash "$ALERT" "SUCCESS" "$id" "Key successfully rotated — new expiry: $new_expiry"

      log "${GREEN}Rotation complete for: $id${NC}"

    else
      log "${YELLOW}Rotation for type '$type' not yet supported${NC}"
    fi

  else
    log "${GREEN}SKIP: $id — status is $status, no rotation needed${NC}"
  fi

done

log "${GREEN}Auto Rotator complete.${NC}"
