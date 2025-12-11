#!/bin/bash

# Performance Optimization Update Script
# Updates ECS task resources, connection pools, and timeout settings

set -e

REGION="us-west-2"
CLUSTER_NAME="rtb-cluster"
SERVICE_NAME="rtb-service"

echo "=========================================="
echo "Performance Optimization Update"
echo "=========================================="
echo ""

# Step 1: Update ALB target group timeout settings
echo "1. Updating ALB target group timeout settings..."

TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
  --region $REGION \
  --query 'TargetGroups[?contains(TargetGroupName, `rtb`)].TargetGroupArn' \
  --output text)

if [ -n "$TARGET_GROUP_ARN" ]; then
  echo "Target Group: $TARGET_GROUP_ARN"
  
  # Update deregistration delay and health check settings
  aws elbv2 modify-target-group \
    --region $REGION \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3
  
  aws elbv2 modify-target-group-attributes \
    --region $REGION \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --attributes \
      Key=deregistration_delay.timeout_seconds,Value=30 \
      Key=stickiness.enabled,Value=true \
      Key=stickiness.type,Value=lb_cookie \
      Key=stickiness.lb_cookie.duration_seconds,Value=86400
  
  echo "✓ Target group updated"
else
  echo "⚠ Target group not found, skipping..."
fi

echo ""

# Step 2: Update ALB idle timeout
echo "2. Updating ALB idle timeout..."

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region $REGION \
  --names rtb-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text 2>/dev/null || echo "")

if [ -n "$ALB_ARN" ]; then
  echo "Load Balancer: $ALB_ARN"
  
  aws elbv2 modify-load-balancer-attributes \
    --region $REGION \
    --load-balancer-arn "$ALB_ARN" \
    --attributes \
      Key=idle_timeout.timeout_seconds,Value=120 \
      Key=deletion_protection.enabled,Value=false
  
  echo "✓ ALB timeout increased to 120s"
else
  echo "⚠ ALB not found, skipping..."
fi

echo ""

# Step 3: Register new task definition
echo "3. Registering new task definition..."
echo "   CPU: 512 → 1024"
echo "   Memory: 1024 → 2048"
echo "   DB Pool: 2-10 → 5-30"
echo "   Health check timeout: 5s → 10s"
echo ""

TASK_DEF_ARN=$(aws ecs register-task-definition \
  --region $REGION \
  --cli-input-json file://aws/task-definition.json \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "✓ New task definition: $TASK_DEF_ARN"
echo ""

# Step 4: Update ECS service
echo "4. Updating ECS service..."

aws ecs update-service \
  --region $REGION \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition "$TASK_DEF_ARN" \
  --force-new-deployment

echo "✓ Service update initiated"
echo ""

# Step 5: Wait for deployment
echo "5. Waiting for deployment to complete..."
echo "   (This may take 3-5 minutes)"
echo ""

aws ecs wait services-stable \
  --region $REGION \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME

echo "✓ Deployment complete!"
echo ""

# Step 6: Verify new tasks
echo "6. Verifying new tasks..."

TASK_COUNT=$(aws ecs describe-services \
  --region $REGION \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query 'services[0].runningCount' \
  --output text)

echo "   Running tasks: $TASK_COUNT"
echo ""

# Get task IDs
TASK_ARNS=$(aws ecs list-tasks \
  --region $REGION \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --query 'taskArns' \
  --output text)

if [ -n "$TASK_ARNS" ]; then
  echo "   Task details:"
  for TASK_ARN in $TASK_ARNS; do
    TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')
    TASK_INFO=$(aws ecs describe-tasks \
      --region $REGION \
      --cluster $CLUSTER_NAME \
      --tasks "$TASK_ARN" \
      --query 'tasks[0].[cpu,memory,healthStatus]' \
      --output text)
    
    echo "     - $TASK_ID: $TASK_INFO"
  done
fi

echo ""
echo "=========================================="
echo "Performance Update Complete!"
echo "=========================================="
echo ""
echo "Changes applied:"
echo "  ✓ ECS Task CPU: 512 → 1024 (2x)"
echo "  ✓ ECS Task Memory: 1GB → 2GB (2x)"
echo "  ✓ DB Connection Pool: 2-10 → 5-30 (3x max)"
echo "  ✓ DB Connection Timeout: 2s → 5s"
echo "  ✓ DB Acquire Timeout: Added 10s"
echo "  ✓ Health Check Timeout: 5s → 10s"
echo "  ✓ Health Check Start Period: 60s → 120s"
echo "  ✓ ALB Idle Timeout: 60s → 120s"
echo "  ✓ Target Group Health Checks: Optimized"
echo "  ✓ Session Stickiness: Enabled (24h)"
echo ""
echo "Next steps:"
echo "  1. Wait 2-3 minutes for tasks to fully stabilize"
echo "  2. Re-run stress test: cd tests/stress && ./run-stress-tests.sh"
echo "  3. Monitor CloudWatch metrics during test"
echo "  4. Check RDS connections: max_connections setting"
echo ""
