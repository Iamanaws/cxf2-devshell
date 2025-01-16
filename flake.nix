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
          php84
          php84Packages.composer
          nodejs_22
          mongodb-ce
          # mongodb-compass

          # Add the built Laravel “env” so we get vendor/bin/laravel in $PATH
          (pkgs.callPackage ./package.nix {
            php = pkgs.php84; 
          })
        ];

        shellHook = ''
          export SHELL=/run/current-system/sw/bin/zsh
          zsh
        '';

      };
    });
  };
}