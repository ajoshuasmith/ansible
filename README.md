# Homelab Ansible Automation

This repository contains Ansible automation for managing a standardized Docker-only virtual machine fleet in a homelab environment using XCP-NG virtualization and Ubuntu 22.04 VMs.

## Overview

This Ansible repository automates the complete setup and configuration of Docker VMs with Matrix-themed hostnames (docker-neo, docker-trinity, etc.). The setup includes:

- **XCP-NG guest tools** (via cloud-config and Ansible)
- **Docker Engine** installation and configuration
- **Portainer** deployment:
  - Portainer Server on `docker-neo`
  - Portainer Agents on all other docker-* hosts
- **Zerobyte** backup system on `docker-neo` for centralized backups to Backblaze B2
- **SSH key management** and configuration

## Architecture

### VM Naming Convention

All Docker hosts follow a Matrix-themed naming scheme:
- `docker-neo` - Runs Portainer Server (192.168.1.30)
- `docker-trinity` - Runs Portainer Agent (192.168.1.31)
- `docker-morpheus` - Runs Portainer Agent (192.168.1.32)
- `docker-oracle` - Runs Portainer Agent (192.168.1.33)

### Network Configuration

- **IP Range**: 192.168.1.30 - 192.168.1.40
- **Ansible User**: `joshua`
- **SSH Key**: `~/.ssh/id_ed25519` (ed25519 keypair)

### Initial VM Setup (Cloud-Config)

VMs are initially configured using Xen Orchestra cloud-config which handles:

- User creation (`joshua` with sudo access)
- SSH public key installation
- `qemu-guest-agent` installation
- Python3 and python3-apt installation (required for Ansible)
- Basic system configuration (hostname, locale, timezone)

The cloud-config template used in Xen Orchestra should include:

```yaml
#cloud-config
hostname: docker-template
manage_etc_hosts: true
locale: en_US.UTF-8
timezone: America/Chicago

users:
  - name: joshua
    gecos: "Joshua"
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    groups: users, admin, sudo
    shell: /bin/bash
    lock_passwd: false
    passwd: "$6$0YyYt5a/v9yRulBe$lwS6OmRsRxZ2fwD1ZgSl8RsONbsBRJiboN1P01Yx0AFLG5HxsFhqHeL5S2KcJNFnC99lSy0FzJ0405EJYDHLg0"
    ssh_authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICJHOxeEHwV5ad6CpPgLwVordrlndSXXz5J2MJoRf0Y8 joshua@homelab"

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

**Note**: Update the `ssh_authorized_keys` value with your actual public key from `~/.ssh/id_ed25519.pub`.

## Repository Structure

```
ansible/
├── install.sh             # VM bootstrap script (run from Ubuntu VM via curl)
├── ansible.cfg            # Ansible configuration
├── inventory/
│   └── hosts.ini         # Inventory file with VM definitions
├── group_vars/
│   └── all.yml           # Global variables
├── playbooks/
│   └── docker-hosts.yml  # Main playbook for Docker VM configuration
└── roles/
    ├── docker_engine/    # Docker Engine installation
    ├── portainer_server/ # Portainer Server deployment
    ├── portainer_agent/  # Portainer Agent deployment
    ├── ssh_baseline/     # SSH service baseline configuration
    ├── ssh_key_push/     # SSH key management
    └── zerobyte_server/  # Zerobyte backup system deployment
```

## Prerequisites

1. **Ubuntu 22.04 VM** created with cloud-config (see Initial VM Setup section)
   - User `joshua` with sudo access
   - SSH key already configured via cloud-config

2. **SSH Access** to the VM
   - You should be able to SSH into the VM as the `joshua` user
   - SSH key should already be configured from cloud-config

## Quick Start

After SSHing into your Ubuntu VM, run the install script:

```bash
curl -fsSL https://raw.githubusercontent.com/joshuasmith/ansible/main/install.sh | bash
```

Or with a custom repository URL:

```bash
ANSIBLE_REPO_URL="https://github.com/yourusername/ansible.git" \
curl -fsSL https://raw.githubusercontent.com/joshuasmith/ansible/main/install.sh | bash
```

The `install.sh` script will:

1. **Install Ansible** on the Ubuntu VM
2. **Clone the repository** to `/tmp/ansible-homelab`
3. **Create local inventory** for localhost execution
4. **Run the playbook** to configure the VM
5. **Auto-detect hostname** and install:
   - Docker Engine (all hosts)
   - Portainer Server + Zerobyte (if hostname is `docker-neo`)
   - Portainer Agent (if hostname matches `docker-*` but not `docker-neo`)

The script provides clear progress output and a summary when complete.

**After installation on docker-neo:**
- Access Portainer at `http://docker-neo:9000` or `https://docker-neo:9443`
- Access Zerobyte at `http://docker-neo:4096`
- Configure Zerobyte Backblaze B2 repository via the web UI

## Adding New VMs

To add a new Docker VM to your fleet:

### 1. Create VM in Xen Orchestra

- Use the cloud-config template (update hostname)
- Assign IP address from range 192.168.1.30-40
- Ensure SSH key matches your `~/.ssh/id_ed25519.pub`

### 2. Update Inventory

Edit `inventory/hosts.ini`:

```ini
[portainer_agents]
docker-trinity ansible_host=192.168.1.31 ansible_user=joshua
docker-morpheus ansible_host=192.168.1.32 ansible_user=joshua
docker-oracle ansible_host=192.168.1.33 ansible_user=joshua
docker-newhost ansible_host=192.168.1.34 ansible_user=joshua  # Add new host
```

**Note**: If adding a new Portainer Server, add it under `[portainer_server]` instead.

### 3. Run Install Script

SSH into the new VM and run:

```bash
curl -fsSL https://raw.githubusercontent.com/joshuasmith/ansible/main/install.sh | bash
```

## Roles

### `docker_engine`

Installs Docker Engine from Docker's official repository.

**What it does:**
- Adds Docker GPG key and repository
- Installs Docker CE and plugins
- Ensures Docker service is enabled and running

### `portainer_server`

Deploys Portainer Server on `docker-neo`.

**What it does:**
- Creates Docker volume for Portainer data
- Runs Portainer Server container
- Exposes ports 9000 (HTTP) and 9443 (HTTPS)

**Variables** (in `roles/portainer_server/defaults/main.yml`):
- `portainer_image`: Portainer image (default: `portainer/portainer-ce:latest`)
- `portainer_data_volume`: Volume name (default: `portainer_data`)
- `portainer_http_port`: HTTP port (default: `9000`)
- `portainer_https_port`: HTTPS port (default: `9443`)

### `portainer_agent`

Deploys Portainer Agent on all other docker-* hosts.

**What it does:**
- Runs Portainer Agent container
- Exposes agent port (default: 9001)

**Variables** (in `roles/portainer_agent/defaults/main.yml`):
- `portainer_agent_image`: Agent image (default: `portainer/agent:latest`)
- `portainer_agent_port`: Agent port (default: `9001`)

### `ssh_baseline`

Ensures SSH service is properly configured.

**What it does:**
- Installs OpenSSH server if missing
- Ensures SSH service is enabled and running
- Configures UFW firewall rule (if UFW is installed)

### `ssh_key_push`

Manages SSH authorized keys for the `joshua` user.

**What it does:**
- Reads local public key (`~/.ssh/id_ed25519.pub`)
- Adds public key to `~/.ssh/authorized_keys` on all hosts
- Idempotent (safe to run multiple times)

**Variables** (in `roles/ssh_key_push/defaults/main.yml`):
- `ssh_private_key_name`: Private key name (default: `id_ed25519`)
- `ssh_public_key_path`: Full path to public key (auto-configured)

### `zerobyte_server`

Deploys Zerobyte backup system on `docker-neo` as a centralized backup solution.

**What it does:**
- Deploys Zerobyte as a Docker container
- Enables Docker volume plugin functionality
- Provides web UI for backup management
- Supports backing up Docker volumes and directories
- Stores backups in Backblaze B2 (configured via web UI)

**Variables** (in `roles/zerobyte_server/defaults/main.yml`):
- `zerobyte_image`: Zerobyte Docker image (default: `ghcr.io/nicotsx/zerobyte:latest`)
- `zerobyte_container_name`: Container name (default: `zerobyte`)
- `zerobyte_web_port`: Web UI port (default: `4096`)
- `zerobyte_data_dir`: Data directory (default: `/var/lib/zerobyte`)
- `zerobyte_timezone`: Timezone (default: `America/Chicago`)

**Access:**
- Web UI: `http://docker-neo-ip:4096`

**Configuration:**
- Zerobyte is deployed automatically on `docker-neo`
- Backblaze B2 repository must be configured manually via the web UI after deployment
- To configure Backblaze B2:
  1. Access Zerobyte web UI at `http://docker-neo:4096`
  2. Navigate to "Repositories" section
  3. Create new repository
  4. Select "S3-compatible" as repository type
  5. Enter Backblaze B2 credentials:
     - Endpoint: `s3.us-west-004.backblazeb2.com` (or your region endpoint)
     - Access Key ID: Your B2 application key ID
     - Secret Access Key: Your B2 application key
     - Bucket name: Your B2 bucket name
  6. Test connection and save

**Backup Strategy:**
- Zerobyte can back up:
  - Docker volumes (accessible via Docker volume plugin)
  - Directories (can add as volume mounts)
  - Local appdata directories on docker-neo
- Future enhancements may include network mounts from other VMs

## Configuration Files

### `ansible.cfg`

Central Ansible configuration:
- Sets inventory path
- Configures SSH connection settings
- Defines roles path
- Sets privilege escalation defaults

### `inventory/hosts.ini`

VM inventory organized into groups:
- `[portainer_server]`: Host running Portainer Server
- `[portainer_agents]`: Hosts running Portainer Agents
- `[docker_hosts]`: Parent group containing all docker VMs

### `group_vars/all.yml`

Global variables applied to all hosts:
- `ansible_user`: SSH user (default: `joshua`)

## Troubleshooting

### SSH Connection Issues

**Problem**: Can't connect to VMs via SSH

**Solutions**:
1. Verify VM IP addresses are correct in `inventory/hosts.ini`
2. Check that SSH key matches cloud-config (`~/.ssh/id_ed25519.pub`)
3. Ensure VMs are reachable: `ping 192.168.1.30`
4. Check SSH config: `ssh -v docker-neo`

### Install Script Issues

**Problem**: Install script fails

**Solutions**:
1. Ensure you have sudo access: `sudo -v`
2. Check network connectivity: `ping 8.8.8.8`
3. Verify Git is installed: `git --version`
4. Check if repository is accessible: `curl -I https://github.com/joshuasmith/ansible`

### Ansible Playbook Failures

**Problem**: Playbook fails during execution

**Solutions**:
1. Check verbose output: `ansible-playbook -vv -i inventory/local/hosts.ini playbooks/local-bootstrap.yml`
2. Verify Python is installed: `python3 --version`
3. Check sudo access: `sudo -n true`
4. Review Ansible logs in the output for specific error messages

### Portainer Not Starting

**Problem**: Portainer containers fail to start

**Solutions**:
1. Check Docker service: `sudo systemctl status docker`
2. Check container logs: `sudo docker logs portainer` or `sudo docker logs portainer_agent`
3. Verify ports aren't in use: `sudo netstat -tlnp | grep -E '9000|9443|9001'`
4. Check if container exists: `sudo docker ps -a | grep portainer`

### Zerobyte Not Starting

**Problem**: Zerobyte container fails to start

**Solutions**:
1. Check Docker service: `sudo systemctl status docker`
2. Check container logs: `sudo docker logs zerobyte`
3. Verify FUSE is available: `ls -la /dev/fuse`
4. Check if Docker Compose is installed: `docker compose version`
5. Verify directory permissions: `ls -la /var/lib/zerobyte`
6. Check port availability: `sudo netstat -tlnp | grep 4096`

### Zerobyte Backblaze B2 Configuration

**Problem**: Cannot connect to Backblaze B2 repository

**Solutions**:
1. Verify B2 credentials are correct (application key ID and secret)
2. Check B2 endpoint URL matches your region (e.g., `s3.us-west-004.backblazeb2.com`)
3. Ensure B2 bucket exists and is accessible
4. Verify network connectivity: `curl -I https://s3.us-west-004.backblazeb2.com`
5. Check Zerobyte container can reach the internet: `docker exec zerobyte ping -c 1 8.8.8.8`

## Security Notes

- SSH keys are configured via cloud-config during VM creation
- Repository is cloned from GitHub (ensure it's private if containing sensitive data)
- Consider hardening SSH configuration in future iterations
- Portainer should be secured with authentication after initial setup

## Contributing

When making changes:

1. Test on a single VM first
2. Ensure roles are idempotent (safe to run multiple times)
3. Update documentation for any new features
4. Follow Ansible best practices

## License

This is a personal homelab project. Use as you see fit.

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Portainer Documentation](https://documentation.portainer.io/)
- [Zerobyte GitHub](https://github.com/nicotsx/zerobyte)
- [Backblaze B2 Documentation](https://www.backblaze.com/b2/docs/)
- [XCP-NG Documentation](https://xcp-ng.org/docs/)

