#!/bin/bash

# Enable ECS Auto-Scaling for Demo
# This allows tasks to scale 4-10 based on CPU utilization

set -e

CLUSTER="rtb-cluster"
SERVICE="rtb-service"
REGION="us-west-2"
MIN_CAPACITY=4
MAX_CAPACITY=10
TARGET_CPU=70

echo "======================================"
echo "ENABLING ECS AUTO-SCALING"
echo "======================================"
echo "Cluster: $CLUSTER"
echo "Service: $SERVICE"
echo "Min Tasks: $MIN_CAPACITY"
echo "Max Tasks: $MAX_CAPACITY"
echo "Target CPU: ${TARGET_CPU}%"
echo ""

# Step 1: Register scalable target
echo "Step 1: Registering scalable target..."
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/${CLUSTER}/${SERVICE} \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity $MIN_CAPACITY \
  --max-capacity $MAX_CAPACITY \
  --region $REGION

echo "✓ Scalable target registered"
echo ""

# Step 2: Delete existing policy if it exists
echo "Step 2: Checking for existing policies..."
EXISTING_POLICIES=$(aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/${CLUSTER}/${SERVICE} \
  --region $REGION \
  --query 'ScalingPolicies[?PolicyName==`rtb-cpu-scaling`].PolicyName' \
  --output text)

if [ -n "$EXISTING_POLICIES" ]; then
  echo "Found existing policy 'rtb-cpu-scaling', deleting..."
  aws application-autoscaling delete-scaling-policy \
    --service-namespace ecs \
    --resource-id service/${CLUSTER}/${SERVICE} \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name rtb-cpu-scaling \
    --region $REGION
  echo "✓ Old policy deleted"
else
  echo "No existing policy found"
fi
echo ""

# Step 3: Create new scaling policy
echo "Step 3: Creating CPU-based scaling policy..."
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/${CLUSTER}/${SERVICE} \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name rtb-cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": '${TARGET_CPU}.0',
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleOutCooldown": 60,
    "ScaleInCooldown": 300
  }' \
  --region $REGION

echo "✓ Scaling policy created"
echo ""

# Step 4: Verify configuration
echo "Step 4: Verifying auto-scaling configuration..."
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/${CLUSTER}/${SERVICE} \
  --region $REGION \
  --query 'ScalableTargets[0].[MinCapacity,MaxCapacity]' \
  --output text

echo ""
echo "======================================"
echo "✓ AUTO-SCALING ENABLED"
echo "======================================"
echo ""
echo "Behavior:"
echo "  - When CPU > 70%: Scale OUT (add tasks) within 60s"
echo "  - When CPU < 70%: Scale IN (remove tasks) after 300s"
echo "  - Current tasks: $(aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query 'services[0].runningCount' --output text)"
echo "  - Min/Max: $MIN_CAPACITY/$MAX_CAPACITY tasks"
echo ""
echo "Monitor scaling with:"
echo "  watch -n 5 'aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query services[0].desiredCount'"
echo ""
echo "Or view in AWS Console:"
echo "  https://us-west-2.console.aws.amazon.com/ecs/v2/clusters/${CLUSTER}/services/${SERVICE}"
echo ""
