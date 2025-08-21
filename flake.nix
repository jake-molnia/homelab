# flake.nix
{
  description = "My Homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, deploy-rs }@inputs:
    let
      serverSystem = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${serverSystem};

      # Helper function to create nixos systems
      mkNixosSystem = modules: nixpkgs.lib.nixosSystem {
        system = serverSystem;
        specialArgs = { inherit inputs; };
        modules = modules;
      };

      # Define all our machines
      machines = {
        k3s-master = mkNixosSystem [
          ./nixos/common.nix
          ./nixos/k3s-master.nix
          ./nixos/hardware-configurations/k3s-master.nix
        ];
        k3s-slave = mkNixosSystem [
          ./nixos/common.nix
          ./nixos/k3s-slave.nix
          ./nixos/hardware-configurations/k3s-slave.nix
        ];
      };

    in
    {
      # Export all machine configurations
      nixosConfigurations = machines;

      # --- Deployment Configuration ---
      deploy = {
        nodes = {
          "k3s-master" = {
            hostname = "10.10.10.37"; # Your master IP
            sshUser = "root"; # SSH user for deployment
            remoteBuild = true;
            sshOpts = [ "-i" "/Users/jake/.ssh/keys/id_homelab_admin" ];
            profiles = {
              system = {
                user = "root";
                path = deploy-rs.lib.${serverSystem}.activate.nixos machines.k3s-master;
              };
            };
          };

          "k3s-slave" = {
            hostname = "10.10.10.74";
            sshUser = "root";
            remoteBuild = true;
            sshOpts = [ "-i" "/Users/jake/.ssh/keys/id_homelab_admin" ];
            profiles = {
              system = {
                user = "root";
                path = deploy-rs.lib.${serverSystem}.activate.nixos machines.k3s-slave;
              };
            };
          };
        };
      };

      # --- Development Shells ---
      devShells = {
        aarch64-darwin = {
          default = let pkgs = nixpkgs.legacyPackages.aarch64-darwin; in pkgs.mkShell {
            packages = [
              pkgs.just
              pkgs.git
              pkgs.gh
              deploy-rs.packages.aarch64-darwin.deploy-rs
            ];
          };
        };
        x86_64-linux = {
          default = let pkgs = nixpkgs.legacyPackages.x86_64-linux; in pkgs.mkShell {
            packages = [
              pkgs.just
              pkgs.kubectl # Add kubectl for k3s management
              deploy-rs.packages.x86_64-linux.deploy-rs
            ];
          };
        };
      };
      # FIXME: make this a automated thing using github actions
      #checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
