#!/bin/bash

# AWS Deployment Script for Real-Time Bidding System
# This script sets up the complete AWS infrastructure

set -e

# Configuration
AWS_REGION="us-west-2"
PROJECT_NAME="rtb"
ENVIRONMENT="production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Real-Time Bidding AWS Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Function to print section headers
print_section() {
    echo -e "\n${YELLOW}>>> $1${NC}\n"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
        echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    echo -e "${GREEN}✓ AWS CLI installed${NC}"
}

# Function to get AWS Account ID
get_account_id() {
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✓ AWS Account ID: ${ACCOUNT_ID}${NC}"
}

# Step 1: Create ECR Repository
create_ecr_repo() {
    print_section "Step 1: Creating ECR Repository"
    
    aws ecr create-repository \
        --repository-name ${PROJECT_NAME}-app \
        --region ${AWS_REGION} \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256 \
        2>/dev/null || echo "Repository already exists"
    
    echo -e "${GREEN}✓ ECR Repository ready${NC}"
}

# Step 2: Build and Push Docker Image
build_and_push_image() {
    print_section "Step 2: Building and Pushing Docker Image"
    
    # Login to ECR
    aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    
    # Build image for linux/amd64 (Fargate requirement)
    echo "Building Docker image for linux/amd64..."
    docker buildx build --platform linux/amd64 -t ${PROJECT_NAME}-app:latest .
    
    # Tag image
    docker tag ${PROJECT_NAME}-app:latest ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-app:latest
    
    # Push image
    echo "Pushing to ECR..."
    docker push ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-app:latest
    
    echo -e "${GREEN}✓ Docker image pushed to ECR${NC}"
}

# Step 3: Configure Security Group
configure_security_group() {
    print_section "Step 3: Configuring Security Group"
    
    echo "Running security group setup script..."
    
    if [ -f "./aws/setup-network.sh" ]; then
        bash ./aws/setup-network.sh
    else
        echo -e "${YELLOW}⚠ setup-network.sh not found. Manual configuration required:${NC}"
        echo "Add these security group rules:"
        echo "  - Port 80 from 0.0.0.0/0 (ALB accepts internet traffic)"
        echo "  - Port 443 from same SG (ECS → VPC endpoints)"
        echo "  - Port 3000 from same SG (ALB → ECS tasks)"
    fi
}

# Step 4: Create VPC and Networking
create_vpc() {
    print_section "Step 4: VPC Setup (Optional)"
    
    echo "If using default VPC, ensure it has:"
    echo "  ✓ Internet Gateway attached"
    echo "  ✓ VPC Endpoints for ECR (api, dkr), S3, Secrets Manager"
    echo ""
    echo "If creating new VPC, you'll need:"
    echo "  - 2 public subnets (for ALB)"
    echo "  - 2 private subnets (for ECS tasks)"
    echo "  - VPC Endpoints OR NAT Gateway for AWS service access"
}

# Step 5: Create RDS PostgreSQL
create_rds() {
    print_section "Step 5: Creating RDS PostgreSQL Database"
    
    # Generate secure password
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    cat << EOF
Run this command to create RDS instance:

aws rds create-db-instance \\
    --db-instance-identifier ${PROJECT_NAME}-db \\
    --db-instance-class db.t3.micro \\
    --engine postgres \\
    --engine-version 15.4 \\
    --master-username rtbadmin \\
    --master-user-password '${DB_PASSWORD}' \\
    --allocated-storage 20 \\
    --storage-type gp3 \\
    --db-name rtb_database \\
    --vpc-security-group-ids sg-XXXXXXXXX \\
    --db-subnet-group-name ${PROJECT_NAME}-db-subnet \\
    --backup-retention-period 7 \\
    --preferred-backup-window "03:00-04:00" \\
    --preferred-maintenance-window "mon:04:00-mon:05:00" \\
    --enable-cloudwatch-logs-exports '["postgresql"]' \\
    --storage-encrypted \\
    --publicly-accessible false \\
    --region ${AWS_REGION}

IMPORTANT: Save this password - you'll need it for Secrets Manager:
${DB_PASSWORD}

After creation, get the endpoint:
aws rds describe-db-instances --db-instance-identifier ${PROJECT_NAME}-db --query 'DBInstances[0].Endpoint.Address' --output text
EOF
}

# Step 6: Create ElastiCache Redis
create_elasticache() {
    print_section "Step 6: Creating ElastiCache Redis Cluster"
    
    cat << EOF
Run this command to create ElastiCache cluster:

aws elasticache create-cache-cluster \\
    --cache-cluster-id ${PROJECT_NAME}-redis \\
    --cache-node-type cache.t3.micro \\
    --engine redis \\
    --engine-version 7.0 \\
    --num-cache-nodes 1 \\
    --cache-subnet-group-name ${PROJECT_NAME}-cache-subnet \\
    --security-group-ids sg-XXXXXXXXX \\
    --region ${AWS_REGION}

After creation, get the endpoint:
aws elasticache describe-cache-clusters --cache-cluster-id ${PROJECT_NAME}-redis --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text
EOF
}

# Step 6: Create Secrets in Secrets Manager
create_secrets() {
    print_section "Step 6: Creating Secrets in AWS Secrets Manager"
    
    echo "Creating secrets..."
    
    # DB Username
    aws secretsmanager create-secret \
        --name rtb/db/username \
        --secret-string "rtbadmin" \
        --region ${AWS_REGION} \
        2>/dev/null || echo "Secret rtb/db/username already exists"
    
    # DB Password - use the same password generated in create_rds()
    if [ -n "${DB_PASSWORD}" ]; then
        aws secretsmanager create-secret \
            --name rtb/db/password \
            --secret-string "${DB_PASSWORD}" \
            --region ${AWS_REGION} \
            2>/dev/null || aws secretsmanager update-secret \
                --secret-id rtb/db/password \
                --secret-string "${DB_PASSWORD}" \
                --region ${AWS_REGION}
        echo -e "${GREEN}✓ DB password synced to Secrets Manager${NC}"
    else
        echo -e "${YELLOW}⚠ DB_PASSWORD not set. Using existing secret or manual setup required.${NC}"
    fi
    
    # JWT Secret
    JWT_SECRET=$(openssl rand -base64 32)
    aws secretsmanager create-secret \
        --name rtb/jwt/secret \
        --secret-string "${JWT_SECRET}" \
        --region ${AWS_REGION} \
        2>/dev/null || echo "Secret rtb/jwt/secret already exists"
    
    echo -e "${GREEN}✓ Secrets created${NC}"
    echo ""
    echo "Copy these ARNs to your task-definition.json:"
    aws secretsmanager describe-secret --secret-id rtb/db/username --region ${AWS_REGION} --query 'ARN' --output text
    aws secretsmanager describe-secret --secret-id rtb/db/password --region ${AWS_REGION} --query 'ARN' --output text
    aws secretsmanager describe-secret --secret-id rtb/jwt/secret --region ${AWS_REGION} --query 'ARN' --output text
}

# Step 7: Create ECS Cluster
create_ecs_cluster() {
    print_section "Step 7: Creating ECS Cluster"
    
    aws ecs create-cluster \
        --cluster-name ${PROJECT_NAME}-cluster \
        --capacity-providers FARGATE FARGATE_SPOT \
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
        --region ${AWS_REGION} \
        2>/dev/null || echo "Cluster already exists"
    
    echo -e "${GREEN}✓ ECS Cluster created${NC}"
}

# Step 8: Create CloudWatch Log Group
create_log_group() {
    print_section "Step 8: Creating CloudWatch Log Group"
    
    aws logs create-log-group \
        --log-group-name /ecs/${PROJECT_NAME}-app \
        --region ${AWS_REGION} \
        2>/dev/null || echo "Log group already exists"
    
    aws logs put-retention-policy \
        --log-group-name /ecs/${PROJECT_NAME}-app \
        --retention-in-days 7 \
        --region ${AWS_REGION}
    
    echo -e "${GREEN}✓ CloudWatch Log Group created${NC}"
}

# Main execution
main() {
    check_aws_cli
    get_account_id
    
    echo -e "\n${YELLOW}This script will guide you through deploying to AWS.${NC}"
    echo -e "${YELLOW}Some steps require manual configuration in AWS Console.${NC}\n"
    
    read -p "Press Enter to continue..."
    
    create_ecr_repo
    build_and_push_image
    configure_security_group
    create_vpc
    create_rds
    create_elasticache
    create_secrets
    create_ecs_cluster
    create_log_group
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Next Steps:${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "1. Ensure VPC endpoints exist for ECR, S3, Secrets Manager"
    echo "2. Update task-definition.json with RDS and ElastiCache endpoints"
    echo "3. Register task definition: aws ecs register-task-definition --cli-input-json file://aws/task-definition.json"
    echo "4. Create Application Load Balancer"
    echo "5. Create ECS Service with the task definition"
    echo "6. Run database migrations (see DEPLOYMENT.md Step 9)"
    echo ""
    echo "See aws/DEPLOYMENT.md and aws/FIXES-APPLIED.md for detailed instructions"
}

main
