{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  };
  outputs = { self, nixpkgs }@inputs: {
      colmena = {
        meta = {
          nixpkgs = import nixpkgs { system = "x86_64-linux"; };
          specialArgs = { inherit nixpkgs; };
        };
        "my-nixos" = { name, nodes, ... }: {
          deployment.targetHost = "192.168.5.42";
          deployment.targetUser = "root";
        };
      };
    };
  }
