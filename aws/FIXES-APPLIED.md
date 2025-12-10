# AWS Deployment Fixes Applied

## Critical Fixes (Required)

### 1. Security Group Rules ⚠️ **CRITICAL**
**Problem**: Security group missing essential inbound rules  
**Fixes Applied**:

```bash
# Allow port 443 for VPC endpoints (ECS tasks to AWS services)
aws ec2 authorize-security-group-ingress \
    --group-id sg-0f45b30eeb2ea2d09 \
    --protocol tcp --port 443 \
    --source-group sg-0f45b30eeb2ea2d09 \
    --region us-west-2

# Allow port 80 for ALB to accept internet traffic
aws ec2 authorize-security-group-ingress \
    --group-id sg-0f45b30eeb2ea2d09 \
    --protocol tcp --port 80 \
    --cidr 0.0.0.0/0 \
    --region us-west-2

# Allow port 3000 for ALB to reach ECS tasks
aws ec2 authorize-security-group-ingress \
    --group-id sg-0f45b30eeb2ea2d09 \
    --protocol tcp --port 3000 \
    --source-group sg-0f45b30eeb2ea2d09 \
    --region us-west-2
```

**Why needed**:
- Port 443: VPC endpoints require this for ECS tasks to access ECR/Secrets Manager
- Port 80: ALB needs to accept HTTP traffic from internet
- Port 3000: ALB needs to forward traffic to ECS tasks

### 2. Docker Image Architecture ⚠️ **CRITICAL**
**Problem**: Image built for ARM64 (Mac M1/M2), Fargate requires AMD64  
**Fix**: Build with platform flag:
```bash
docker buildx build --platform linux/amd64 -t rtb-app:latest .
```

## Other Fixes Applied (May Not Be Required)

### 3. Database Creation
**Problem**: RDS instance created without database  
**Fix**: Added `--db-name rtb_database` to RDS creation

### 4. Secrets Manager (Workaround)
**Problem**: Tasks couldn't retrieve secrets (may have been security group issue)  
**Temporary solution**: Switched to environment variables  
**Note**: With port 443 fix, Secrets Manager should work now

### 5. Network Configuration (Likely Unnecessary)
Applied but probably not needed if VPC endpoints working:
- Public IP assignment
- Route table associations
- Auto-assign public IP on subnets

### 6. IAM Permissions
**Fix**: Ensured `AmazonECSTaskExecutionRolePolicy` attached to execution role

## Final Working Configuration

### Security Group (sg-0f45b30eeb2ea2d09)
**Inbound Rules:**
- Port 80 from 0.0.0.0/0 (internet → ALB)
- Port 443 from sg-0f45b30eeb2ea2d09 (ECS tasks → VPC endpoints)
- Port 3000 from sg-0f45b30eeb2ea2d09 (ALB → ECS tasks)
- Port 5432 from bastion (for database migrations)

**Outbound Rules:**
- All traffic to 0.0.0.0/0

### Required Components
✅ VPC Endpoints: ECR API, ECR Docker, S3, Secrets Manager (Private DNS enabled)  
✅ Docker image: Built for `linux/amd64`  
✅ IAM Role: `AmazonECSTaskExecutionRolePolicy` attached  
✅ RDS: Created with `--db-name rtb_database`  
✅ Task Definition: Uses Secrets Manager (not environment variables)

### NOT Required
❌ Public IP assignment (VPC endpoints handle connectivity)  
❌ Internet Gateway routes (unless no VPC endpoints)  
❌ NAT Gateway (unless no VPC endpoints)
