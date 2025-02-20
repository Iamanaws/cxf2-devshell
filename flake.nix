{
  description = "php environment for CXF 2";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # Iterate over all target systems
      forSystems = f:
        nixpkgs.lib.genAttrs systems (system:
          let
            pkgs = import nixpkgs {
              inherit system;
              config = { allowUnfree = true; };
            };
          in f { pkgs = pkgs; });

      # Define PHP with the mongodb extension
      mkPhp = pkgs:
        pkgs.php84.withExtensions (pe: pe.enabled ++ [ pe.all.mongodb ]);

      # Common packages used in the dev shells
      commonPackages = pkgs:
        with pkgs; [
          (mkPhp pkgs)
          php84Packages.composer
          nodejs_22
          mongodb-ce
          mongosh
        ];

      # Write the setup script
      setupScript = pkgs:
        pkgs.writeScript "setup.sh" (builtins.readFile ./setup.sh);

      # Common trap to stop services on exit
      stopServicesTrap = ''
        trap "echo 'Stopping services...'; pkill mongod; pkill -f 'php artisan serve'; pkill -f 'npm run dev'" EXIT
      '';

      # A helper function to create a dev shell for a given action
      mkDevShell = action: pkgs:
        pkgs.mkShell {
          packages = commonPackages pkgs;
          shellHook = ''
            ${stopServicesTrap}
            ${setupScript pkgs} ${action}
          '';
        };
    in {
      # Formatter (you can run `nix fmt` for formatting)
      formatter = forSystems ({ pkgs }: pkgs.nixfmt);

      # Package derivation(s)
      packages = forSystems ({ pkgs }: {
        default = pkgs.buildEnv {
          name = "cxf2-devshell";
          paths = commonPackages pkgs;
        };
      });

      # Dev shells for various actions
      devShells = forSystems ({ pkgs }: {
        default = mkDevShell "run" pkgs;
        run = mkDevShell "run" pkgs;
        install = mkDevShell "install" pkgs;
        install-fresh = mkDevShell "install-fresh" pkgs;
        load = mkDevShell "load" pkgs;
      });
    };
}
