#!/bin/bash
set -e

# Helper function to read secret from file
# Usage: set_secret ENV_VAR_NAME FILE_ENV_VAR_NAME
set_secret() {
  local var_name="$1"
  local file_var_name="$2"

  # Only process if *_FILE env var is set
  if [ -n "${!file_var_name}" ]; then
    local secret_file="${!file_var_name}"

    # Skip if secret file path is empty
    if [ -z "$secret_file" ]; then
      return 0
    fi

    # Skip if secret file doesn't exist
    if [ ! -f "$secret_file" ]; then
      return 0
    fi

    # Read from file and export
    export "$var_name"="$(cat "$secret_file")"
  fi
}

rm -f /rails/tmp/pids/server.pid

# Set secrets from files
set_secret "SECRET_KEY_BASE" "APP_SECRET_KEY_BASE_FILE"

if [ "${APP_DB_MIGRATION:-false}" = "true" ]; then
  echo "Running database migration..."
  ./bin/rails db:prepare
fi

exec "${@}"
