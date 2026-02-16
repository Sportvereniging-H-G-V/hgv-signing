#!/usr/bin/env bash
#
# Quick Fix: Add sudoers configuration for deployment
#
# Purpose: This script fixes the missing sudoers configuration that prevents
#          the deployment pipeline from working. Run this on your server if
#          you already ran prepare_server.sh before this fix was added.
#
# Usage:   sudo bash scripts/fix_sudoers.sh
#

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

APP_USER="hgv-signing"

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root (use sudo)"
  exit 1
fi

echo "[INFO] Fixing sudoers configuration for HGV-Signing deployment..."
echo ""

# =============================================================================
# DETECT SSH/DEPLOYMENT USER
# =============================================================================

echo "Which user does GitLab CI use to SSH into this server?"
echo "This is the SSH_USER variable in your GitLab CI configuration."
echo ""
read -p "Enter SSH username (e.g., deploy, gitlab-runner, etc.): " DEPLOY_USER

if [[ -z "${DEPLOY_USER}" ]]; then
  echo "[ERROR] No username provided"
  exit 1
fi

# Check if user exists
if ! id -u "${DEPLOY_USER}" > /dev/null 2>&1; then
  echo "[WARNING] User '${DEPLOY_USER}' does not exist on this system"
  read -p "Do you want to continue anyway? (y/n): " confirm
  if [[ "${confirm}" != "y" ]]; then
    echo "Aborted"
    exit 1
  fi
fi

# =============================================================================
# CREATE SUDOERS CONFIGURATION
# =============================================================================

echo "[INFO] Creating sudoers configuration..."

# Create or update sudoers file
cat > /etc/sudoers.d/hgv-signing << EOF
# Allow hgv-signing user to manage the application service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl start hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl stop hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl restart hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl reload hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl status hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl daemon-reload
${APP_USER} ALL=(ALL) NOPASSWD: /bin/journalctl -u hgv-signing.service *

# Allow hgv-signing to update the service file
${APP_USER} ALL=(ALL) NOPASSWD: /bin/cp */deploy/hgv-signing.service /etc/systemd/system/hgv-signing.service

# Allow deployment user (from GitLab CI) to run deployment as hgv-signing user
${DEPLOY_USER} ALL=(${APP_USER}) NOPASSWD: ALL
EOF

chmod 440 /etc/sudoers.d/hgv-signing

# =============================================================================
# VERIFY CONFIGURATION
# =============================================================================

echo "[INFO] Verifying sudoers syntax..."

if visudo -c -f /etc/sudoers.d/hgv-signing; then
  echo "[SUCCESS] ✓ Sudoers configuration created successfully"
else
  echo "[ERROR] Sudoers syntax error! Removing invalid file..."
  rm -f /etc/sudoers.d/hgv-signing
  exit 1
fi

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "========================================================================"
echo "SUDOERS CONFIGURATION FIXED!"
echo "========================================================================"
echo ""
echo "Configuration:"
echo "  Sudoers file:    /etc/sudoers.d/hgv-signing"
echo "  App user:        ${APP_USER}"
echo "  Deployment user: ${DEPLOY_USER}"
echo ""
echo "Permissions granted:"
echo "  - ${APP_USER} can manage systemd service (start, stop, restart, reload)"
echo "  - ${DEPLOY_USER} can run deployment scripts as ${APP_USER}"
echo ""
echo "Your GitLab CI deployment pipeline should now work!"
echo "Try pushing a new tag to trigger a deployment."
echo ""
echo "========================================================================"
