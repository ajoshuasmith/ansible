# Homelab Ansible Automation

A comprehensive Ansible repository for automating the setup and management of my Docker-based homelab environment running on XCP-NG with Ubuntu VMs. This setup provides a standardized, reproducible way to configure my entire Docker infrastructure.

## What This Does

I use this repository to automate the complete lifecycle of my Docker VMs, from initial setup to ongoing management. It handles:

- **XCP-NG guest tools** installation and configuration
- **Docker Engine** installation from official repositories
- **Portainer** deployment for container management:
  - Portainer Server on my primary host
  - Portainer Agents on all other Docker hosts
- **Zerobyte** backup system for centralized backups to Backblaze B2
- **SSH configuration** and key management

Perfect for my homelab setup where I want infrastructure-as-code principles applied to my Docker fleet.

## Architecture Overview

### Host Naming

I use themed hostnames (you can customize this). By default, my primary server runs Portainer Server and Zerobyte, while other hosts run Portainer Agents.

### Network Setup

- I configure my IP range in the inventory file
- All hosts use a single Ansible user account
- I use SSH key-based authentication throughout

### Initial VM Setup

I create VMs using cloud-init/cloud-config in my hypervisor (Xen Orchestra, XCP-NG, etc.). This handles the initial user setup, SSH keys, and basic system configuration.

A typical cloud-config template I use looks like this:

```yaml
#cloud-config
hostname: docker-template
manage_etc_hosts: true
locale: en_US.UTF-8
timezone: America/Chicago

users:
  - name: ansible
    gecos: "Ansible User"
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    groups: users, admin, sudo
    shell: /bin/bash
    lock_passwd: false
    passwd: "$6$rounds=4096$your_hashed_password_here"
    ssh_authorized_keys:
      - "ssh-ed25519 YOUR_PUBLIC_KEY_HERE"

ssh_pwauth: true

package_update: true
package_upgrade: true
packages:
  - qemu-guest-agent
  - python3
  - python3-apt

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
```

**Important**: I replace the password hash and SSH public key with my own values. I generate a password hash using `mkpasswd --method=sha-512` or Python's `crypt` module.

## Repository Structure

```
ansible/
├── install.sh             # Bootstrap script (run from Ubuntu VM via curl)
├── ansible.cfg            # Ansible configuration
├── inventory/
│   └── hosts.ini         # VM inventory definitions
├── group_vars/
│   └── all.yml           # Global variables
├── playbooks/
│   └── docker-hosts.yml  # Main configuration playbook
└── roles/
    ├── docker_engine/    # Docker Engine installation
    ├── portainer_server/ # Portainer Server deployment
    ├── portainer_agent/  # Portainer Agent deployment
    ├── ssh_baseline/     # SSH service configuration
    ├── ssh_key_push/     # SSH key management
    ├── xcp_guest_tools/  # XCP-NG guest utilities
    └── zerobyte_server/  # Zerobyte backup system
```

## Getting Started

### Prerequisites

I need:
- Ubuntu 22.04 VMs created with cloud-config
- SSH access to my VMs
- Basic familiarity with Ansible (helpful but not required)

### Quick Setup

After creating a VM and SSH'ing into it, I simply run:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/ansible/main/install.sh | bash
```

That's it! The script will:
1. Install Ansible on the VM
2. Clone this repository
3. Create the necessary configuration files
4. Run the playbook to set everything up
5. Automatically detect what roles to deploy based on the hostname

If I'm using a custom repository URL, I can override it:

```bash
ANSIBLE_REPO_URL="https://github.com/yourusername/ansible.git" \
curl -fsSL https://raw.githubusercontent.com/yourusername/ansible/main/install.sh | bash
```

**After installation on my primary host:**
- I access Portainer at `http://my-host:9000` or `https://my-host:9443`
- I access Zerobyte at `http://my-host:4096`
- I configure my Zerobyte Backblaze B2 repository through the web UI

## Adding New Hosts

To add a new Docker host to my fleet:

1. **Create the VM** in my hypervisor with cloud-config
2. **Update my inventory** (`inventory/hosts.ini`) to include the new host
3. **SSH into the new VM** and run the install script

The system will automatically detect the hostname and deploy the appropriate services.

## Role Details

### Docker Engine

Installs Docker Engine from Docker's official APT repository, including Docker CLI, containerd, and Docker Compose plugins.

### Portainer

Portainer provides a web UI for managing Docker containers. My setup deploys:
- **Portainer Server** on my primary host (manages the environment)
- **Portainer Agents** on other hosts (report back to the server)

I can manage everything from a single Portainer Server interface.

### Zerobyte

Zerobyte is my backup automation tool built on Restic. It provides:
- Web UI for managing backups
- Support for Docker volumes and directories
- Integration with Backblaze B2 (S3-compatible storage)
- Automated scheduling and retention policies

After deployment, I configure my Backblaze B2 repository through the Zerobyte web UI. The setup instructions are straightforward and handled entirely through the interface.

### SSH Configuration

The SSH baseline role ensures SSH is properly configured and running, while the key push role manages authorized keys across all hosts for seamless access.

### XCP-NG Guest Tools

Installs and configures the XCP-NG guest utilities (`xe-guest-utilities`) which provide better integration with my hypervisor, including proper hostname reporting and performance metrics.

## Configuration

### Inventory File

My `inventory/hosts.ini` file defines my hosts. I organize them into groups like `[portainer_server]` and `[portainer_agents]` to control which services run where.

### Variables

Most configuration is handled through role defaults in `roles/*/defaults/main.yml`. I override these in `group_vars/` or `host_vars/` if needed.

## Troubleshooting

### Install Script Issues

If the install script fails for me:
- I make sure I have sudo access: `sudo -v`
- I check network connectivity: `ping 8.8.8.8`
- I verify Git is installed (should be included in Ubuntu)
- I check if the repository URL is accessible

### Playbook Failures

For playbook issues:
- I run with verbose output: `ansible-playbook -vv -i inventory/local/hosts.ini playbooks/local-bootstrap.yml`
- I ensure Python 3 is installed: `python3 --version`
- I verify sudo access works: `sudo -n true`
- I check the Ansible output for specific error messages

### Container Issues

If containers won't start:
- I check Docker service: `sudo systemctl status docker`
- I review container logs: `sudo docker logs <container-name>`
- I verify ports aren't in use: `sudo netstat -tlnp | grep <port>`
- I ensure containers exist: `sudo docker ps -a`

### Zerobyte Configuration

If I can't connect Zerobyte to Backblaze B2:
- I double-check my B2 application key ID and secret
- I verify the endpoint URL matches my B2 region
- I ensure the bucket exists and is accessible
- I test network connectivity from the Zerobyte container

## Customization

This setup is designed to be easily customizable. If I want to use a different backup solution, I swap out the Zerobyte role. If I need different Docker configurations, I modify the docker_engine role. The modular structure makes it simple to adapt to my specific needs.

## Security Considerations

- SSH keys are configured via cloud-config during VM creation
- Sensitive files are excluded via `.gitignore` (passwords, keys, secrets, etc.)
- I consider making my repository private if it contains sensitive information
- I use Ansible Vault for encrypting sensitive variables if needed
- I never commit actual credentials or private keys to the repository
- I create `.example` or `.template` versions of files containing sensitive data
- SSH hardening can be added as a future enhancement
- Portainer and Zerobyte should be secured with authentication after initial setup
- I keep my Ansible repository updated and review changes before applying

**Before pushing to a public repository:**
- I review `.gitignore` to ensure sensitive files are excluded
- I check `git status` to verify no sensitive files are staged
- I scan for accidentally committed secrets: `git log --all --full-history -- "*secret*" "*password*" "*key*"`

## Contributing

This is my personal homelab project, but contributions and feedback are welcome! If you find issues or have suggestions, feel free to open an issue or submit a pull request.

When contributing:
- Test changes on a single VM first
- Ensure roles are idempotent (safe to run multiple times)
- Update documentation for any new features
- Follow Ansible best practices

## License

This project is provided as-is for personal use. Feel free to fork and adapt it to your own needs.

## Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Portainer Documentation](https://documentation.portainer.io/)
- [Zerobyte GitHub](https://github.com/nicotsx/zerobyte)
- [Backblaze B2 Documentation](https://www.backblaze.com/b2/docs/)
- [XCP-NG Documentation](https://xcp-ng.org/docs/)
