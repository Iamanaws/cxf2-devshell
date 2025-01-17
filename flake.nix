{
  description = "php environment for CXF 2";

  inputs = { 
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { 
    self, nixpkgs 
  }:
  let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
      pkgs = import nixpkgs { 
        inherit system; 
        config = { allowUnfree = true; };
      };
    });
  in
  {
    # Provide a top-level package build
    packages = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.callPackage ./package.nix { };
      }
    );

    devShells = forEachSupportedSystem ({ pkgs }: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          (php84.withExtensions (pe: pe.enabled ++ [pe.all.mongodb]))
          php84Packages.composer
          # php84Extensions.mongodb
          nodejs_22
          mongodb-ce
          mongosh

          # Add the built Laravel “env” so we get vendor/bin/laravel in $PATH
          (pkgs.callPackage ./package.nix {
            php = pkgs.php84; 
          })
        ];
        shellHook = ''
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
            mongod --dbpath "$MONGO_DB_PATH" \
                  --logpath "$MONGO_LOG_PATH" \
                  --replSet rs0 \
                  --bind_ip localhost \
                  --fork

            # Wait for mongod to start
            sleep 2

            # Initialize the replica set using mongosh
            echo "Initializing replica set..."
            mongosh --eval 'rs.initiate({_id: "rs0", members: [{_id: 0, host: "localhost:27017"}]})'

            echo "MongoDB replica set 'rs0' initialized."
          else
            echo "mongod is already running."
          fi

          # Ensure that mongod, the PHP server, and the NPM frontend are stopped when exiting the shell
          trap "echo 'Stopping services...'; pkill mongod; pkill -f 'php artisan serve'; pkill -f 'npm run dev'" EXIT

          # Run PHP commands only once if necessary
          if [ ! -f "vendor/autoload.php" ]; then
            echo "Installing PHP dependencies..."
            composer install
          fi

          # Check if migrations have already been run
          # if ! php artisan migrate | grep -q "Nothing to migrate"; then
          #   echo "Running migrations and seeders..."
          #   php artisan migrate:fresh
          #   php artisan db:seed
          #   php artisan db:seed --class=TestingDataSeeder
          # else
          #   echo "Migrations have already been run."
          # fi

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
        '';
      };
    });
  };
}