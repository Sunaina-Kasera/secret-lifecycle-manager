#!/bin/bash

LEVEL=$1
SECRET_ID=$2
MESSAGE=$3

WEBHOOK_URL="${SLACK_WEBHOOK_URL}"

LOG="logs/brain.log"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
  echo -e "$1"
}

case "$LEVEL" in
  "CRITICAL") EMOJI=":rotating_light:" ; COLOR="#FF0000" ;;
  "WARNING")  EMOJI=":warning:"        ; COLOR="#FFA500" ;;
  "NOTICE")   EMOJI=":information_source:" ; COLOR="#0000FF" ;;
  "SUCCESS")  EMOJI=":white_check_mark:" ; COLOR="#00FF00" ;;
  "ERROR")    EMOJI=":x:"              ; COLOR="#FF0000" ;;
  *)          EMOJI=":bell:"           ; COLOR="#808080" ;;
esac

PAYLOAD=$(cat <<JSON
{
  "attachments": [
    {
      "color": "$COLOR",
      "blocks": [
        {
          "type": "header",
          "text": {
            "type": "plain_text",
            "text": "$EMOJI Secret Lifecycle Manager Alert"
          }
        },
        {
          "type": "section",
          "fields": [
            {"type": "mrkdwn", "text": "*Level:*\n$LEVEL"},
            {"type": "mrkdwn", "text": "*Secret ID:*\n$SECRET_ID"}
          ]
        },
        {
          "type": "section",
          "text": {"type": "mrkdwn", "text": "*Message:*\n$MESSAGE"}
        },
        {
          "type": "context",
          "elements": [
            {"type": "mrkdwn", "text": "Time: $(date '+%Y-%m-%d %H:%M:%S')"}
          ]
        }
      ]
    }
  ]
}
JSON
)

log "Sending $LEVEL alert to Slack for: $SECRET_ID"

response=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H 'Content-type: application/json' \
  --data "$PAYLOAD" \
  "$WEBHOOK_URL")

if [ "$response" == "200" ]; then
  log "${GREEN}Slack alert sent successfully!${NC}"
else
  log "${RED}Slack alert failed — HTTP response: $response${NC}"
fi
