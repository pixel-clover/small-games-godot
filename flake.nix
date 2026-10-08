{
  description = "Small Games: A collection of retro arcade games and art experiments in Godot 4";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system:
          let
            pkgs = import nixpkgs { inherit system; };
          in
          f pkgs
        );
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "small-games-dev";

          packages = [
            pkgs.godot_4
            pkgs.git
          ];

          shellHook = ''
            echo "=========================================================="
            echo "  Small Games (Godot 4) development environment"
            echo "  godot: $(godot --version 2>/dev/null || echo 'available via environment')"
            echo "=========================================================="
          '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt or pkgs.nixfmt-classic);
    };
}
