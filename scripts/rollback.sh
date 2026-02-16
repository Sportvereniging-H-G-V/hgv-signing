#!/usr/bin/env bash
#
# HGV-Signing Rollback Script
#
# Purpose: Manually rollback to the previous release
#
# Usage:   sudo -u hgv-signing bash scripts/rollback.sh
#
# Features:
#   - Identifies previous working release
#   - Prompts for confirmation
#   - Switches symlink to previous release
#   - Restarts application
#   - Verifies rollback with health check
#

set -euo pipefail

# =============================================================================
# RBENV INITIALIZATION
# =============================================================================

# Load rbenv if it exists
if [ -d "/opt/rbenv" ]; then
  export RBENV_ROOT="/opt/rbenv"
  export PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:${PATH}"
  eval "$(rbenv init -)"
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

APP_PATH="/opt/hgv-signing"
APP_USER="hgv-signing"
RELEASES_PATH="${APP_PATH}/releases"
CURRENT_PATH="${APP_PATH}/current"
HEALTH_CHECK_RETRIES=30
HEALTH_CHECK_INTERVAL=2

# =============================================================================
# COLORS FOR OUTPUT
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

# Check if running as app user
if [[ $(whoami) != "${APP_USER}" ]]; then
  error "This script must be run as ${APP_USER}"
  error "Run: sudo -u ${APP_USER} bash scripts/rollback.sh"
  exit 1
fi

# Load environment
if [[ -f "/etc/hgv-signing/hgv-signing.env" ]]; then
  source /etc/hgv-signing/hgv-signing.env
else
  error "Environment file not found: /etc/hgv-signing/hgv-signing.env"
  exit 1
fi

# =============================================================================
# IDENTIFY RELEASES
# =============================================================================

log "========================================================================="
log "HGV-Signing Rollback"
log "========================================================================="
log ""

# Get current release
CURRENT_RELEASE=$(readlink -f "${CURRENT_PATH}" 2>/dev/null || echo "")

if [[ -z "${CURRENT_RELEASE}" ]]; then
  error "No current release found at ${CURRENT_PATH}"
  error "Nothing to rollback from!"
  exit 1
fi

CURRENT_RELEASE_NAME=$(basename "${CURRENT_RELEASE}")

log "Current release: ${CURRENT_RELEASE_NAME}"

# Get all releases sorted by timestamp (newest first)
cd "${RELEASES_PATH}"
RELEASES=($(ls -t))

# Find previous release (first release that is not the current one)
PREVIOUS_RELEASE=""
PREVIOUS_RELEASE_NAME=""

for release in "${RELEASES[@]}"; do
  if [[ "${RELEASES_PATH}/${release}" != "${CURRENT_RELEASE}" ]]; then
    PREVIOUS_RELEASE="${RELEASES_PATH}/${release}"
    PREVIOUS_RELEASE_NAME="${release}"
    break
  fi
done

if [[ -z "${PREVIOUS_RELEASE}" ]]; then
  error "No previous release found!"
  error "Available releases:"
  ls -1t "${RELEASES_PATH}"
  exit 1
fi

# =============================================================================
# DISPLAY ROLLBACK INFORMATION
# =============================================================================

log "Previous release: ${PREVIOUS_RELEASE_NAME}"
log ""

# Show all available releases
log "Available releases (newest first):"
RELEASE_NUM=1
for release in "${RELEASES[@]}"; do
  if [[ "${RELEASES_PATH}/${release}" == "${CURRENT_RELEASE}" ]]; then
    echo "  ${RELEASE_NUM}. ${release} (current)"
  elif [[ "${RELEASES_PATH}/${release}" == "${PREVIOUS_RELEASE}" ]]; then
    echo "  ${RELEASE_NUM}. ${release} <- will rollback to this"
  else
    echo "  ${RELEASE_NUM}. ${release}"
  fi
  RELEASE_NUM=$((RELEASE_NUM + 1))
done

log ""
warn "========================================================================="
warn "IMPORTANT: Database migrations will NOT be automatically rolled back!"
warn "========================================================================="
warn ""
warn "If the current release includes new database migrations, you may need to:"
warn "  1. Manually rollback the database migrations, or"
warn "  2. Restore the database from a backup"
warn ""
warn "Database backups are located in:"
warn "  ${APP_PATH}/shared/backups/"
warn ""
warn "========================================================================="
warn ""

# =============================================================================
# CONFIRMATION
# =============================================================================

echo -n "Do you want to rollback from '${CURRENT_RELEASE_NAME}' to '${PREVIOUS_RELEASE_NAME}'? (yes/no): "
read CONFIRM

if [[ "${CONFIRM}" != "yes" ]]; then
  log "Rollback cancelled by user"
  exit 0
fi

log ""
log "Starting rollback process..."

# =============================================================================
# SWITCH SYMLINK
# =============================================================================

log "Switching symlink to previous release..."

# Atomic symlink switch
ln -sfn "${PREVIOUS_RELEASE}" "${CURRENT_PATH}.tmp"
mv -Tf "${CURRENT_PATH}.tmp" "${CURRENT_PATH}"

info "✓ Symlink switched: ${CURRENT_PATH} -> ${PREVIOUS_RELEASE}"

# =============================================================================
# RESTART APPLICATION
# =============================================================================

log "Restarting application..."

sudo systemctl restart hgv-signing.service

# Give it time to start
sleep 3

info "✓ Application restarted"

# =============================================================================
# HEALTH CHECK
# =============================================================================

log "Performing health check..."

HEALTH_URL="http://localhost:${PORT:-3000}/up"
HEALTH_SUCCESS=false

log "Checking health endpoint: ${HEALTH_URL}"

for i in $(seq 1 ${HEALTH_CHECK_RETRIES}); do
  sleep ${HEALTH_CHECK_INTERVAL}

  # Check if service is running
  if ! systemctl is-active --quiet hgv-signing.service; then
    error "Service stopped unexpectedly!"
    break
  fi

  # Check health endpoint
  if curl -sf "${HEALTH_URL}" >/dev/null 2>&1; then
    log "✓ Health check passed (attempt ${i}/${HEALTH_CHECK_RETRIES})"
    HEALTH_SUCCESS=true
    break
  else
    if [[ $i -eq ${HEALTH_CHECK_RETRIES} ]]; then
      warn "Health check failed (attempt ${i}/${HEALTH_CHECK_RETRIES})"
    else
      info "Health check pending (attempt ${i}/${HEALTH_CHECK_RETRIES})..."
    fi
  fi
done

# =============================================================================
# ROLLBACK RESULT
# =============================================================================

log ""

if [[ "${HEALTH_SUCCESS}" == "true" ]]; then
  log "========================================================================="
  log "ROLLBACK COMPLETED SUCCESSFULLY!"
  log "========================================================================="
  log ""
  log "Current release: ${PREVIOUS_RELEASE_NAME}"
  log "Previous release: ${CURRENT_RELEASE_NAME} (now inactive)"
  log ""
  log "Application status:"
  sudo systemctl status hgv-signing.service --no-pager || true
  log ""
  log "The failed release (${CURRENT_RELEASE_NAME}) is still available in:"
  log "  ${CURRENT_RELEASE}"
  log ""
  log "You can remove it manually once you've confirmed the rollback:"
  log "  rm -rf ${CURRENT_RELEASE}"
  log ""
  log "========================================================================="
else
  error "========================================================================="
  error "ROLLBACK HEALTH CHECK FAILED"
  error "========================================================================="
  error ""
  error "The rollback completed but the health check failed."
  error "This may indicate a deeper issue with the application or database."
  error ""
  error "Current release: ${PREVIOUS_RELEASE_NAME}"
  error ""
  error "Check logs with:"
  error "  sudo journalctl -u hgv-signing.service -f"
  error ""
  error "Recent logs:"
  sudo journalctl -u hgv-signing.service -n 30 --no-pager || true
  error ""
  error "========================================================================="

  exit 1
fi

# =============================================================================
# DATABASE MIGRATION WARNING
# =============================================================================

log ""
warn "========================================================================="
warn "POST-ROLLBACK CHECKLIST"
warn "========================================================================="
warn ""
warn "✓ Symlink switched to previous release"
warn "✓ Application restarted"
warn "✓ Health check passed"
warn ""
warn "⚠ REMINDER: Check if database migrations need to be rolled back!"
warn ""
warn "To check for new migrations in the failed release:"
warn "  cd ${CURRENT_RELEASE}"
warn "  bundle exec rake db:migrate:status"
warn ""
warn "To rollback database migrations (if needed):"
warn "  cd ${CURRENT_PATH}"
warn "  bundle exec rake db:rollback STEP=N"
warn ""
warn "Or restore from backup:"
warn "  Find backup: ls -lt ${APP_PATH}/shared/backups/"
warn "  Restore: pg_restore -h 127.0.0.1 -U hgv_signing -d hgv_signing_production backup.dump"
warn ""
warn "========================================================================="
