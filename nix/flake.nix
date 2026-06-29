{
  description = "Console packages via home-manager (used by setup.sh on SteamOS)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium-browser = {
      url = "github:vikingnope/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, jovian-nixos, helium-browser, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system}.extend jovian-nixos.overlays.default;
      # Resolved at eval time from the environment (requires --impure), so the
      # same flake works for any user (`deck` on a Steam Deck) without templating.
      username = builtins.getEnv "USER";
      homeDirectory = builtins.getEnv "HOME";
      # Built from the egigoka/plasma-keyboard fork. Qt/KF6 deps come from the
      # kdePackages set so they share one Qt; the rest auto-fill from pkgs.
      plasma-keyboard = pkgs.callPackage ./plasma-keyboard.nix {
        inherit (pkgs.kdePackages)
          extra-cmake-modules wrapQtAppsHook
          qtbase qtdeclarative qtsvg qtvirtualkeyboard qtwayland
          plasma-wayland-protocols
          kcoreaddons ki18n kcmutils kconfig kirigami libplasma;
      };
      helium = helium-browser.packages.${system}.helium;
    in {
      packages.${system}.plasma-keyboard = plasma-keyboard;

      homeConfigurations.default = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
        extraSpecialArgs = { inherit username homeDirectory plasma-keyboard helium; };
      };
    };
}
