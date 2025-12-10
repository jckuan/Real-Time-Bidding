#!/bin/bash

# Security Group Setup Script for ECS Deployment
# Configures security group rules for ALB, ECS tasks, and VPC endpoints

set -e

AWS_REGION="${AWS_REGION:-us-west-2}"
SG_ID="${SG_ID:-sg-XXXXXXXXX}"  # Update with your security group ID

echo "=== Configuring Security Group Rules ==="
echo ""

if [ "$SG_ID" = "sg-XXXXXXXXX" ]; then
    echo "ERROR: Please update SG_ID in this script with your actual security group ID"
    exit 1
fi

# 1. Port 80 - ALB accepts internet traffic
echo "1. Adding port 80 for internet → ALB..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>&1 | grep -v "already exists" || echo "  ✓ Port 80 configured"

# 2. Port 443 - ECS tasks to VPC endpoints
echo ""
echo "2. Adding port 443 for ECS tasks → VPC endpoints..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 443 \
    --source-group $SG_ID \
    --region $AWS_REGION 2>&1 | grep -v "already exists" || echo "  ✓ Port 443 configured"

# 3. Port 3000 - ALB to ECS tasks
echo ""
echo "3. Adding port 3000 for ALB → ECS tasks..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 3000 \
    --source-group $SG_ID \
    --region $AWS_REGION 2>&1 | grep -v "already exists" || echo "  ✓ Port 3000 configured"

echo ""
echo "✓ Security group configuration complete"
echo ""
echo "Security group $SG_ID now allows:"
echo "  - Port 80 from internet (for ALB)"
echo "  - Port 443 from self (for VPC endpoints)"
echo "  - Port 3000 from self (for ALB → tasks)"

