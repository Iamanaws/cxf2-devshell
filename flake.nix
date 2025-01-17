{
  description = "php environment for CXF 2";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
      pkgs = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
      };
    });

    commonPackages = pkgs: with pkgs; [
      (php84.withExtensions (pe: pe.enabled ++ [pe.all.mongodb]))
      php84Packages.composer
      nodejs_22
      mongodb-ce
      mongosh
      (pkgs.callPackage ./package.nix {
        php = pkgs.php84;
      })
    ];

    setupScript = pkgs: pkgs.writeScript "setup.sh" (builtins.readFile ./setup.sh);
  in {
    packages = forEachSupportedSystem ({ pkgs }: {
      default = pkgs.callPackage ./package.nix { };
    });

    devShells = forEachSupportedSystem ({ pkgs }: {
      default = pkgs.mkShell {
        packages = commonPackages pkgs;
        shellHook = ''
          trap "echo 'Stopping services...'; pkill mongod; pkill -f 'php artisan serve'; pkill -f 'npm run dev'" EXIT
          ${setupScript pkgs}
        '';
      };

      fresh = pkgs.mkShell {
        packages = commonPackages pkgs;
        shellHook = ''
          trap "echo 'Stopping services...'; pkill mongod; pkill -f 'php artisan serve'; pkill -f 'npm run dev'" EXIT
          ${setupScript pkgs} fresh
        '';
      };

      migrate = pkgs.mkShell {
        packages = commonPackages pkgs;
        shellHook = ''
          trap "echo 'Stopping services...'; pkill mongod; pkill -f 'php artisan serve'; pkill -f 'npm run dev'" EXIT
          ${setupScript pkgs} migrate
        '';
      };

      load = pkgs.mkShell {
        packages = commonPackages pkgs;
        shellHook = ''
          trap "echo 'Stopping services...'; pkill mongod; pkill -f 'php artisan serve'; pkill -f 'npm run dev'" EXIT
          ${setupScript pkgs} load
        '';
      };
    });
  };
}
