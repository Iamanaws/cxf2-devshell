#!/usr/bin/env bash

ACTION=${1:-load}

echo "Setting up the development environment for California XF..."

# Define MongoDB data and log directories
MONGO_DB_PATH="$HOME/.local/mongodb/db"
MONGO_LOG_PATH="$HOME/.local/mongodb/mongodb.log"

# Create directories if they don't exist
mkdir -p "$MONGO_DB_PATH"
mkdir -p "$(dirname "$MONGO_LOG_PATH")"

# Check if mongod is already running
if ! pgrep -x "mongod" > /dev/null; then
  echo "Starting mongod with replica set configuration..."
  ulimit -n 64000

  mongod --dbpath "$MONGO_DB_PATH" \
        --logpath "$MONGO_LOG_PATH" \
        --replSet rs0 \
        --bind_ip localhost \
        --fork

  # Wait for mongod to start
  sleep 2
else
  echo "mongod is already running."
fi

# Check if replica set is already initialized
REPLICA_SET_STATUS=$(mongosh --quiet --eval "rs.status().ok" || echo "not initialized")

if [[ "$REPLICA_SET_STATUS" == "1" ]]; then
  echo "MongoDB replica set 'rs0' is already initialized."
else
  echo "Initializing replica set..."
  mongosh --quiet --eval 'rs.initiate({_id: "rs0", members: [{_id: 0, host: "localhost:27017"}]})'
  echo "MongoDB replica set 'rs0' initialized."
fi

case $ACTION in
  run)
    ;;
  fresh)
    echo "Setting up the environment..."
    npm install
    composer install --ignore-platform-req=ext-mongodb
    cp .env.example .env
    php artisan key:generate

    echo "Running migrations and seeders..."
    php artisan migrate:fresh
    php artisan db:seed
    php artisan db:seed --class=TestingDataSeeder
    ;;
  migrate)
    echo "Running migrations..."
    php artisan migrate
    ;;
  load)
    echo "Loading environment without running migrations or seeders..."
    ;;
  *)
    echo "Invalid action specified: $ACTION"
    exit 1
    ;;
esac

# Skip starting the PHP server and NPM frontend for the 'load' action
if [[ "$ACTION" != "load" ]]; then

  # Start the PHP server in the background if it's not running
  if ! pgrep -f "php artisan serve" > /dev/null; then
    echo "Starting PHP server..."
    php artisan serve &
  else
    echo "PHP server is already running."
  fi

  # Start the NPM frontend in the background if it's not running
  if ! pgrep -f "npm run dev" > /dev/null; then
    echo "Starting NPM frontend..."
    npm run dev &
  else
    echo "NPM frontend is already running."
  fi

  echo "Development environment is ready. Access it at http://localhost:8000"
fi

# Ensure cleanup when exiting
# trap "echo 'Stopping services...'; pkill mongod; pkill -f 'php artisan serve'; pkill -f 'npm run dev'" EXIT
