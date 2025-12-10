# AWS Deployment Quick Start

## One-Time Setup (15-20 minutes)

### 1. Create VPC Endpoints (if not using NAT Gateway)

```bash
VPC_ID="vpc-xxxxx"  # Your VPC ID
SUBNETS="subnet-xxxxx subnet-yyyyy"  # Your subnet IDs
SG_ID="sg-xxxxx"  # Your security group ID
REGION="us-west-2"

# ECR API
aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --vpc-endpoint-type Interface \
    --service-name com.amazonaws.$REGION.ecr.api \
    --subnet-ids $SUBNETS \
    --security-group-ids $SG_ID \
    --private-dns-enabled \
    --region $REGION

# ECR Docker
aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --vpc-endpoint-type Interface \
    --service-name com.amazonaws.$REGION.ecr.dkr \
    --subnet-ids $SUBNETS \
    --security-group-ids $SG_ID \
    --private-dns-enabled \
    --region $REGION

# S3 Gateway
aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --vpc-endpoint-type Gateway \
    --service-name com.amazonaws.$REGION.s3 \
    --route-table-ids rtb-xxxxx \
    --region $REGION

# Secrets Manager
aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --vpc-endpoint-type Interface \
    --service-name com.amazonaws.$REGION.secretsmanager \
    --subnet-ids $SUBNETS \
    --security-group-ids $SG_ID \
    --private-dns-enabled \
    --region $REGION
```

### 2. Run Deployment Scripts

```bash
# Setup IAM roles
./aws/iam/setup-roles.sh

# Deploy application (builds image, pushes to ECR, configures security)
./aws/deploy.sh

# Update security group with required rules
# Edit SG_ID in setup-network.sh first
./aws/setup-network.sh
```

### 3. Create Infrastructure

Follow DEPLOYMENT.md for:
- RDS database (include `--db-name rtb_database`)
- ElastiCache Redis
- Application Load Balancer
- ECS Service

### 4. Run Database Migrations

```bash
# Via bastion host
psql -h <RDS_ENDPOINT> -U rtbadmin -d rtb_database -f migrations/001_create_users_table.sql
psql -h <RDS_ENDPOINT> -U rtbadmin -d rtb_database -f migrations/002_create_products_table.sql
psql -h <RDS_ENDPOINT> -U rtbadmin -d rtb_database -f migrations/003_create_bids_table.sql
psql -h <RDS_ENDPOINT> -U rtbadmin -d rtb_database -f migrations/004_create_orders_table.sql
psql -h <RDS_ENDPOINT> -U rtbadmin -d rtb_database -f migrations/005_create_scoring_parameters_table.sql
psql -h <RDS_ENDPOINT> -U rtbadmin -d rtb_database -f migrations/006_fix_timestamp_timezone.sql
```

## Verification Checklist

- [ ] VPC endpoints exist and have Private DNS enabled
- [ ] Security group has ports 80, 443, 3000 inbound
- [ ] Docker image built for linux/amd64
- [ ] IAM execution role has AmazonECSTaskExecutionRolePolicy
- [ ] RDS database created with name `rtb_database`
- [ ] Task definition registered
- [ ] ECS service created and tasks running
- [ ] ALB target group shows healthy targets
- [ ] `/health` endpoint returns `{"status":"OK"}`
- [ ] Database migrations completed

## Quick Test Commands

```bash
# Check ECS tasks
aws ecs describe-services --cluster rtb-cluster --services rtb-service --region us-west-2 --query 'services[0].{Running:runningCount,Desired:desiredCount}'

# Check target health
aws elbv2 describe-target-health --target-group-arn <ARN> --region us-west-2

# Get ALB DNS
aws elbv2 describe-load-balancers --names rtb-alb --region us-west-2 --query 'LoadBalancers[0].DNSName' --output text

# Test health endpoint
curl http://<ALB-DNS>/health

# Test API endpoints (after migrations)
curl http://<ALB-DNS>/api/products
curl -X POST http://<ALB-DNS>/api/auth/register -H "Content-Type: application/json" -d '{"username":"test","password":"test123"}'
```

## Common Issues

See `FIXES-APPLIED.md` for detailed troubleshooting.

**Tasks won't start?**
- Check security group has port 443 inbound
- Verify image is linux/amd64
- Check VPC endpoints have Private DNS enabled

**ALB timeout?**
- Security group needs port 80 from internet
- Security group needs port 3000 from itself

**Database connection failed?**
- Verify RDS security group allows port 5432 from ECS tasks
- Check database name is `rtb_database`
