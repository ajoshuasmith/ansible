#!/bin/bash
# VM Bootstrap Script - Run from Ubuntu VM after SSH
# 
# This script installs Ansible, clones the repository, and configures the VM.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joshuasmith/ansible/main/install.sh | bash
#
# Or with custom repository:
#   ANSIBLE_REPO_URL="https://github.com/yourusername/ansible.git" \
#   curl -fsSL https://raw.githubusercontent.com/joshuasmith/ansible/main/install.sh | bash

set -e

# Default repository (can be overridden with ANSIBLE_REPO_URL env var)
DEFAULT_REPO_URL="https://github.com/joshuasmith/ansible.git"
DEFAULT_BRANCH="main"

# Use environment variables if set, otherwise use defaults
REPO_URL="${ANSIBLE_REPO_URL:-${DEFAULT_REPO_URL}}"
BRANCH="${ANSIBLE_BRANCH:-${DEFAULT_BRANCH}}"
REPO_DIR="/tmp/ansible-homelab"

# Simple banner
echo "========================================="
echo "  Docker VM Bootstrap Script"
echo "========================================="
echo ""
echo "Repository: ${REPO_URL}"
echo "Branch: ${BRANCH}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "ERROR: This script should not be run as root. Please run as a regular user with sudo access."
    exit 1
fi

# Install Ansible
echo "Step 1/4: Installing Ansible..."
sudo apt-get update -qq
sudo apt-get install -y -qq software-properties-common git > /dev/null
sudo apt-add-repository -y ppa:ansible/ansible > /dev/null 2>&1 || true
sudo apt-get update -qq
sudo apt-get install -y -qq ansible > /dev/null
echo "✓ Ansible installed"

# Clone repository
echo ""
echo "Step 2/4: Cloning repository..."
if [[ -d "${REPO_DIR}/.git" ]]; then
    echo "Repository exists, updating..."
    cd "${REPO_DIR}"
    git fetch origin > /dev/null 2>&1
    git checkout "${BRANCH}" > /dev/null 2>&1 || git checkout -b "${BRANCH}" > /dev/null 2>&1
    git pull origin "${BRANCH}" > /dev/null 2>&1 || echo "Warning: Could not pull latest changes"
else
    echo "Cloning repository..."
    git clone -b "${BRANCH}" "${REPO_URL}" "${REPO_DIR}" > /dev/null 2>&1
    cd "${REPO_DIR}"
fi
echo "✓ Repository cloned/updated"

# Create local inventory
echo ""
echo "Step 3/4: Creating local inventory..."
mkdir -p inventory/local

cat > inventory/local/hosts.ini << EOF
[localhost]
localhost ansible_connection=local

[portainer_server]
localhost ansible_connection=local

[portainer_agents]
localhost ansible_connection=local

[docker_hosts:children]
portainer_server
portainer_agents
EOF
echo "✓ Local inventory created"

# Create local playbook
echo ""
echo "Step 4/4: Creating local playbook..."
cat > playbooks/local-bootstrap.yml << 'EOFPB'
---
- name: Configure local Docker VM
  hosts: localhost
  become: true
  connection: local

  pre_tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: yes
        cache_valid_time: 3600

  roles:
    - docker_engine

- name: Deploy Portainer Server and Zerobyte (docker-neo only)
  hosts: localhost
  become: true
  connection: local
  roles:
    - portainer_server
    - zerobyte_server
  when: ansible_hostname == 'docker-neo'

- name: Deploy Portainer Agent (other docker-* hosts)
  hosts: localhost
  become: true
  connection: local
  roles:
    - portainer_agent
  when: ansible_hostname != 'docker-neo' and ansible_hostname is match('^docker-.*')
EOFPB
echo "✓ Local playbook created"

# Run Ansible
echo ""
echo "========================================="
echo "  Running Ansible Playbook"
echo "========================================="
echo ""

ansible-playbook -i inventory/local/hosts.ini playbooks/local-bootstrap.yml

# Summary
echo ""
echo "========================================="
echo "  Bootstrap Complete!"
echo "========================================="
echo ""
echo "Your VM has been configured with:"
echo "  ✓ Docker Engine"
HOSTNAME=$(hostname)
if [[ "${HOSTNAME}" == "docker-neo" ]]; then
    IP=$(hostname -I | awk '{print $1}')
    echo "  ✓ Portainer Server"
    echo ""
    echo "Access Portainer:"
    echo "  - HTTPS: https://${IP}:9443"
    echo "  - HTTP:  http://${IP}:9000"
else
    echo "  ✓ Portainer Agent (port 9001)"
fi
echo ""
echo "Repository location: ${REPO_DIR}"
echo ""

