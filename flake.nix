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
          echo "Setting up MongoDB as a single-node replica set..."

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

            # Initialize the replica set
            echo "Initializing replica set..."
            mongosh --eval 'rs.initiate({_id: "rs0", members: [{_id: 0, host: "localhost:27017"}]})'

            echo "MongoDB replica set 'rs0' initialized."
          else
            echo "mongod is already running."
          fi

          # Ensure mongod is stopped when the shell exits
          trap "echo 'Stopping MongoDB...'; pkill mongod" EXIT

          export SHELL=/run/current-system/sw/bin/zsh
          zsh
        '';
      };
    });
  };
}