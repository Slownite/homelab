{
  description = "Declarative Latitude homelab: validation is separate from deployment readiness";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
    };
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      disko,
      sops-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      common = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        ./hosts/latitude
      ];
      validation = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = common ++ [ ./tests/validation.nix ];
      };
      containerValidation = validation.extendModules {
        modules = [ { homelab.exampleContainer.enable = true; } ];
      };
    in
    {
      nixosConfigurations.latitude =
        if !(builtins.pathExists ./local/latitude.nix) then
          {
            # Only a failing sentinel derivation is exposed until private inventory exists.
            inherit pkgs;
            config.system.build.toplevel = pkgs.runCommand "latitude-deployment-blocked" { } ''
              echo "Deployment blocked: provide inspected local/latitude.nix via path flake" >&2
              exit 1
            '';
          }
        else
          nixpkgs.lib.nixosSystem {
            inherit system;
            modules = common ++ [
              ./local/latitude.nix
              ({ config, ... }: {
                assertions = [
                  {
                    assertion = config.homelab.install.internalDisk != null;
                    message = "Internal disk inspection required";
                  }
                  {
                    assertion = config.homelab.adminKeys != [ ];
                    message = "Verified administrator keys required";
                  }
                  {
                    assertion = config.systemd.network.networks != { };
                    message = "Verified network configuration required";
                  }
                ];
              })
            ];
          };
      formatter.${system} = pkgs.writeShellApplication {
        name = "format-homelab";
        runtimeInputs = [
          pkgs.findutils
          pkgs.nixfmt
        ];
        text = ''
          if [ "$#" -eq 0 ]; then
            find . -path './local' -prune -o -name '*.nix' -type f -print0 | xargs -0 -r nixfmt
          else
            nixfmt "$@"
          fi
        '';
      };
      packages.${system} = {
        inherit (pkgs) nixos-rebuild;
        nixos-anywhere = inputs.nixos-anywhere.packages.${system}.default;
      };
      checks.${system} = import ./tests {
        inherit pkgs validation containerValidation;
        source = self;
      };
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          sops
          age
        ];
      };
    };
}
