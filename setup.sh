#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ACTION="${1:-load}"
echo "Setting up the development environment for California XF..."

# MongoDB directories
MONGO_DB_PATH="$HOME/.local/mongodb/db"
MONGO_LOG_PATH="$HOME/.local/mongodb/mongodb.log"

# Create necessary directories
mkdir -p "$MONGO_DB_PATH" "$(dirname "$MONGO_LOG_PATH")"

setup_mongo() {
  if ! pgrep -x "mongod" > /dev/null; then
    echo "Starting mongod with replica set configuration..."
    ulimit -n 64000
    mongod --dbpath "$MONGO_DB_PATH" \
           --logpath "$MONGO_LOG_PATH" \
           --replSet rs0 \
           --bind_ip localhost \
           --fork
    sleep 2
  else
    echo "mongod is already running."
  fi

  # Initialize replica set if not already initialized
  if [[ "$(mongosh --quiet --eval "rs.status().ok" || echo "0")" != "1" ]]; then
    echo "Initializing MongoDB replica set..."
    mongosh --quiet --eval 'rs.initiate({_id: "rs0", members: [{_id: 0, host: "localhost:27017"}]})'
    echo "Replica set initialized."
  else
    echo "MongoDB replica set 'rs0' is already initialized."
  fi
}

setup_env() {
  echo "Setting up the environment..."
  npm install
  composer install --ignore-platform-req=ext-mongodb

  # Prompt before overwriting an existing .env file
  if [[ -f .env ]]; then
    read -rp ".env file already exists. Overwrite? (y/N): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      cp .env.example .env
      php artisan key:generate
      echo ".env overwritten and key generated."
    else
      echo "Skipping .env file overwrite."
    fi
  else
    cp .env.example .env
    php artisan key:generate
    echo ".env created and key generated."
  fi
}

start_service() {
  local command="$1"
  local name="$2"

  if ! pgrep -f "$command" > /dev/null; then
    echo "Starting $name..."
    eval "$command" &
  else
    echo "$name is already running."
  fi
}

# Set up MongoDB
setup_mongo

# Execute action-specific tasks
case "$ACTION" in
  install)
    setup_env
    ;;
  install-fresh)
    setup_env
    read -rp "WARNING: This will run fresh migrations and seed the database, erasing all data. Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Aborting fresh migration."
      exit 0
    fi
    echo "Running migrations and seeders..."
    php artisan migrate:fresh
    php artisan db:seed
    php artisan db:seed --class=TestingDataSeeder
    ;;
  run)
    # 'run' performs no additional tasks
    ;;
  load)
    echo "Loading environment without running services..."
    ;;
  *)
    echo "Invalid action specified: $ACTION"
    exit 1
    ;;
esac

# Start background services unless in 'load' mode
if [[ "$ACTION" != "load" ]]; then
  start_service "php artisan serve" "PHP server"
  start_service "npm run dev" "NPM frontend"
  echo "Development environment is ready. Access it at http://localhost:8000"
fi
