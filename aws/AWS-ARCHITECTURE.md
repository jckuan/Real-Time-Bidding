# AWS Architecture & Services

## AWS Services Used

### Compute & Container Services
1. **Amazon ECR (Elastic Container Registry)**
   - Stores Docker images
   - Repository: `746581495218.dkr.ecr.us-west-2.amazonaws.com/rtb-app`
   - Image scanning enabled for security

2. **Amazon ECS (Elastic Container Service) with Fargate**
   - Cluster: `rtb-cluster`
   - Service: `rtb-service`
   - Serverless container orchestration (no EC2 management)
   - CPU: 512, Memory: 1024 MB per task
   - Runs Node.js application on port 3000

### Networking & Load Balancing
3. **Application Load Balancer (ALB)**
   - Name: `rtb-alb`
   - DNS: `rtb-alb-1080675720.us-west-2.elb.amazonaws.com`
   - Distributes HTTP traffic (port 80) to ECS tasks (port 3000)
   - Target Group: `rtb-targets`
   - Health checks: `/health` endpoint

4. **Amazon VPC (Virtual Private Cloud)**
   - VPC ID: `vpc-0449dd4efd076077e` (default VPC)
   - Subnets: `subnet-06160b4d3e6bd1629`, `subnet-01685448c8b5069dc`
   - Security Group: `sg-0f45b30eeb2ea2d09`

5. **VPC Endpoints (Interface & Gateway)**
   - ECR API Endpoint (com.amazonaws.us-west-2.ecr.api)
   - ECR Docker Endpoint (com.amazonaws.us-west-2.ecr.dkr)
   - S3 Gateway Endpoint (com.amazonaws.us-west-2.s3)
   - Secrets Manager Endpoint (com.amazonaws.us-west-2.secretsmanager)
   - Purpose: Private connectivity to AWS services without internet gateway/NAT

### Database & Caching
6. **Amazon RDS PostgreSQL**
   - Instance: `rtb-db`
   - Engine: PostgreSQL 15.8
   - Instance Class: db.t3.micro
   - Database Name: `rtb_database`
   - Endpoint: `rtb-db.cxs8mgm8ufcp.us-west-2.rds.amazonaws.com:5432`
   - Storage: 20GB gp3, encrypted

7. **Amazon ElastiCache Redis**
   - Cluster: `rtb-redis`
   - Engine: Redis 7.0
   - Node Type: cache.t3.micro
   - Endpoint: `rtb-redis.laocea.0001.usw2.cache.amazonaws.com:6379`
   - Purpose: Real-time leaderboards (Sorted Sets), session management

### Security & Secrets Management
8. **AWS Secrets Manager**
   - `rtb/db/username` - Database username
   - `rtb/db/password` - Database password
   - `rtb/jwt/secret` - JWT signing secret
   - Accessed by ECS tasks via IAM roles

9. **AWS IAM (Identity & Access Management)**
   - **RTB-ecsTaskExecutionRole** - Allows ECS to pull images, write logs, retrieve secrets
   - **RTB-ecsTaskRole** - Allows application to write CloudWatch logs
   - Policies: AmazonECSTaskExecutionRolePolicy, SecretsManagerAccessPolicy, CloudWatchLogsPolicy

### Monitoring & Logging
10. **Amazon CloudWatch Logs**
    - Log Group: `/ecs/rtb-app`
    - Retention: 7 days
    - Captures application logs and ECS task outputs

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                   │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   │ HTTP (Port 80)
                                   ▼
                    ┌──────────────────────────────┐
                    │  Application Load Balancer   │
                    │      (rtb-alb)               │
                    │  rtb-alb-1080675720...       │
                    │                              │
                    │  Target Group: rtb-targets   │
                    └──────────────┬───────────────┘
                                   │
                                   │ Port 3000
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    VPC (vpc-0449dd4efd076077e)                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │            Security Group (sg-0f45b30eeb2ea2d09)                │    │
│  │  Rules:                                                         │    │
│  │    • Port 80 from 0.0.0.0/0 (ALB ← Internet)                    │    │
│  │    • Port 443 from same SG (ECS → VPC Endpoints)                │    │
│  │    • Port 3000 from same SG (ECS ← ALB)                         │    │
│  │    • Port 5432 from same SG (RDS ← ECS)                         │    │
│  │    • Port 6379 from same SG (Redis ← ECS)                       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │          ECS Cluster: rtb-cluster (Fargate)                     │    │
│  │  ┌────────────────────────────────────────────────────────┐     │    │
│  │  │  ECS Service: rtb-service                              │     │    │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │     │    │
│  │  │  │  ECS Task 1  │  │  ECS Task 2  │  │  ECS Task N  │  │     │    │
│  │  │  │              │  │              │  │              │  │     │    │
│  │  │  │  Container:  │  │  Container:  │  │  Container:  │  │     │    │
│  │  │  │  rtb-app     │  │  rtb-app     │  │  rtb-app     │  │     │    │
│  │  │  │  Port: 3000  │  │  Port: 3000  │  │  Port: 3000  │  │     │    │
│  │  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │     │    │
│  │  │         │                 │                 │          │     │    │
│  │  │         └─────────────────┴─────────────────┘          │     │    │
│  │  │                           │                            │     │    │
│  │  │              Uses IAM Roles for Auth                   │     │    │
│  │  │              • RTB-ecsTaskExecutionRole                │     │    │
│  │  │              • RTB-ecsTaskRole                         │     │    │
│  │  └────────────────────────────┬───────────────────────────┘     │    │
│  └───────────────────────────────┼─────────────────────────────────┘    │
│                                  │                                      │
│                     ┌────────────┼────────────┐                         │
│                     │            │            │                         │
│                     ▼            ▼            ▼                         │
│         ┌───────────────┐  ┌──────────┐  ┌─────────────┐                │
│         │  RDS          │  │ElastiCache│ │  VPC        │                │
│         │  PostgreSQL   │  │  Redis    │ │  Endpoints  │                │
│         │               │  │           │ │             │                │
│         │  rtb_database │  │  ZSET for │ │  • ECR API  │                │
│         │               │  │Leaderboard│ │  • ECR Dkr  │                │
│         │  Port: 5432   │  │           │ │  • S3       │                │
│         │               │  │Port: 6379 │ │  • Secrets  │                │
│         └───────────────┘  └──────────-┘ │    Manager  │                │
│                                          └─────┬───────┘                │
│                                                │                        │
└────────────────────────────────────────────────┼────────────────────────┘
                                                 │
                          Port 443 (Private DNS enabled)
                                                 │
                                                 ▼
                    ┌────────────────────────────────────────┐
                    │        AWS Services (Private)          │
                    │                                        │
                    │  ┌──────────────┐  ┌───────────────┐   │
                    │  │    ECR       │  │    Secrets    │   │
                    │  │  (Docker     │  │    Manager    │   │
                    │  │   Images)    │  │  (Credentials)│   │
                    │  └──────────────┘  └───────────────┘   │
                    │                                        │
                    │  ┌──────────────┐  ┌───────────────┐   │
                    │  │  CloudWatch  │  │      S3       │   │
                    │  │    Logs      │  │  (ECR layers) │   │
                    │  │ /ecs/rtb-app │  │               │   │
                    │  └──────────────┘  └───────────────┘   │
                    └────────────────────────────────────────┘
```

---

## Data Flow Diagram

### 1. Container Deployment Flow
```
Developer
    │
    │ 1. docker build --platform linux/amd64
    ▼
Local Docker Image
    │
    │ 2. docker push
    ▼
Amazon ECR
    │
    │ 3. ECS pulls image via VPC Endpoint (port 443)
    ▼
ECS Fargate Task
    │
    │ 4. Task starts with IAM role credentials
    │ 5. Retrieves secrets from Secrets Manager
    ▼
Running Container (Node.js App on port 3000)
```

### 2. User Request Flow
```
User Browser
    │
    │ HTTP GET/POST
    ▼
Application Load Balancer (Port 80)
    │
    │ Health Check: /health
    │ Forward to healthy targets
    ▼
ECS Task (Port 3000)
    │
    ├──► PostgreSQL RDS (Port 5432)
    │      • User authentication
    │      • Product data
    │      • Bid records
    │      • Order transactions
    │
    ├──► Redis ElastiCache (Port 6379)
    │      • Real-time leaderboard (ZSET)
    │      • Session cache
    │      • Rate limiting counters
    │
    └──► CloudWatch Logs
           • Application logs
           • Error tracking
```

### 3. Secrets & Configuration Flow
```
Deploy Script (deploy.sh)
    │
    │ 1. Generate secure passwords
    ▼
AWS Secrets Manager
    • rtb/db/username
    • rtb/db/password
    • rtb/jwt/secret
    │
    │ 2. ECS Task Execution Role reads secrets
    ▼
ECS Task Environment Variables
    │
    │ 3. Application uses at runtime
    ▼
Database Connection & JWT Signing
```

---

## Security Architecture

### Network Isolation
- **Private Subnets**: ECS tasks run in private subnets (no public IPs)
- **VPC Endpoints**: Private connectivity to AWS services
- **Security Group**: Single security group with minimal required ports
- **No NAT Gateway**: VPC endpoints eliminate need for internet routing

### IAM Role Separation
```
RTB-ecsTaskExecutionRole (Infrastructure)
    ├─ Pull images from ECR
    ├─ Retrieve secrets from Secrets Manager
    └─ Write container logs to CloudWatch

RTB-ecsTaskRole (Application)
    └─ Write application logs to CloudWatch
```

### Secrets Management
- Database credentials stored in Secrets Manager (not environment variables)
- JWT secret auto-generated with `openssl rand -base64 32`
- Task definition references secrets by ARN
- Secrets retrieved at container startup

---

## Scaling Strategy

### Horizontal Scaling
```
Low Traffic                  High Traffic (Auto-scaling)
┌──────────┐                ┌──────────┐  ┌──────────┐  ┌──────────┐
│ ECS Task │                │ ECS Task │  │ ECS Task │  │ ECS Task │
│          │    ──────>     │          │  │          │  │          │
│ 1 Task   │                │          │  │          │  │    ...   │
└──────────┘                └──────────┘  └──────────┘  └──────────┘
                                  ↑
                                  │
                            ECS Service Auto-scaling
                            (Based on CPU/Memory metrics)
```

### Database Scaling
- **RDS**: Can scale vertically (instance class) or add read replicas
- **Redis**: Can scale to cluster mode for partitioning
- **Current**: db.t3.micro, cache.t3.micro (suitable for development/testing)

---

## Cost Breakdown

| Service | Configuration | Estimated Monthly Cost |
|---------|--------------|------------------------|
| ECS Fargate | 512 CPU, 1024 MB, 2 tasks, 24/7 | ~$30 |
| RDS PostgreSQL | db.t3.micro, 20GB gp3 | ~$15 |
| ElastiCache Redis | cache.t3.micro | ~$12 |
| Application Load Balancer | 1 ALB + LCU usage | ~$20 |
| VPC Endpoints | 4 endpoints | ~$28 |
| CloudWatch Logs | 7 day retention | ~$5 |
| Secrets Manager | 3 secrets | ~$1.20 |
| **TOTAL** | | **~$111/month** |

*Note: Costs are estimates for us-west-2 region, assuming moderate traffic*

---

## Deployment Checklist

✅ IAM roles created (RTB-ecsTaskExecutionRole, RTB-ecsTaskRole)  
✅ Docker image built for linux/amd64  
✅ ECR repository created and image pushed  
✅ RDS database created with name `rtb_database`  
✅ ElastiCache Redis cluster created  
✅ VPC endpoints created (ECR, S3, Secrets Manager)  
✅ Security group configured (ports 80, 443, 3000, 5432, 6379)  
✅ Secrets stored in Secrets Manager  
✅ ECS cluster and service created  
✅ Application Load Balancer configured  
✅ Task definition registered  
✅ Health checks passing  
✅ System accessible via ALB DNS  

**Status**: ✅ **PRODUCTION READY**
