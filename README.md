# Secret Lifecycle Manager

A fully automated DevOps security tool that monitors, detects, and rotates AWS secrets — without any manual intervention.

## The Problem

Companies lose millions every year due to:
- **Leaked credentials** accidentally pushed to Git repositories
- **Expired secrets** that no one rotated on time
- **Inconsistent updates** — secret rotated in one place but forgotten in another

This tool solves all three problems with a single automated system.

## How It Works

Central Brain tracks all secrets in secrets.db.json
Git Scanner scans every commit for leaked credentials
Expiry Watcher monitors expiry dates and sends early warnings
Auto Rotator rotates AWS IAM keys automatically
Alert Engine sends real-time Slack notifications

## Architecture

Central Brain (secrets.db.json)
       |
  _____|_____________________
  |          |              |
Git Scanner  Expiry Watcher  Auto Rotator
                |
          Alert Engine (Slack)

## Modules

### Central Brain
Tracks every secret in secrets.db.json, makes decisions based on status and expiry, and coordinates all other modules.

### Git Scanner
Scans every Git commit for leaked secrets. Detects AWS keys, API tokens, passwords, and private keys. Immediately marks secret as compromised and triggers rotation.

### Expiry Watcher
Monitors expiry dates of all secrets. Sends alerts at 30, 15, and 7 day intervals. Escalates to CRITICAL when secret has already expired.

### Auto Rotator
Automatically creates new AWS IAM access keys. Stores new keys securely in AWS SSM Parameter Store. Updates secrets.db.json with new expiry date.

### Alert Engine
Sends formatted Slack notifications for all events. Color coded alerts — RED for critical, YELLOW for warning, GREEN for success. Logs all events to logs/brain.log.

## Tech Stack

- Bash / Shell — Core scripting
- AWS CLI — IAM key rotation
- AWS IAM — Access key management
- AWS SSM Parameter Store — Secure secret storage
- GitHub Actions — Daily automation
- Slack Webhook — Real-time alerts
- jq — JSON processing
- Git — Commit scanning

## Project Structure

secret-lifecycle-manager/
├── modules/
│   ├── brain.sh
│   ├── git_scanner.sh
│   ├── expiry_watcher.sh
│   ├── auto_rotator.sh
│   └── alert_engine.sh
├── config/
│   └── secrets.db.json
├── logs/
│   └── brain.log
└── .github/
    └── workflows/
        └── secret-monitor.yml

## Setup

### Prerequisites
- Linux or WSL2
- AWS CLI configured
- GitHub account
- Slack workspace with Incoming Webhook

### Installation

git clone https://github.com/Sunaina-Kasera/secret-lifecycle-manager.git
cd secret-lifecycle-manager
chmod +x modules/*.sh

### Configure GitHub Secrets

Add these three secrets in GitHub repository settings:

AWS_ACCESS_KEY_ID — Your AWS IAM access key
AWS_SECRET_ACCESS_KEY — Your AWS IAM secret key
SLACK_WEBHOOK_URL — Your Slack incoming webhook URL

### Run Manually

export SLACK_WEBHOOK_URL="your-webhook-url"
bash modules/brain.sh
bash modules/git_scanner.sh
bash modules/expiry_watcher.sh
bash modules/auto_rotator.sh

## Automation

GitHub Actions runs this tool every day at 9:00 AM IST automatically. You can also trigger it manually from the Actions tab anytime.

## Real World Impact

- Prevents credential leaks before they reach GitHub
- Eliminates human error in secret rotation
- Provides audit trail via logs
- Zero cost — uses only AWS Free Tier services

## Author

Sunaina Kasera
DevOps Enthusiast
GitHub: https://github.com/Sunaina-Kasera
LinkedIn: https://linkedin.com/in/sunaina-kasera
