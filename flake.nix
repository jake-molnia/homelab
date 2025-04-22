{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, colmena }@inputs: {
    # Standard NixOS configurations for each host
    nixosConfigurations = {
      electivire = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/electivire/configuration.nix ];
      };
      yungoos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/yungoos/configuration.nix ];
      };
    };

    colmena = {
      meta = {
        nixpkgs = import nixpkgs { system = "x86_64-linux"; };
        specialArgs = { inherit nixpkgs; };
      };

      "electivire" = { name, nodes, ... }: {
        deployment.targetHost = "10.10.10.195";
        deployment.targetUser = "root";
        deployment.buildOnTarget = true;
        imports = [ ./hosts/electivire/configuration.nix ];
      };

      #"yungoos" = { name, nodes, ... }: {
      #  deployment.targetHost = "192.168.5.42";
      #  deployment.targetUser = "root";
      #  imports = [ ./hosts/yungoos/configuration.nix ];
      #};
    };
  };
}
