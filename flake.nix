{
  description = "vitrum — a glass desktop for niri: the shell, the patched compositor and a NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # niri at the revision lib/stages/30-niri.sh pins (NIRI_REV); the patches in
    # patches/niri go on top. The two are kept together by an assertion in
    # nix/packages.nix: move the pin there and here, then `nix flake update niri`.
    niri = {
      url = "github:YaLTeR/niri/a8562a1126922ed4c1c94d34c1dbb26633491d05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      niri,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;

      # Every package for one nixpkgs (nix/packages.nix).
      packagesFor =
        pkgs:
        import ./nix/packages.nix {
          inherit pkgs;
          niriFlake = niri;
          root = ./.;
        };
      vitrumFor = forAllSystems (system: packagesFor nixpkgs.legacyPackages.${system});

      # A small system with the module on: what the checks evaluate, and a
      # virtual machine to look at (nixos-rebuild build-vm --flake .#vm).
      vmFor =
        system:
        lib.nixosSystem {
          modules = [
            self.nixosModules.default
            ./nix/vm.nix
            { nixpkgs.hostPlatform = system; }
          ];
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          p = vitrumFor.${system};
        in
        {
          inherit (p)
            niri-vitrum
            quickshell
            vitrum
            vitrum-sddm-theme
            vitrum-plymouth-theme
            phosphor-fonts
            bibata-cursor
            ;
          default = p.vitrum;
        }
      );

      # pkgs.vitrumPackages, built with the nixpkgs the overlay is applied to.
      overlays.default = final: _prev: {
        vitrumPackages = removeAttrs (packagesFor final) [ "lib" ];
      };

      nixosModules.default = import ./nix/module.nix { inherit self; };
      nixosModules.vitrum = self.nixosModules.default;

      nixosConfigurations = {
        vm = vmFor "x86_64-linux";
        vm-aarch64 = vmFor "aarch64-linux";
      };

      checks = forAllSystems (
        system:
        import ./nix/checks.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          vitrum = vitrumFor.${system};
          nixos = vmFor system;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
