#!/bin/bash
# Script to generate Ansible inventory from EKS cluster

set -e

CLUSTER_NAME=${1:-"dc-llc-cluster"}
AWS_REGION=${2:-"ap-northeast-2"}
OUTPUT_FILE=${3:-"inventory/eks-nodes.ini"}

echo "Generating Ansible inventory for EKS cluster: ${CLUSTER_NAME}"
echo "Region: ${AWS_REGION}"

# Get the Auto Scaling Group name for the EKS node group
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
    --region ${AWS_REGION} \
    --query "AutoScalingGroups[?contains(Tags[?Key=='eks:cluster-name'].Value, '${CLUSTER_NAME}')].AutoScalingGroupName" \
    --output text | head -1)

if [ -z "$ASG_NAME" ]; then
    echo "Error: Could not find Auto Scaling Group for cluster ${CLUSTER_NAME}"
    exit 1
fi

echo "Found ASG: ${ASG_NAME}"

# Get EC2 instance IDs from the ASG
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --region ${AWS_REGION} \
    --auto-scaling-group-names ${ASG_NAME} \
    --query "AutoScalingGroups[0].Instances[?HealthStatus=='Healthy'].InstanceId" \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    echo "Error: No healthy instances found in ASG"
    exit 1
fi

echo "Found instances: ${INSTANCE_IDS}"

# Create inventory file
cat > ${OUTPUT_FILE} << 'EOF'
# Auto-generated EKS Worker Nodes Inventory
# Generated at: $(date)

[eks_workers]
EOF

# Get private IP addresses and add to inventory
for INSTANCE_ID in ${INSTANCE_IDS}; do
    PRIVATE_IP=$(aws ec2 describe-instances \
        --region ${AWS_REGION} \
        --instance-ids ${INSTANCE_ID} \
        --query "Reservations[0].Instances[0].PrivateIpAddress" \
        --output text)
    
    echo "${INSTANCE_ID} ansible_host=${PRIVATE_IP}" >> ${OUTPUT_FILE}
    echo "Added node: ${INSTANCE_ID} (${PRIVATE_IP})"
done

# Add group variables
cat >> ${OUTPUT_FILE} << 'EOF'

[eks_workers:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=~/.ssh/eks-node-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/bastion-key.pem ec2-user@${BASTION_HOST}"'
ansible_python_interpreter=/usr/bin/python3
EOF

echo ""
echo "Inventory file created: ${OUTPUT_FILE}"
echo "Total nodes: $(echo ${INSTANCE_IDS} | wc -w)"
cat ${OUTPUT_FILE}
