# List all available commands
default:
    @just --list

# Apply the configuration to all hosts
apply:
    nix-shell -p nixos-rebuild --command "nixos-rebuild switch --flake .#electivire --target-host root@10.10.10.195 --build-host root@10.10.10.195 --fast"

# Apply the configuration to a specific host
apply-host host:
    nix-shell -p nixos-rebuild --command "nixos-rebuild switch --flake .#{{host}} --target-host root@10.10.10.195 --build-host root@10.10.10.195 --fast"

# Update flake inputs
update:
    nix flake update

# Update a specific input
update-input input:
    nix flake lock --update-input {{input}}
