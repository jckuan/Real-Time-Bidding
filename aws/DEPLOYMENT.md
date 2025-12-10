# AWS Deployment Guide

## Overview

This guide walks you through deploying the Real-Time Bidding system to AWS using:
- **ECS Fargate** for containerized application
- **RDS PostgreSQL** for database
- **ElastiCache Redis** for caching
- **Application Load Balancer** for traffic distribution
- **Auto Scaling** for handling traffic spikes

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Docker** installed locally (with buildx support for multi-platform builds)

## Critical Requirements

⚠️ **Before deploying, ensure:**

1. **Docker images must be built for linux/amd64** (Fargate requirement)
   ```bash
   docker buildx build --platform linux/amd64 -t app:latest .
   ```

2. **Security Group must have these inbound rules:**
   - Port 80 from 0.0.0.0/0 (ALB accepts internet traffic)
   - Port 443 from same security group (ECS → VPC endpoints)
   - Port 3000 from same security group (ALB → ECS tasks)

3. **VPC Endpoints required** (or NAT Gateway as alternative):
   - com.amazonaws.REGION.ecr.api (Private DNS enabled)
   - com.amazonaws.REGION.ecr.dkr (Private DNS enabled)
   - com.amazonaws.REGION.s3 (Gateway type)
   - com.amazonaws.REGION.secretsmanager (Private DNS enabled)

4. **IAM Execution Role must have:**
   - `AmazonECSTaskExecutionRolePolicy` attached

## Architecture

```
Internet
    │
    ▼
[Application Load Balancer]
    │
    ├─► [ECS Service - Task 1] ──┐
    ├─► [ECS Service - Task 2] ──┼──► [RDS PostgreSQL]
    └─► [ECS Service - Task 3] ──┘
           │
           └──► [ElastiCache Redis]
```

## Deployment Steps

### Step 1: Create IAM Roles and Security Group

```bash
# Create IAM roles
cd aws
./iam/setup-roles.sh

# Configure security group (after creating it in console or via CLI)
# Update SG_ID in setup-network.sh, then run:
./setup-network.sh
```

This sets up:
- IAM execution and task roles
- Security group rules for ALB, ECS tasks, and VPC endpoints

### Step 2: Run Deployment Script

```bash
cd aws
./deploy.sh
```

### Step 2: Run Deployment Script

```bash
cd aws
./deploy.sh
```

This script will:
- Create ECR repository
- Build Docker image **for linux/amd64** (required for Fargate)
- Push image to ECR
- Configure security group rules
- Create secrets in Secrets Manager
- Create ECS cluster
- Create CloudWatch log group

**Important:** The script builds the image with `--platform linux/amd64` to ensure compatibility with Fargate.

### Step 3: Create RDS Database

```bash
# Create DB subnet group first
aws rds create-db-subnet-group \
    --db-subnet-group-name rtb-db-subnet \
    --db-subnet-group-description "RTB Database Subnet Group" \
    --subnet-ids subnet-xxxxx subnet-yyyyy \
    --region us-west-2

# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier rtb-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.8 \
    --master-username rtbadmin \
    --master-user-password 'YourStrongPassword123!' \
    --allocated-storage 20 \
    --storage-type gp3 \
    --db-name rtb_database \
    --vpc-security-group-ids sg-xxxxx \
    --db-subnet-group-name rtb-db-subnet \
    --backup-retention-period 7 \
    --storage-encrypted \
    --no-publicly-accessible \
    --region us-west-2
```

Wait for the database to be available (~10 minutes):
```bash
aws rds wait db-instance-available --db-instance-identifier rtb-db
```

Get the endpoint:
```bash
aws rds describe-db-instances \
    --db-instance-identifier rtb-db \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text
```

### Step 4: Create ElastiCache Redis

```bash
# Create cache subnet group
aws elasticache create-cache-subnet-group \
    --cache-subnet-group-name rtb-cache-subnet \
    --cache-subnet-group-description "RTB Cache Subnet Group" \
    --subnet-ids subnet-xxxxx subnet-yyyyy \
    --region us-west-2

# Create Redis cluster
aws elasticache create-cache-cluster \
    --cache-cluster-id rtb-redis \
    --cache-node-type cache.t3.micro \
    --engine redis \
    --engine-version 7.0 \
    --num-cache-nodes 1 \
    --cache-subnet-group-name rtb-cache-subnet \
    --security-group-ids sg-xxxxx \
    --region us-west-2
```

Get the endpoint:
```bash
aws elasticache describe-cache-clusters \
    --cache-cluster-id rtb-redis \
    --show-cache-node-info \
    --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
    --output text
```

### Step 5: Update Task Definition

Edit `aws/task-definition.json` and replace:
- `{ACCOUNT_ID}` with your AWS account ID
- `{REGION}` with your region (e.g., us-west-2)
- `{RDS_ENDPOINT}` with RDS endpoint from Step 3
- `{ELASTICACHE_ENDPOINT}` with ElastiCache endpoint from Step 4

Register the task definition:
```bash
aws ecs register-task-definition \
    --cli-input-json file://aws/task-definition.json \
    --region us-west-2
```

### Step 6: Create Application Load Balancer

```bash
# Create ALB
aws elbv2 create-load-balancer \
    --name rtb-alb \
    --subnets subnet-xxxxx subnet-yyyyy \
    --security-groups sg-xxxxx \
    --region us-west-2

# Create target group
aws elbv2 create-target-group \
    --name rtb-targets \
    --protocol HTTP \
    --port 3000 \
    --vpc-id vpc-xxxxx \
    --target-type ip \
    --health-check-path /health \
    --health-check-interval-seconds 30 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --region us-west-2

# Create listener
aws elbv2 create-listener \
    --load-balancer-arn arn:aws:elasticloadbalancing:... \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:...
```

### Step 7: Create ECS Service

```bash
aws ecs create-service \
    --cluster rtb-cluster \
    --service-name rtb-service \
    --task-definition rtb-app:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-xxxxx,subnet-yyyyy],securityGroups=[sg-xxxxx],assignPublicIp=DISABLED}" \
    --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=rtb-app,containerPort=3000 \
    --region us-west-2
```

### Step 8: Configure Auto Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id service/rtb-cluster/rtb-service \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 2 \
    --max-capacity 10 \
    --region us-west-2

# Create scaling policy (CPU-based)
aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --resource-id service/rtb-cluster/rtb-service \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
        },
        "ScaleInCooldown": 60,
        "ScaleOutCooldown": 60
    }' \
    --region us-west-2
```

### Step 9: Run Database Migrations

#### Option 1: Via Bastion Host (Recommended for initial setup)

**Create bastion host:**
```bash
# Get your public IP
MY_IP=$(curl -s https://checkip.amazonaws.com)

# Create security group for bastion
aws ec2 create-security-group \
    --group-name RTB-Bastion-SG \
    --description "SSH access to bastion" \
    --vpc-id vpc-xxxxx

# Allow SSH from your IP
aws ec2 authorize-security-group-ingress \
    --group-name RTB-Bastion-SG \
    --protocol tcp --port 22 --cidr $MY_IP/32

# Launch bastion instance (requires existing key pair)
aws ec2 run-instances \
    --image-id ami-xxxxx \
    --instance-type t3.micro \
    --key-name YourKeyPairName \
    --security-group-ids sg-xxxxx \
    --subnet-id subnet-xxxxx \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=RTB-Bastion}]'

# Update RDS security group to allow port 5432 from bastion
aws ec2 authorize-security-group-ingress \
    --group-name RTB-RDS-SG \
    --protocol tcp --port 5432 --source-group RTB-Bastion-SG
```

**Connect and run migrations:**
```bash
# SSH to bastion
ssh -i key.pem ec2-user@<bastion-public-ip>

# Install PostgreSQL client
sudo yum install -y postgresql15

# Connect to RDS (use 'postgres' database initially if rtb_database doesn't exist)
psql -h <RDS_ENDPOINT> -U rtbadmin -d postgres

# Create database if it doesn't exist
CREATE DATABASE rtb_database;
\q

# Reconnect to the new database
psql -h <RDS_ENDPOINT> -U rtbadmin -d rtb_database

# Run migrations (copy/paste SQL from migrations/ folder)
```

#### Option 2: Via ECS Task (For automation/CI-CD)

```bash
aws ecs run-task \
    --cluster rtb-cluster \
    --task-definition rtb-app:1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-xxxxx],securityGroups=[sg-xxxxx],assignPublicIp=DISABLED}" \
    --overrides '{
        "containerOverrides": [{
            "name": "rtb-app",
            "command": ["node", "-e", "require('\''./src/database/postgres'\'').query(require('\''fs'\'').readFileSync('\''./migrations/001_create_users_table.sql'\'', '\''utf8'\''))"]
        }]
    }'
```

### Step 10: Verify Deployment

```bash
# Get ALB DNS name
aws elbv2 describe-load-balancers \
    --names rtb-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text

# Test the endpoint
curl http://<ALB-DNS-NAME>/health
```

## Common Issues and Solutions

See `aws/FIXES-APPLIED.md` for detailed troubleshooting.

### Tasks fail to start with "unable to pull secrets or registry auth"

**Cause**: Security group missing port 443 inbound rule

**Fix**:
```bash
aws ec2 authorize-security-group-ingress \
    --group-id <SG_ID> \
    --protocol tcp --port 443 \
    --source-group <SG_ID> \
    --region us-west-2
```

### Tasks fail with "Manifest does not contain descriptor matching platform"

**Cause**: Docker image built for ARM64 instead of AMD64

**Fix**: Rebuild image with platform flag:
```bash
docker buildx build --platform linux/amd64 -t rtb-app:latest .
```

### ALB connection timeout

**Cause**: Security group missing required ports

**Fix**: Ensure security group has:
- Port 80 from 0.0.0.0/0
- Port 3000 from same security group

### Database doesn't exist

**Cause**: RDS created without specifying database name

**Fix**: Connect to 'postgres' database and create it:
```sql
CREATE DATABASE rtb_database;
```

- [ ] Security groups configured properly (least privilege)
- [ ] RDS encryption at rest enabled
- [ ] RDS in private subnet only
- [ ] ElastiCache in private subnet only
- [ ] Secrets stored in AWS Secrets Manager
- [ ] IAM roles follow principle of least privilege
- [ ] CloudWatch logs enabled
- [ ] VPC Flow Logs enabled (optional)
- [ ] AWS WAF configured on ALB (optional)

## Cost Estimation

**Estimated Monthly Cost** (us-west-2):
- ECS Fargate (2 tasks): ~$30
- RDS db.t3.micro: ~$15
- ElastiCache t3.micro: ~$12
- ALB: ~$20
- Data transfer: ~$10
- **Total: ~$87/month**

*Costs will increase with auto-scaling during high traffic*

## Monitoring

Access CloudWatch:
```bash
# View logs
aws logs tail /ecs/rtb-app --follow --region us-west-2

# View metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --dimensions Name=ServiceName,Value=rtb-service Name=ClusterName,Value=rtb-cluster \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average \
    --region us-west-2
```

## Troubleshooting

### Service won't start
```bash
# Check service events
aws ecs describe-services \
    --cluster rtb-cluster \
    --services rtb-service \
    --query 'services[0].events' \
    --region us-west-2

# Check task logs
aws logs tail /ecs/rtb-app --follow
```

### Database connection issues
- Verify security group allows traffic from ECS tasks
- Check RDS endpoint is correct in task definition
- Verify secrets are accessible

### High latency
- Check CloudWatch metrics for CPU/Memory
- Scale up task count
- Consider upgrading instance types

## Cleanup

To avoid charges, delete resources:
```bash
# Delete ECS service
aws ecs update-service --cluster rtb-cluster --service rtb-service --desired-count 0
aws ecs delete-service --cluster rtb-cluster --service rtb-service

# Delete ECS cluster
aws ecs delete-cluster --cluster rtb-cluster

# Delete RDS
aws rds delete-db-instance --db-instance-identifier rtb-db --skip-final-snapshot

# Delete ElastiCache
aws elasticache delete-cache-cluster --cache-cluster-id rtb-redis

# Delete ALB, target groups, listeners
# (via AWS Console or CLI)
```
