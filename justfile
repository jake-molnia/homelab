# Variables
packer_bin := "packer"
default_var_file := "vars.auto.pkvars.hcl"

# Find all VMs directories
vm_dirs := `find packer/vms -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort`
lxc_dirs := `find packer/lxc -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort`

# Default recipe
default:
    @just --list

# Build all VMs
build-all-vms:
    @echo "Building all VMs..."
    @for dir in {{vm_dirs}}; do \
        just build-vm $$dir; \
    done

# Build specific VM by name
build-vm vm_name:
    @echo "Building {{vm_name}} VM..."
    @if [ -f "packer/vms/{{vm_name}}/{{vm_name}}.pkr.hcl" ]; then \
        cd "packer/vms/{{vm_name}}" && {{packer_bin}} build -var-file={{default_var_file}} "{{vm_name}}.pkr.hcl"; \
    elif [ -d "packer/vms/{{vm_name}}" ]; then \
        cd "packer/vms/{{vm_name}}" && {{packer_bin}} build -var-file={{default_var_file}} .; \
    else \
        echo "Error: VM '{{vm_name}}' not found"; \
        exit 1; \
    fi

# Validate all VM templates
validate-all-vms:
    @echo "Validating all VM templates..."
    @for dir in {{vm_dirs}}; do \
        just validate-vm $$dir; \
    done

# Validate specific VM template
validate-vm vm_name:
    @echo "Validating {{vm_name}} VM template..."
    @if [ -f "packer/vms/{{vm_name}}/{{vm_name}}.pkr.hcl" ]; then \
        cd "packer/vms/{{vm_name}}" && {{packer_bin}} validate -var-file={{default_var_file}} "{{vm_name}}.pkr.hcl"; \
    elif [ -d "packer/vms/{{vm_name}}" ]; then \
        cd "packer/vms/{{vm_name}}" && {{packer_bin}} validate -var-file={{default_var_file}} .; \
    else \
        echo "Error: VM '{{vm_name}}' not found"; \
        exit 1; \
    fi

# Initialize all Packer templates
init-all:
    @echo "Initializing all Packer templates..."
    @if [ -f "packer/lxc/base.pkr.hcl" ]; then \
        cd packer/lxc && {{packer_bin}} init base.pkr.hcl; \
    fi
    @for dir in {{lxc_dirs}}; do \
        cd packer/lxc && {{packer_bin}} init $$dir; \
    done
    @for dir in {{vm_dirs}}; do \
        if [ -f "packer/vms/$$dir/$$dir.pkr.hcl" ]; then \
            cd "packer/vms/$$dir" && {{packer_bin}} init "$$dir.pkr.hcl"; \
        else \
            cd "packer/vms/$$dir" && {{packer_bin}} init .; \
        fi \
    done

# Help
help:
    @just --list
