#!/bin/bash

# Quick deployment script - Increase DB connection timeouts
# Run after starting Docker Desktop

set -e

REGION="us-west-2"
ECR_REPO="746581495218.dkr.ecr.us-west-2.amazonaws.com/rtb-app"

echo "=========================================="
echo "Deploying Connection Timeout Fix"
echo "=========================================="
echo ""

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running"
  echo "Please start Docker Desktop first"
  exit 1
fi

echo "1. Building Docker image with timeout fixes..."
echo "   - connectionTimeoutMillis: 5s → 10s"
echo "   - acquireTimeoutMillis: 10s → 30s"
echo ""

docker buildx build --platform linux/amd64 -t ${ECR_REPO}:latest .

echo ""
echo "2. Logging into ECR..."

aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin ${ECR_REPO%/*}

echo ""
echo "3. Pushing image to ECR..."

docker push ${ECR_REPO}:latest

echo ""
echo "4. Forcing ECS service update..."

aws ecs update-service \
  --region $REGION \
  --cluster rtb-cluster \
  --service rtb-service \
  --force-new-deployment \
  --query 'service.serviceName' \
  --output text

echo ""
echo "5. Waiting for deployment (3-5 minutes)..."

aws ecs wait services-stable \
  --region $REGION \
  --cluster rtb-cluster \
  --services rtb-service

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Changes applied:"
echo "  ✓ DB connection timeout: 5s → 10s"
echo "  ✓ DB acquire timeout: 10s → 30s"
echo ""
echo "Wait 1 minute, then re-run stress test"
echo ""
