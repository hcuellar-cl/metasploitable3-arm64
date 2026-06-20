#!/bin/bash
# Script to automate the deployment and provisioning of Metasploitable 3 ARM64.
# Execute this script from the host machine (Host Mac).

set -euo pipefail

# Load environment variables from utm.env if it exists
if [ -f "utm.env" ]; then
    echo "✓ Environment file 'utm.env' detected."
    # Export environment variables from utm.env (strip Windows carriage returns if any)
    eval $(sed 's/\r$//' utm.env)
fi

# Default parameters
DEFAULT_IP="${UTM_HOST_IP:-192.168.64.29}"
DEFAULT_USER="${UTM_USER:-msfadmin}"
DEFAULT_PORT="${UTM_SSH_PORT:-22}"

# Read parameters
IP="${1:-$DEFAULT_IP}"
USER="${2:-$DEFAULT_USER}"
PORT="${3:-$DEFAULT_PORT}"

echo "========================================================================="
echo " Automated Deployment of Metasploitable 3 ARM64"
echo " Target VM: $USER@$IP (Port: $PORT)"
echo "========================================================================="

# Step 1: Generate/Update the build package
echo "=== 1. Rebuilding local assets package ==="
if [ -f "./download_assets.sh" ]; then
    ./download_assets.sh
else
    echo "ERROR: 'download_assets.sh' not found in the current directory."
    exit 1
fi

# Step 2: Copy the tarball package to the VM via SCP
echo "=== 2. Transferring metasploitable3-arm-build.tar.gz package to the VM ==="
scp -P "$PORT" -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    metasploitable3-arm-build.tar.gz \
    "$USER@$IP:/tmp/"

# Step 3: Run extraction and provisioning via SSH
echo "=== 3. Starting remote provisioning via SSH (sudo password will be requested) ==="
SSH_CMD="cd /tmp && \
         rm -rf metasploitable3-arm-build && \
         tar -xvzf metasploitable3-arm-build.tar.gz && \
         cd metasploitable3-arm-build && \
         echo '=== Starting provisioning with root privileges ===' && \
         sudo ./provision_arm.sh"

ssh -p "$PORT" -t -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$USER@$IP" \
    "$SSH_CMD"

echo "========================================================================="
echo " Deployment completed successfully!"
echo "========================================================================="
