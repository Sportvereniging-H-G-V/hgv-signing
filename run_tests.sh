#!/usr/bin/env bash
# Script om tests lokaal uit te voeren (native, zonder Docker)

set -euo pipefail

echo "========================================================================="
echo "Running HGV-Signing Tests"
echo "========================================================================="

# Check if running in correct environment
if [ "${RAILS_ENV:-}" != "test" ]; then
  export RAILS_ENV=test
  echo "Setting RAILS_ENV=test"
fi

# Check if PostgreSQL is available
if ! command -v psql &> /dev/null; then
  echo "ERROR: PostgreSQL client not found. Please install postgresql-client."
  exit 1
fi

# Check if database exists
if [ -z "${DATABASE_URL:-}" ]; then
  export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/hgv_signing_test"
  echo "Using default DATABASE_URL: ${DATABASE_URL}"
fi

# Ensure test database exists
echo "Setting up test database..."
bundle exec rake db:test:prepare

# Run RSpec tests
echo ""
echo "Running RSpec tests..."
bundle exec rspec --format progress --order random "$@"

echo ""
echo "========================================================================="
echo "Tests completed successfully!"
echo "========================================================================="
