{
  description = "DVB departure board plugin for TRMNL";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # Firefox is not part of the shell because nixpkgs has no cached
          # macOS build; trmnlp's PNG rendering and tests use the system one.
          packages = with pkgs; [
            ruby_4_0
            imagemagick
            geckodriver
          ];

          shellHook = ''
            export GEM_HOME="$PWD/.gem"
            export PATH="$GEM_HOME/bin:$PATH"
            # TRMNL renders in UTC and templates add trmnl.user.utc_offset
            # themselves, so a local time zone would shift every time shown.
            export TZ=UTC
          '';
        };
      });
    };
}
