#!/usr/bin/env bash
#
# HGV-Signing Deployment Script
#
# Purpose: Deploy new releases using Capistrano-style directory structure
#          with atomic symlink switching and automatic rollback on failure
#
# Usage:   sudo -u hgv-signing bash scripts/deploy.sh
#
# Features:
#   - Timestamped release directories
#   - Atomic symlink switching (zero-downtime)
#   - Health check with automatic rollback
#   - Database backup before migrations
#   - Asset precompilation
#   - Cleanup of old releases (keep 5)
#

set -euo pipefail

# =============================================================================
# RBENV INITIALIZATION
# =============================================================================

# Load rbenv if it exists
if [ -d "/opt/rbenv" ]; then
  export RBENV_ROOT="/opt/rbenv"
  export PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:${PATH}"
  # Skip rehash during init to avoid permission issues
  eval "$(rbenv init - --no-rehash)"
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

APP_PATH="/opt/hgv-signing"
APP_USER="hgv-signing"
RELEASES_PATH="${APP_PATH}/releases"
SHARED_PATH="${APP_PATH}/shared"
CURRENT_PATH="${APP_PATH}/current"
KEEP_RELEASES=5
DEPLOY_TIMEOUT=600
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
  error "Run: sudo -u ${APP_USER} bash scripts/deploy.sh"
  exit 1
fi

# Check if app path exists
if [[ ! -d "${APP_PATH}" ]]; then
  error "Application path ${APP_PATH} does not exist"
  error "Please run scripts/prepare_server.sh first"
  exit 1
fi

# Load environment (set -a exports all variables automatically)
if [[ -f "/etc/hgv-signing/hgv-signing.env" ]]; then
  set -a
  source /etc/hgv-signing/hgv-signing.env
  set +a
else
  error "Environment file not found: /etc/hgv-signing/hgv-signing.env"
  error "Please run scripts/prepare_server.sh first"
  exit 1
fi

# Verify rbenv is available (already loaded at top of script)
if ! command -v rbenv &> /dev/null; then
  error "rbenv not found. Please run scripts/prepare_server.sh first"
  exit 1
fi

# =============================================================================
# DEPLOYMENT START
# =============================================================================

RELEASE_VERSION="${CI_COMMIT_TAG:-$(date +%Y%m%d%H%M%S)}"
RELEASE_PATH="${RELEASES_PATH}/${RELEASE_VERSION}"

log "========================================================================="
log "Starting HGV-Signing Deployment"
log "========================================================================="
log "Release:     ${RELEASE_VERSION}"
log "Release path: ${RELEASE_PATH}"
log "Environment: ${RAILS_ENV}"
log ""

# =============================================================================
# PHASE 1: CREATE RELEASE DIRECTORY
# =============================================================================

log "Phase 1: Creating release directory..."
mkdir -p "${RELEASE_PATH}"
info "✓ Release directory created: ${RELEASE_PATH}"

# =============================================================================
# PHASE 2: OBTAIN CODE
# =============================================================================

log "Phase 2: Obtaining application code..."

if [[ -n "${CI_PROJECT_DIR:-}" && -d "${CI_PROJECT_DIR}" ]]; then
  # GitLab CI environment - code is already available
  log "Copying code from CI workspace: ${CI_PROJECT_DIR}"

  rsync -a --exclude='.git' \
           --exclude='node_modules' \
           --exclude='tmp' \
           --exclude='log' \
           --exclude='coverage' \
           --exclude='vendor/bundle' \
           "${CI_PROJECT_DIR}/" "${RELEASE_PATH}/"

  info "✓ Code copied from CI workspace"

elif [[ -d "${CURRENT_PATH}/.git" ]]; then
  # Git repository exists in current deployment
  log "Pulling latest code from git repository..."

  cd "${CURRENT_PATH}"
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")

  git fetch origin
  git reset --hard origin/${CURRENT_BRANCH}

  rsync -a --exclude='.git' \
           --exclude='node_modules' \
           --exclude='tmp' \
           --exclude='log' \
           --exclude='coverage' \
           --exclude='vendor/bundle' \
           "${CURRENT_PATH}/" "${RELEASE_PATH}/"

  info "✓ Code pulled from git (branch: ${CURRENT_BRANCH})"

else
  error "No code source found!"
  error "Expected:"
  error "  - CI_PROJECT_DIR environment variable (GitLab CI), or"
  error "  - Git repository in ${CURRENT_PATH}/.git"
  exit 1
fi

cd "${RELEASE_PATH}"

# =============================================================================
# PHASE 3: CREATE SYMLINKS TO SHARED DIRECTORIES
# =============================================================================

log "Phase 3: Creating symlinks to shared directories..."

# Remove existing directories if they exist
rm -rf "${RELEASE_PATH}/log"
rm -rf "${RELEASE_PATH}/tmp"
rm -rf "${RELEASE_PATH}/storage"

# Create symlinks
ln -sfn "${SHARED_PATH}/log" "${RELEASE_PATH}/log"
ln -sfn "${SHARED_PATH}/tmp" "${RELEASE_PATH}/tmp"
ln -sfn "${SHARED_PATH}/storage" "${RELEASE_PATH}/storage"

# Create public/fonts symlink for custom fonts
mkdir -p "${RELEASE_PATH}/public"
ln -sfn "${SHARED_PATH}/fonts" "${RELEASE_PATH}/public/fonts"

# Create fonts symlink in root (for compatibility)
ln -sfn "${SHARED_PATH}/fonts" "${RELEASE_PATH}/fonts"

info "✓ Symlinks created"

# =============================================================================
# PHASE 4: INSTALL RUBY DEPENDENCIES
# =============================================================================

log "Phase 4: Installing Ruby dependencies..."

export BUNDLE_WITHOUT="development:test"
export BUNDLE_DEPLOYMENT="true"
export BUNDLE_PATH="${RELEASE_PATH}/vendor/bundle"

bundle install --jobs 4 --retry 3 --quiet

info "✓ Ruby dependencies installed"

# =============================================================================
# PHASE 5: INSTALL NODE DEPENDENCIES
# =============================================================================

log "Phase 5: Installing Node.js dependencies..."

yarn install --frozen-lockfile --production=false

info "✓ Node.js dependencies installed"

# =============================================================================
# PHASE 6: PRECOMPILE ASSETS
# =============================================================================

log "Phase 6: Precompiling assets..."

export NODE_ENV=production
export RAILS_ENV=production

# Clear any existing precompiled assets
rm -rf public/packs || true
rm -rf public/assets || true

bundle exec rake assets:precompile

info "✓ Assets precompiled"

# =============================================================================
# PHASE 7: STOP APPLICATION BEFORE MIGRATION
# =============================================================================

log "Phase 7: Stopping application before database migration..."

# Stop the app to prevent concurrent migration locks
# The app's migrate.rb initializer auto-runs migrations on startup,
# which conflicts with our deploy script migrations
if systemctl is-active --quiet hgv-signing.service; then
  sudo systemctl stop hgv-signing.service
  info "✓ Application stopped"

  # Wait for connections to close
  sleep 2
else
  info "Application was not running"
fi

# =============================================================================
# PHASE 8: DATABASE BACKUP BEFORE MIGRATION
# =============================================================================

log "Phase 8: Backing up database before migration..."

MIGRATION_BACKUP="${SHARED_PATH}/backups/pre_migration_${RELEASE_VERSION}.dump"
mkdir -p "${SHARED_PATH}/backups"

export PGPASSWORD="${DATABASE_PASSWORD}"

if pg_dump -h ${DATABASE_HOST} \
           -p ${DATABASE_PORT} \
           -U ${DATABASE_USER} \
           -Fc \
           -f "${MIGRATION_BACKUP}" \
           ${DATABASE_NAME}; then
  info "✓ Database backed up: ${MIGRATION_BACKUP}"
else
  error "Database backup failed!"
  # Start app again before exiting
  sudo systemctl start hgv-signing.service || true
  exit 1
fi

# =============================================================================
# PHASE 9: RUN DATABASE MIGRATIONS
# =============================================================================

log "Phase 9: Running database migrations..."

# Disable auto-migrations in the app during this run
export RUN_MIGRATIONS=false

if ! bundle exec rake db:migrate; then
  error "Database migration failed!"
  error "Database backup available at: ${MIGRATION_BACKUP}"
  error "Rolling back deployment..."
  rm -rf "${RELEASE_PATH}"
  # Start app again with previous release
  sudo systemctl start hgv-signing.service || true
  exit 1
fi

info "✓ Database migrations completed"

# =============================================================================
# PHASE 10: PRECOMPILE BOOTSNAP CACHE
# =============================================================================

log "Phase 10: Precompiling bootsnap cache..."

bundle exec bootsnap precompile --gemfile app/ lib/ || true

info "✓ Bootsnap cache precompiled"

# =============================================================================
# PHASE 11: ATOMIC SYMLINK SWITCH
# =============================================================================

log "Phase 11: Switching current symlink to new release..."

# Get previous release for potential rollback
PREVIOUS_RELEASE=$(readlink -f "${CURRENT_PATH}" 2>/dev/null || echo "")

if [[ -n "${PREVIOUS_RELEASE}" ]]; then
  info "Previous release: $(basename ${PREVIOUS_RELEASE})"
else
  info "No previous release (first deployment)"
fi

# Atomic symlink switch
ln -sfn "${RELEASE_PATH}" "${CURRENT_PATH}.tmp"
mv -Tf "${CURRENT_PATH}.tmp" "${CURRENT_PATH}"

info "✓ Symlink switched: ${CURRENT_PATH} -> ${RELEASE_PATH}"

# =============================================================================
# PHASE 12: UPDATE SYSTEMD SERVICE FILE
# =============================================================================

log "Phase 12: Updating systemd service file..."

if [[ -f "${RELEASE_PATH}/deploy/hgv-signing.service" ]]; then
  sudo cp "${RELEASE_PATH}/deploy/hgv-signing.service" /etc/systemd/system/hgv-signing.service
  sudo systemctl daemon-reload
  info "✓ Systemd service file updated"
else
  warn "Service file not found in release, using existing"
fi

# =============================================================================
# PHASE 13: START APPLICATION
# =============================================================================

log "Phase 13: Starting application..."

# App was stopped in Phase 7 for migrations, now start it fresh
sudo systemctl start hgv-signing.service

info "✓ Application started"

# =============================================================================
# PHASE 14: HEALTH CHECK
# =============================================================================

log "Phase 14: Performing health check..."

HEALTH_URL="http://localhost:${PORT:-3000}/up"
HEALTH_SUCCESS=false

log "Checking health endpoint: ${HEALTH_URL}"
log "Retries: ${HEALTH_CHECK_RETRIES} × ${HEALTH_CHECK_INTERVAL}s = $((HEALTH_CHECK_RETRIES * HEALTH_CHECK_INTERVAL))s timeout"

for i in $(seq 1 ${HEALTH_CHECK_RETRIES}); do
  sleep ${HEALTH_CHECK_INTERVAL}

  # Check if service is still running
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
      warn "Health check failed (attempt ${i}/${HEALTH_CHECK_RETRIES}) - FINAL ATTEMPT"
    else
      info "Health check pending (attempt ${i}/${HEALTH_CHECK_RETRIES})..."
    fi
  fi
done

# =============================================================================
# PHASE 15: ROLLBACK ON FAILURE
# =============================================================================

if [[ "${HEALTH_SUCCESS}" != "true" ]]; then
  error "========================================================================="
  error "HEALTH CHECK FAILED - INITIATING ROLLBACK"
  error "========================================================================="

  # Show recent logs for debugging
  error ""
  error "Recent application logs:"
  sudo journalctl -u hgv-signing.service -n 20 --no-pager || true

  if [[ -n "${PREVIOUS_RELEASE}" && -d "${PREVIOUS_RELEASE}" ]]; then
    error ""
    error "Rolling back to previous release: $(basename ${PREVIOUS_RELEASE})"

    # Switch symlink back
    ln -sfn "${PREVIOUS_RELEASE}" "${CURRENT_PATH}.tmp"
    mv -Tf "${CURRENT_PATH}.tmp" "${CURRENT_PATH}"

    # Restart with previous release
    error "Restarting application with previous release..."
    sudo systemctl restart hgv-signing.service

    # Give it time to start
    sleep 5

    # Verify rollback worked
    if curl -sf "${HEALTH_URL}" >/dev/null 2>&1; then
      error "✓ Rollback successful - application running on previous release"
    else
      error "✗ Rollback failed - manual intervention required!"
    fi

    error ""
    error "Cleaning up failed release: ${RELEASE_PATH}"
    rm -rf "${RELEASE_PATH}"
  else
    error "No previous release available for rollback!"
    error "Manual intervention required!"
  fi

  error ""
  error "Deployment failed. Check logs with:"
  error "  sudo journalctl -u hgv-signing.service -f"
  error ""
  error "Database backup available at:"
  error "  ${MIGRATION_BACKUP}"
  error ""

  exit 1
fi

# =============================================================================
# PHASE 16: CLEANUP OLD RELEASES
# =============================================================================

log "Phase 16: Cleaning up old releases..."

cd "${RELEASES_PATH}"

# Get list of releases sorted by timestamp (newest first)
RELEASES=($(ls -t))

# Count releases
RELEASE_COUNT=${#RELEASES[@]}

if [[ ${RELEASE_COUNT} -gt ${KEEP_RELEASES} ]]; then
  log "Found ${RELEASE_COUNT} releases, keeping ${KEEP_RELEASES}..."

  # Remove old releases (keep the most recent KEEP_RELEASES)
  for (( i=${KEEP_RELEASES}; i<${RELEASE_COUNT}; i++ )); do
    OLD_RELEASE="${RELEASES_PATH}/${RELEASES[$i]}"

    # Don't remove if it's the current release (safety check)
    if [[ "$(readlink -f ${CURRENT_PATH})" != "${OLD_RELEASE}" ]]; then
      log "Removing old release: ${RELEASES[$i]}"
      rm -rf "${OLD_RELEASE}"
    fi
  done

  info "✓ Old releases cleaned up"
else
  info "Only ${RELEASE_COUNT} releases, keeping all"
fi

# =============================================================================
# DEPLOYMENT SUCCESS
# =============================================================================

log ""
log "========================================================================="
log "DEPLOYMENT COMPLETED SUCCESSFULLY!"
log "========================================================================="
log ""
log "Release:          ${RELEASE_VERSION}"
log "Current symlink:  ${CURRENT_PATH} -> ${RELEASE_PATH}"
if [[ -n "${PREVIOUS_RELEASE}" ]]; then
  log "Previous release: $(basename ${PREVIOUS_RELEASE})"
fi
log "Releases kept:    ${KEEP_RELEASES}"
log ""
log "Application status:"
sudo systemctl status hgv-signing.service --no-pager || true
log ""
log "Application URL:"
log "  http://localhost:${PORT:-3000}"
if [[ -n "${HOST:-}" ]]; then
  log "  https://${HOST}"
fi
log ""
log "Useful commands:"
log "  View logs:    sudo journalctl -u hgv-signing.service -f"
log "  Check status: sudo systemctl status hgv-signing.service"
log "  Restart:      sudo systemctl restart hgv-signing.service"
log "  Rollback:     cd ${APP_PATH} && bash scripts/rollback.sh"
log ""
log "========================================================================="
