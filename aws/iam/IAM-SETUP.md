# IAM Roles Setup Guide

## Overview

This directory contains IAM role configurations for the Real-Time Bidding ECS deployment.

## Files

- **`ecs-trust-policy.json`** - Trust policy allowing ECS to assume roles
- **`secrets-policy.json`** - Policy for accessing Secrets Manager
- **`cloudwatch-logs-policy.json`** - Policy for CloudWatch Logs access
- **`setup-roles.sh`** - Automated script to create both IAM roles

## Quick Setup

Run the automated script:

```bash
cd /Users/jckuan/Dev/Real-Time-Bidding
./aws/iam/setup-roles.sh
```

This will:
1. Create `RTB-ecsTaskExecutionRole` with permissions to:
   - Pull Docker images from ECR
   - Write logs to CloudWatch
   - Retrieve secrets from Secrets Manager

2. Create `RTB-ecsTaskRole` with permissions to:
   - Write application logs to CloudWatch

3. Display the role ARNs needed for your task definition

## Manual Setup

If you prefer to create roles manually:

### 1. Create RTB-ecsTaskExecutionRole

```bash
aws iam create-role \
  --role-name RTB-ecsTaskExecutionRole \
  --assume-role-policy-document file://aws/iam/ecs-trust-policy.json

aws iam attach-role-policy \
  --role-name RTB-ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam put-role-policy \
  --role-name RTB-ecsTaskExecutionRole \
  --policy-name SecretsManagerAccessPolicy \
  --policy-document file://aws/iam/secrets-policy.json
```

### 2. Create RTB-ecsTaskRole

```bash
aws iam create-role \
  --role-name RTB-ecsTaskRole \
  --assume-role-policy-document file://aws/iam/ecs-trust-policy.json

aws iam put-role-policy \
  --role-name RTB-ecsTaskRole \
  --policy-name CloudWatchLogsPolicy \
  --policy-document file://aws/iam/cloudwatch-logs-policy.json
```

### 3. Get Role ARNs

```bash
aws iam get-role --role-name RTB-ecsTaskExecutionRole --query 'Role.Arn' --output text
aws iam get-role --role-name RTB-ecsTaskRole --query 'Role.Arn' --output text
```

## Permissions Breakdown

### RTB-ecsTaskExecutionRole

**Purpose:** Allows ECS infrastructure to prepare and start your container

**Permissions:**
- `ecr:GetAuthorizationToken` - Authenticate with ECR
- `ecr:BatchCheckLayerAvailability` - Check if Docker layers exist
- `ecr:GetDownloadUrlForLayer` - Download Docker image layers
- `ecr:BatchGetImage` - Pull Docker images
- `logs:CreateLogStream` - Create log streams in CloudWatch
- `logs:PutLogEvents` - Write logs to CloudWatch
- `secretsmanager:GetSecretValue` - Retrieve database credentials and JWT secret

### RTB-ecsTaskRole

**Purpose:** Allows your application code to interact with AWS services

**Permissions:**
- `logs:CreateLogGroup` - Create log groups
- `logs:CreateLogStream` - Create log streams
- `logs:PutLogEvents` - Write application logs
- `logs:DescribeLogStreams` - Query log streams

## Security Best Practices

✅ **Principle of Least Privilege** - Roles only have permissions they need  
✅ **Secrets in Secrets Manager** - No hardcoded credentials  
✅ **Resource-specific policies** - Limited to `/ecs/rtb-app` log group  
✅ **Scoped secret access** - Only `rtb/*` secrets accessible  

## Troubleshooting

**Error: "Role already exists"**
- The script will skip creation and just update policies
- Or delete existing role: `aws iam delete-role --role-name <role-name>`

**Error: "Access Denied"**
- Ensure your AWS CLI user has IAM permissions
- Required permissions: `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PutRolePolicy`

**Can't retrieve secrets**
- Verify secrets exist: `aws secretsmanager list-secrets`
- Check secret ARNs match in `secrets-policy.json`
- Ensure secrets are in the same region

## Next Steps

After creating roles:
1. Copy the role ARNs from script output
2. Update `aws/task-definition.json`:
   - Replace `{ACCOUNT_ID}` placeholders
   - Set `executionRoleArn`
   - Set `taskRoleArn`
3. Continue with deployment in `aws/DEPLOYMENT.md`
