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
        "x86_64-darwin"
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
            # On non-NixOS Linux, Nix GUI binaries cannot access proprietary host GPU
            # drivers (/run/opengl-driver is missing). If a native host Godot binary exists,
            # prioritize it so full Vulkan/OpenGL hardware acceleration works seamlessly.
            if [ ! -d "/run/opengl-driver" ]; then
              HOST_GODOT=$(find "$HOME/bin" -maxdepth 2 -name "Godot*linux*x86_64" -type f 2>/dev/null | head -n 1)
              if [ -n "$HOST_GODOT" ]; then
                BIN_DIR="''${TMPDIR:-/tmp}/nix-godot-$UID"
                mkdir -p "$BIN_DIR"
                ln -sf "$HOST_GODOT" "$BIN_DIR/godot"
                export PATH="$BIN_DIR:$PATH"
              fi
            fi

            echo "=========================================================="
            echo "  Small Games (Godot 4) development environment"
            echo "  godot: $(godot --version 2>/dev/null || echo 'available via environment')"
            echo "  path:  $(which godot 2>/dev/null || echo 'not found')"
            echo "=========================================================="
          '';
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt or pkgs.nixfmt-classic);
    };
}
