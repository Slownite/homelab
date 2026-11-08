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
    hermes-agent.url = "github:NousResearch/hermes-agent";
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
        ({ ... }: { _module.args.hermesAgent = inputs.hermes-agent; })
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
      hermesValidation = validation.extendModules {
        modules = [ { homelab.hermes.enable = true; } ];
      };
    in
    {
      nixosModules.installationVM = ./tests/installation-vm.nix;
      nixosModules.latitude = {
        imports = common ++ [ ./hosts/latitude/prerequisites.nix ];
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
        hermes-agent = inputs.hermes-agent.packages.${system}.default;
        nixos-anywhere = inputs.nixos-anywhere.packages.${system}.default;
      };
      checks.${system} = import ./tests {
        inherit
          pkgs
          validation
          containerValidation
          hermesValidation
          ;
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
