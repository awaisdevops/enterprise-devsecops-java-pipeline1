#!/bin/bash
# Script to setup SSH access to EKS nodes via Systems Manager (SSM)

set -e

CLUSTER_NAME=${1:-"dc-llc-cluster"}
AWS_REGION=${2:-"ap-northeast-2"}
KEY_NAME="eks-node-ssh-key"

echo "Setting up SSH access to EKS nodes..."

# Get node instance IDs
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region ${AWS_REGION} \
    --filters "Name=tag:eks:cluster-name,Values=${CLUSTER_NAME}" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    echo "No running instances found for cluster ${CLUSTER_NAME}"
    exit 1
fi

echo "Found instances: ${INSTANCE_IDS}"

# Install SSM Session Manager plugin if not already installed
if ! command -v session-manager-plugin &> /dev/null; then
    echo "Installing AWS Session Manager plugin..."
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "/tmp/session-manager-plugin.deb"
    sudo dpkg -i /tmp/session-manager-plugin.deb
fi

echo "SSH access setup complete!"
echo "You can now connect to nodes using AWS Systems Manager"
