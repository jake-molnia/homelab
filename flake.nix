{
  description = "NixOS Homelab Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells = {
            default = pkgs.mkShell {
                cores = 18;
                max-job = 6;
                packages = with pkgs; [
                    # Core tools
                    just
                    git
                    
                    # Network tools
                    openssh
                    rsync
                ];

                shellHook = ''
                    echo "NixOS Homelab Development Environment"
                    just --list
                '';
                };
        };
      }
    );
}