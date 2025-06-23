# justfile

# Check the flake for errors and formatting
check:
	@nix flake check

# Deploy the 'test-vm' configuration.
# The --fast flag skips building and just does the transfer if the build is already cached.
deploy: check
	@deploy-rs .#test-vm --fast

# A helper to easily SSH into our test VM
ssh:
	@ssh root@<YOUR_VM_IP_ADDRESS>