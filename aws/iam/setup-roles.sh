#!/bin/bash

# IAM Roles Setup Script for Real-Time Bidding System
# This script creates the necessary IAM roles for ECS tasks

set -e

# Configuration
AWS_REGION="${AWS_REGION:-us-west-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setting up IAM Roles for ECS${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Function to check if role exists
role_exists() {
    aws iam get-role --role-name "$1" &> /dev/null
}

# Step 1: Create RTB-ecsTaskExecutionRole
echo -e "${YELLOW}Step 1: Creating RTB-ecsTaskExecutionRole...${NC}"

if role_exists "RTB-ecsTaskExecutionRole"; then
    echo -e "${YELLOW}⚠ RTB-ecsTaskExecutionRole already exists, skipping...${NC}"
else
    # Create the role
    aws iam create-role \
        --role-name RTB-ecsTaskExecutionRole \
        --assume-role-policy-document file://aws/iam/ecs-trust-policy.json \
        --description "RTB: Allows ECS tasks to call AWS services on your behalf" \
        --region ${AWS_REGION}
    
    echo -e "${GREEN}✓ RTB-ecsTaskExecutionRole created${NC}"
fi

# Attach AWS managed policy for ECS task execution
echo "Attaching AmazonECSTaskExecutionRolePolicy..."
aws iam attach-role-policy \
    --role-name RTB-ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Attach custom secrets policy
echo "Attaching Secrets Manager policy..."
aws iam put-role-policy \
    --role-name RTB-ecsTaskExecutionRole \
    --policy-name SecretsManagerAccessPolicy \
    --policy-document file://aws/iam/secrets-policy.json

echo -e "${GREEN}✓ RTB-ecsTaskExecutionRole configured${NC}\n"

# Step 2: Create RTB-ecsTaskRole
echo -e "${YELLOW}Step 2: Creating RTB-ecsTaskRole...${NC}"

if role_exists "RTB-ecsTaskRole"; then
    echo -e "${YELLOW}⚠ RTB-ecsTaskRole already exists, skipping...${NC}"
else
    # Create the role
    aws iam create-role \
        --role-name RTB-ecsTaskRole \
        --assume-role-policy-document file://aws/iam/ecs-trust-policy.json \
        --description "RTB: Allows ECS tasks to access AWS services" \
        --region ${AWS_REGION}
    
    echo -e "${GREEN}✓ RTB-ecsTaskRole created${NC}"
fi

# Attach CloudWatch Logs policy
echo "Attaching CloudWatch Logs policy..."
aws iam put-role-policy \
    --role-name RTB-ecsTaskRole \
    --policy-name CloudWatchLogsPolicy \
    --policy-document file://aws/iam/cloudwatch-logs-policy.json

echo -e "${GREEN}✓ RTB-ecsTaskRole configured${NC}\n"

# Step 3: Get and display role ARNs
echo -e "${YELLOW}Step 3: Retrieving role ARNs...${NC}"

EXECUTION_ROLE_ARN=$(aws iam get-role --role-name RTB-ecsTaskExecutionRole --query 'Role.Arn' --output text)
TASK_ROLE_ARN=$(aws iam get-role --role-name RTB-ecsTaskRole --query 'Role.Arn' --output text)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}IAM Roles Created Successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo "Task Execution Role ARN:"
echo -e "${GREEN}${EXECUTION_ROLE_ARN}${NC}\n"

echo "Task Role ARN:"
echo -e "${GREEN}${TASK_ROLE_ARN}${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Update aws/task-definition.json with these ARNs:"
echo "   - executionRoleArn: ${EXECUTION_ROLE_ARN}"
echo "   - taskRoleArn: ${TASK_ROLE_ARN}"
echo ""
echo "2. Continue with the deployment process in aws/DEPLOYMENT.md"
