# flake.nix
{
  description = "php environment";

  inputs = { 
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { 
    self, nixpkgs 
  }:
  let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
      pkgs = import nixpkgs { inherit system; };
    });
  in
  {
    devShells = forEachSupportedSystem ({ pkgs }: {
      cxf2 = pkgs.mkShell {
        packages = with pkgs; [
          php84
          php84Packages.composer
        ];

        shellHook = ''
          export SHELL=/run/current-system/sw/bin/zsh
        '';

      };
    });
  };
}