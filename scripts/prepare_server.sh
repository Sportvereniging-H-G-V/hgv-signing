#!/usr/bin/env bash
#
# HGV-Signing Server Preparation Script
#
# Purpose: First-time server setup for bare-metal deployment on Ubuntu 22.04 LTS
# Usage:   sudo bash scripts/prepare_server.sh
#
# This script installs all dependencies, creates the application user and directory
# structure, configures PostgreSQL, downloads native libraries (PDFium, ONNX Runtime),
# sets up systemd service, log rotation, and automated backups.
#

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

APP_USER="hgv-signing"
APP_PATH="/opt/hgv-signing"
RUBY_VERSION="3.4.2"
NODE_VERSION="20"
POSTGRES_VERSION="15"
ONNX_VERSION="1.16.3"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

warn() {
  echo "[WARNING] $*"
}

info() {
  echo "[INFO] $*"
}

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

# Check if running as root
[[ $EUID -ne 0 ]] && error "This script must be run as root (use sudo)"

# Check if Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
  log "Warning: This script is designed for Ubuntu 22.04 LTS. Other distributions may require modifications."
fi

log "Starting HGV-Signing server preparation..."
log "Target configuration:"
log "  App user:    ${APP_USER}"
log "  App path:    ${APP_PATH}"
log "  Ruby:        ${RUBY_VERSION}"
log "  Node.js:     ${NODE_VERSION}"
log "  PostgreSQL:  ${POSTGRES_VERSION}"
echo ""

# =============================================================================
# PHASE 1: SYSTEM PACKAGE UPDATES
# =============================================================================

log "Phase 1: Updating system packages..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# =============================================================================
# PHASE 2: BUILD DEPENDENCIES AND SYSTEM LIBRARIES
# =============================================================================

log "Phase 2: Installing build dependencies and system libraries..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  build-essential \
  libssl-dev \
  libreadline-dev \
  zlib1g-dev \
  libpq-dev \
  libvips-dev \
  libvips42 \
  libvips-tools \
  libyaml-dev \
  libffi-dev \
  libgdbm-dev \
  libncurses5-dev \
  automake \
  libtool \
  bison \
  pkg-config \
  curl \
  wget \
  git \
  gnupg2 \
  ca-certificates \
  apt-transport-https \
  software-properties-common \
  libheif-dev \
  imagemagick \
  libmagickwand-dev \
  fonts-freefont-ttf \
  fontforge \
  python3-fontforge

log "✓ Build dependencies installed"

# =============================================================================
# PHASE 3: RUBY INSTALLATION (rbenv)
# =============================================================================

log "Phase 3: Installing Ruby ${RUBY_VERSION} via rbenv..."

# Install rbenv if not present
if [ ! -d "/opt/rbenv" ]; then
  log "Installing rbenv..."
  git clone https://github.com/rbenv/rbenv.git /opt/rbenv
  git clone https://github.com/rbenv/ruby-build.git /opt/rbenv/plugins/ruby-build

  # Build rbenv dynamic bash extension for speed
  cd /opt/rbenv
  src/configure && make -C src || log "Warning: rbenv dynamic bash extension build failed, will use shell version"

  # Configure rbenv system-wide
  cat > /etc/profile.d/rbenv.sh << 'EOF'
export PATH="/opt/rbenv/bin:$PATH"
eval "$(rbenv init -)"
EOF

  log "✓ rbenv installed"
else
  log "rbenv already installed"
fi

# Always load rbenv in current shell
export RBENV_ROOT="/opt/rbenv"
export PATH="/opt/rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Verify ruby-build plugin is available
if [ ! -d "/opt/rbenv/plugins/ruby-build" ]; then
  log "Installing ruby-build plugin..."
  git clone https://github.com/rbenv/ruby-build.git /opt/rbenv/plugins/ruby-build
fi

# Check if Ruby version is already installed
if rbenv versions 2>/dev/null | grep -q "${RUBY_VERSION}"; then
  log "Ruby ${RUBY_VERSION} already installed"
  rbenv global ${RUBY_VERSION}
else
  log "Installing Ruby ${RUBY_VERSION}... (this may take several minutes)"
  rbenv install ${RUBY_VERSION}
  rbenv global ${RUBY_VERSION}

  log "Installing bundler..."
  gem install bundler --no-document

  log "✓ Ruby ${RUBY_VERSION} installed"
fi

# Verify Ruby installation
if ! rbenv exec ruby --version | grep -q "${RUBY_VERSION}"; then
  error "Ruby ${RUBY_VERSION} installation verification failed"
fi

# =============================================================================
# PHASE 4: NODE.JS AND YARN INSTALLATION
# =============================================================================

log "Phase 4: Installing Node.js ${NODE_VERSION} and Yarn..."

if ! command -v node &> /dev/null || ! node --version | grep -q "v${NODE_VERSION}"; then
  log "Installing Node.js ${NODE_VERSION}..."
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
  log "✓ Node.js installed"
else
  log "Node.js ${NODE_VERSION} already installed"
fi

if ! command -v yarn &> /dev/null; then
  log "Installing Yarn..."
  npm install -g yarn
  log "✓ Yarn installed"
else
  log "Yarn already installed"
fi

# Verify Node.js and Yarn
node --version
yarn --version

# =============================================================================
# PHASE 5: POSTGRESQL INSTALLATION
# =============================================================================

log "Phase 5: Installing PostgreSQL ${POSTGRES_VERSION}..."

if ! command -v psql &> /dev/null || ! psql --version | grep -q "${POSTGRES_VERSION}"; then
  log "Installing PostgreSQL ${POSTGRES_VERSION}..."

  # Add PostgreSQL APT repository
  sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    postgresql-${POSTGRES_VERSION} \
    postgresql-client-${POSTGRES_VERSION}

  # Enable and start PostgreSQL
  systemctl enable postgresql
  systemctl start postgresql

  log "✓ PostgreSQL ${POSTGRES_VERSION} installed"
else
  log "PostgreSQL ${POSTGRES_VERSION} already installed"
fi

# =============================================================================
# PHASE 6: REDIS INSTALLATION (OPTIONAL, FOR FUTURE USE)
# =============================================================================

log "Phase 6: Installing Redis (disabled by default, app uses embedded mode)..."

if ! command -v redis-server &> /dev/null; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq redis-server

  # Create custom Redis config for HGV-Signing (not used by default)
  cat > /etc/redis/hgv-signing.conf << 'EOF'
port 6379
bind 127.0.0.1
maxmemory 256mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
dir /var/lib/redis
EOF

  # Disable default Redis service (app uses embedded Redis by default)
  systemctl disable redis-server
  systemctl stop redis-server || true

  log "✓ Redis installed (disabled, app uses embedded mode)"
else
  log "Redis already installed"
fi

# =============================================================================
# PHASE 7: ONNX RUNTIME INSTALLATION
# =============================================================================

log "Phase 7: Installing ONNX Runtime ${ONNX_VERSION}..."

if [ ! -f "/usr/lib/x86_64-linux-gnu/libonnxruntime.so" ]; then
  log "Downloading ONNX Runtime ${ONNX_VERSION}..."

  wget -q -O /tmp/onnxruntime.tgz \
    "https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-x64-${ONNX_VERSION}.tgz"

  log "Extracting ONNX Runtime..."
  tar -xzf /tmp/onnxruntime.tgz -C /usr/local

  # Create symlinks to standard library location
  ln -sf /usr/local/onnxruntime-linux-x64-${ONNX_VERSION}/lib/libonnxruntime.so.${ONNX_VERSION} \
    /usr/lib/x86_64-linux-gnu/libonnxruntime.so.1
  ln -sf /usr/lib/x86_64-linux-gnu/libonnxruntime.so.1 /usr/lib/x86_64-linux-gnu/libonnxruntime.so

  ldconfig

  rm /tmp/onnxruntime.tgz

  log "✓ ONNX Runtime ${ONNX_VERSION} installed"
else
  log "ONNX Runtime already installed"
fi

# Verify ONNX installation
if [ ! -f "/usr/lib/x86_64-linux-gnu/libonnxruntime.so" ]; then
  error "ONNX Runtime installation verification failed: library file not found"
  exit 1
fi

# Verify library is loadable
if ! ldconfig -p | grep -q "libonnxruntime"; then
  warn "ONNX Runtime library not in ldconfig cache, running ldconfig again..."
  ldconfig
fi

info "✓ ONNX Runtime verified"

# =============================================================================
# PHASE 8: APPLICATION USER AND DIRECTORY STRUCTURE
# =============================================================================

log "Phase 8: Creating application user and directory structure..."

# Create application user if not exists
if ! id -u ${APP_USER} > /dev/null 2>&1; then
  log "Creating user ${APP_USER}..."
  useradd -r -m -d ${APP_PATH} -s /bin/bash ${APP_USER}
  log "✓ User ${APP_USER} created"
else
  log "User ${APP_USER} already exists"
fi

# Create directory structure
log "Creating directory structure..."
mkdir -p ${APP_PATH}/{releases,shared/{config,log,tmp,storage,public,attachments,fonts,backups}}

# Set ownership
chown -R ${APP_USER}:${APP_USER} ${APP_PATH}

log "✓ Directory structure created"

# =============================================================================
# PHASE 9: PDFIUM LIBRARY INSTALLATION
# =============================================================================

log "Phase 9: Installing PDFium library..."

if [ ! -f "/usr/lib/x86_64-linux-gnu/libpdfium.so" ]; then
  log "Downloading PDFium library..."

  # Detect architecture
  ARCH=$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')

  wget -q -O /tmp/pdfium-linux.tgz \
    "https://github.com/docusealco/pdfium-binaries/releases/latest/download/pdfium-linux-${ARCH}.tgz"

  mkdir -p /tmp/pdfium-linux
  tar -xzf /tmp/pdfium-linux.tgz -C /tmp/pdfium-linux

  # Install library to standard location
  cp /tmp/pdfium-linux/lib/libpdfium.so /usr/lib/x86_64-linux-gnu/libpdfium.so
  cp /tmp/pdfium-linux/licenses/pdfium.txt /usr/share/doc/libpdfium-LICENSE.txt || true

  # Update library cache
  ldconfig

  # Cleanup
  rm -rf /tmp/pdfium-linux.tgz /tmp/pdfium-linux

  log "✓ PDFium library installed"
else
  log "PDFium library already installed"
fi

# Verify PDFium installation
if [ ! -f "/usr/lib/x86_64-linux-gnu/libpdfium.so" ]; then
  error "PDFium library installation verification failed: library file not found"
  exit 1
fi

# Verify library is loadable
if ! ldconfig -p | grep -q "libpdfium"; then
  warn "PDFium library not in ldconfig cache, running ldconfig again..."
  ldconfig
fi

info "✓ PDFium library verified"

# =============================================================================
# PHASE 10: FONTS DOWNLOAD
# =============================================================================

log "Phase 10: Downloading fonts..."

cd ${APP_PATH}/shared/fonts

if [ ! -f "GoNotoKurrent-Regular.ttf" ]; then
  log "Downloading GoNotoKurrent fonts..."
  wget -q https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Regular.ttf
  wget -q https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Bold.ttf
fi

if [ ! -f "DancingScript-Regular.otf" ]; then
  log "Downloading DancingScript font..."
  wget -q https://github.com/impallari/DancingScript/raw/master/fonts/DancingScript-Regular.otf
  wget -q https://github.com/impallari/DancingScript/raw/master/OFL.txt || true
fi

if [ ! -f "NotoSansSymbols2-Regular.ttf" ]; then
  log "Downloading NotoSansSymbols2 font..."
  wget -q https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io/fonts/NotoSansSymbols2/hinted/ttf/NotoSansSymbols2-Regular.ttf
fi

if [ ! -f "FreeSans.ttf" ]; then
  log "Downloading FreeSans font..."
  wget -q https://github.com/Maxattax97/gnu-freefont/raw/master/ttf/FreeSans.ttf
fi

# Merge FreeSans with NotoSansSymbols2 using fontforge
log "Merging FreeSans with NotoSansSymbols2..."
if command -v fontforge &> /dev/null; then
  # Create backup of original FreeSans
  cp FreeSans.ttf FreeSans-original.ttf || true

  # Merge fonts using fontforge Python API
  fontforge -lang=py -c "
import fontforge
try:
    font1 = fontforge.open('FreeSans.ttf')
    font2 = fontforge.open('NotoSansSymbols2-Regular.ttf')
    font1.mergeFonts(font2)
    font1.generate('FreeSans.ttf')
    print('Font merge successful')
except Exception as e:
    print(f'Font merge failed: {e}')
" 2>&1 | grep -q "successful" && log "✓ Fonts merged successfully" || log "Warning: Font merge failed, using unmerged FreeSans"
else
  log "Warning: fontforge not available, skipping font merge"
fi

# Set ownership
chown -R ${APP_USER}:${APP_USER} ${APP_PATH}/shared/fonts

log "✓ Fonts downloaded"

# =============================================================================
# PHASE 11: ONNX MODEL DOWNLOAD
# =============================================================================

log "Phase 11: Downloading ONNX model..."

if [ ! -f "${APP_PATH}/shared/tmp/model.onnx" ]; then
  log "Downloading ONNX field detection model..."

  mkdir -p ${APP_PATH}/shared/tmp
  wget -q -O ${APP_PATH}/shared/tmp/model.onnx \
    "https://github.com/docusealco/fields-detection/releases/download/1.0.0/model_704_int8.onnx"

  chown ${APP_USER}:${APP_USER} ${APP_PATH}/shared/tmp/model.onnx

  log "✓ ONNX model downloaded"
else
  log "ONNX model already exists"
fi

# =============================================================================
# PHASE 12: POSTGRESQL DATABASE SETUP
# =============================================================================

log "Phase 12: Setting up PostgreSQL database..."

DB_NAME="hgv_signing_production"
DB_USER="hgv_signing"
DB_PASSWORD=$(openssl rand -base64 32)

# Check if database already exists
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw ${DB_NAME}; then
  log "Database ${DB_NAME} already exists, skipping creation..."
else
  log "Creating database and user..."

  sudo -u postgres psql << EOF
CREATE DATABASE ${DB_NAME};
CREATE USER ${DB_USER} WITH ENCRYPTED PASSWORD '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};
\c ${DB_NAME}
GRANT ALL ON SCHEMA public TO ${DB_USER};
EOF

  log "✓ Database created"
  log ""
  log "Database credentials (SAVE THESE SECURELY!):"
  log "  Database: ${DB_NAME}"
  log "  User:     ${DB_USER}"
  log "  Password: ${DB_PASSWORD}"
  log ""
fi

# =============================================================================
# PHASE 13: ENVIRONMENT FILE CREATION
# =============================================================================

log "Phase 13: Creating environment configuration..."

mkdir -p /etc/hgv-signing

if [ ! -f "/etc/hgv-signing/hgv-signing.env" ]; then
  log "Creating environment file..."

  cat > /etc/hgv-signing/hgv-signing.env << EOF
# HGV-Signing Environment Configuration
# Generated on $(date)

# =============================================================================
# Rails Configuration
# =============================================================================
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=false
RAILS_SERVE_STATIC_FILES=true

# =============================================================================
# Database Configuration
# =============================================================================
DATABASE_HOST=127.0.0.1
DATABASE_PORT=5432
DATABASE_NAME=${DB_NAME}
DATABASE_USER=${DB_USER}
DATABASE_PASSWORD=${DB_PASSWORD}

# =============================================================================
# Redis Configuration (empty = embedded mode via Puma plugin)
# =============================================================================
REDIS_URL=

# To use embedded Redis, also set:
# LOCAL_REDIS_URL=redis://localhost:6379

# =============================================================================
# Application Server Configuration
# =============================================================================
PORT=3000
RAILS_MAX_THREADS=15
WEB_CONCURRENCY=2

# =============================================================================
# Sidekiq Configuration
# =============================================================================
SIDEKIQ_THREADS=5

# =============================================================================
# Security Configuration (CHANGE THE SECRET_KEY_BASE!)
# =============================================================================
SECRET_KEY_BASE=$(openssl rand -hex 64)

# Optional encryption secret
# ENCRYPTION_SECRET=$(openssl rand -hex 32)

# =============================================================================
# Storage Configuration
# =============================================================================
WORKDIR=${APP_PATH}/shared
ACTIVE_STORAGE_PUBLIC=false

# =============================================================================
# Application Configuration (UPDATE THESE!)
# =============================================================================
# HOST=sign.example.com
# FORCE_SSL=true
# APP_URL=https://sign.example.com

# =============================================================================
# Email Configuration (Optional)
# =============================================================================
# SMTP_ADDRESS=smtp.example.com
# SMTP_PORT=587
# SMTP_DOMAIN=example.com
# SMTP_USERNAME=noreply@example.com
# SMTP_PASSWORD=
# SMTP_AUTHENTICATION=plain
# SMTP_ENABLE_STARTTLS_AUTO=true

# =============================================================================
# Deployment Configuration (Internal - DO NOT MODIFY)
# =============================================================================
APP_PATH=${APP_PATH}
APP_USER=${APP_USER}
EOF

  chmod 640 /etc/hgv-signing/hgv-signing.env
  chown root:${APP_USER} /etc/hgv-signing/hgv-signing.env

  log "✓ Environment file created"
  log "   Location: /etc/hgv-signing/hgv-signing.env"
  log "   Please review and update HOST, FORCE_SSL, and email settings"
else
  log "Environment file already exists, skipping..."
fi

# =============================================================================
# PHASE 14: SYSTEMD SERVICE INSTALLATION
# =============================================================================

log "Phase 14: Installing systemd service..."

# The service file should be created by deploy/hgv-signing.service in the repo
# Here we just check if it needs to be copied

if [ -f "$(dirname "$(dirname "$0")")/deploy/hgv-signing.service" ]; then
  log "Copying systemd service file from repository..."
  cp "$(dirname "$(dirname "$0")")/deploy/hgv-signing.service" /etc/systemd/system/hgv-signing.service

  systemctl daemon-reload
  systemctl enable hgv-signing.service

  log "✓ Systemd service installed and enabled"
else
  log "Warning: deploy/hgv-signing.service not found in repository"
  log "You'll need to manually install the systemd service file"
fi

# =============================================================================
# PHASE 15: LOG ROTATION SETUP
# =============================================================================

log "Phase 15: Setting up log rotation..."

cat > /etc/logrotate.d/hgv-signing << 'EOF'
/opt/hgv-signing/shared/log/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    su hgv-signing hgv-signing
    dateext
    dateformat -%Y%m%d
    extension .log
}
EOF

log "✓ Log rotation configured (30 days retention)"

# =============================================================================
# PHASE 16: BACKUP SCRIPT AND CRON SETUP
# =============================================================================

log "Phase 16: Setting up automated backups..."

cat > /usr/local/bin/hgv-signing-backup << 'EOF'
#!/usr/bin/env bash
#
# HGV-Signing Database Backup Script
#
# This script performs daily backups of the PostgreSQL database and
# application attachments/uploads.
#

set -euo pipefail

# Load environment variables
if [ -f /etc/hgv-signing/hgv-signing.env ]; then
  source /etc/hgv-signing/hgv-signing.env
else
  echo "Error: Environment file not found"
  exit 1
fi

BACKUP_DIR="/opt/hgv-signing/shared/backups"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p ${BACKUP_DIR}

# Backup database
echo "[$(date)] Starting database backup..."
export PGPASSWORD="${DATABASE_PASSWORD}"
pg_dump -h ${DATABASE_HOST} \
        -p ${DATABASE_PORT} \
        -U ${DATABASE_USER} \
        -Fc \
        -f ${BACKUP_DIR}/database_${TIMESTAMP}.dump \
        ${DATABASE_NAME}

# Backup attachments/uploads
echo "[$(date)] Starting attachments backup..."
if [ -d "/opt/hgv-signing/shared/attachments" ] || [ -d "/opt/hgv-signing/shared/storage" ]; then
  tar -czf ${BACKUP_DIR}/attachments_${TIMESTAMP}.tar.gz \
      -C /opt/hgv-signing/shared \
      --ignore-failed-read \
      attachments storage 2>/dev/null || true
fi

# Remove old backups
echo "[$(date)] Cleaning up old backups (retention: ${RETENTION_DAYS} days)..."
find ${BACKUP_DIR} -name "*.dump" -mtime +${RETENTION_DAYS} -delete
find ${BACKUP_DIR} -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "[$(date)] Backup completed successfully"
echo "  Database: ${BACKUP_DIR}/database_${TIMESTAMP}.dump"
if [ -f "${BACKUP_DIR}/attachments_${TIMESTAMP}.tar.gz" ]; then
  echo "  Attachments: ${BACKUP_DIR}/attachments_${TIMESTAMP}.tar.gz"
fi
EOF

chmod +x /usr/local/bin/hgv-signing-backup
chown root:root /usr/local/bin/hgv-signing-backup

# Create cron job for daily backups at 2 AM
cat > /etc/cron.d/hgv-signing-backup << EOF
# HGV-Signing daily backup at 2 AM
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

0 2 * * * root /usr/local/bin/hgv-signing-backup >> /opt/hgv-signing/shared/log/backup.log 2>&1
EOF

log "✓ Backup script installed (daily at 2:00 AM, 30 days retention)"

# =============================================================================
# PHASE 17: SUDOERS CONFIGURATION FOR DEPLOYMENT
# =============================================================================

log "Phase 17: Configuring sudoers for deployment user..."

# Allow hgv-signing user to manage the systemd service without password
cat > /etc/sudoers.d/hgv-signing << EOF
# Allow hgv-signing user to manage the application service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl start hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl stop hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl restart hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl reload hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/systemctl status hgv-signing.service
${APP_USER} ALL=(ALL) NOPASSWD: /bin/journalctl -u hgv-signing.service *

# Allow deployment user (from GitLab CI) to run deployment as hgv-signing user
# NOTE: Replace 'deploy' with your actual SSH_USER from GitLab CI variables
# Example: If SSH_USER=gitlab-deploy, change 'deploy' to 'gitlab-deploy'
# deploy ALL=(hgv-signing) NOPASSWD: ALL
EOF

chmod 440 /etc/sudoers.d/hgv-signing

# Verify sudoers syntax
if visudo -c -f /etc/sudoers.d/hgv-signing; then
  log "✓ Sudoers configuration created successfully"
else
  error "Sudoers syntax error! Removing invalid file..."
  rm -f /etc/sudoers.d/hgv-signing
  exit 1
fi

log ""
log "IMPORTANT: Configure deployment user sudoers access!"
log "If you are using GitLab CI with a deployment user (SSH_USER),"
log "you need to allow that user to run commands as ${APP_USER}."
log ""
log "Run this command on the server (replace 'deploy' with your SSH_USER):"
log "  echo 'deploy ALL=(${APP_USER}) NOPASSWD: ALL' | sudo tee -a /etc/sudoers.d/hgv-signing"
log "  sudo visudo -c -f /etc/sudoers.d/hgv-signing"
log ""

# =============================================================================
# PHASE 18: FIREWALL CONFIGURATION (OPTIONAL)
# =============================================================================

log "Phase 18: Configuring firewall (if UFW is installed)..."

if command -v ufw &> /dev/null; then
  # Only configure if UFW is active
  if ufw status | grep -q "Status: active"; then
    ufw allow 3000/tcp comment 'HGV Signing Application' || true
    log "✓ Firewall rule added for port 3000"
  else
    log "UFW is installed but not active, skipping firewall configuration"
  fi
else
  log "UFW not installed, skipping firewall configuration"
fi

# =============================================================================
# FINAL SUMMARY
# =============================================================================

log ""
log "========================================================================="
log "SERVER PREPARATION COMPLETED SUCCESSFULLY!"
log "========================================================================="
log ""
log "Summary:"
log "  App path:         ${APP_PATH}"
log "  App user:         ${APP_USER}"
log "  Ruby version:     $(source /etc/profile.d/rbenv.sh && ruby --version)"
log "  Node.js version:  $(node --version)"
log "  PostgreSQL:       $(psql --version | head -n1)"
log ""
log "Configuration:"
log "  Environment file: /etc/hgv-signing/hgv-signing.env"
log "  Systemd service:  /etc/systemd/system/hgv-signing.service"
log "  Backup script:    /usr/local/bin/hgv-signing-backup"
log "  Backup schedule:  Daily at 2:00 AM (30 days retention)"
log ""
log "Database:"
log "  Name:     ${DB_NAME}"
log "  User:     ${DB_USER}"
log "  Password: (stored in environment file)"
log ""
log "Next steps:"
log "  1. Review and update /etc/hgv-signing/hgv-signing.env"
log "     - Set HOST, FORCE_SSL, APP_URL for production"
log "     - Configure SMTP settings for email"
log "  2. Deploy the application:"
log "     cd ${APP_PATH}"
log "     sudo -u ${APP_USER} bash /path/to/repo/scripts/deploy.sh"
log "  3. Configure nginx reverse proxy for SSL/TLS (recommended)"
log "  4. Start the service:"
log "     systemctl start hgv-signing"
log "     systemctl status hgv-signing"
log ""
log "========================================================================="
