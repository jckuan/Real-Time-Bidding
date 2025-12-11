#!/bin/bash

# Create CloudWatch Dashboard for Demo
# This creates a dashboard showing key metrics for your demo video

DASHBOARD_NAME="RTB-Demo-Dashboard"
CLUSTER_NAME="rtb-cluster"
SERVICE_NAME="rtb-service"
DB_INSTANCE="rtb-db"
CACHE_CLUSTER="rtb-redis"
ALB_ARN_SUFFIX="app/rtb-alb/61f1c3d8f6f6b7e1"
TARGET_GROUP_ARN_SUFFIX="targetgroup/rtb-tg/8f5e0d5a6c4b3d2e"
REGION="us-west-2"

echo "Creating CloudWatch Dashboard: $DASHBOARD_NAME"

aws cloudwatch put-dashboard \
  --dashboard-name "$DASHBOARD_NAME" \
  --region "$REGION" \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/ECS", "CPUUtilization", { "stat": "Average", "label": "Avg CPU" } ],
            [ "...", { "stat": "Maximum", "label": "Max CPU" } ]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-west-2",
          "title": "ECS CPU Utilization",
          "period": 60,
          "yAxis": {
            "left": {
              "min": 0,
              "max": 100
            }
          },
          "annotations": {
            "horizontal": [
              {
                "label": "Target 70%",
                "value": 70
              }
            ]
          }
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/ECS", "MemoryUtilization", { "stat": "Average" } ]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-west-2",
          "title": "ECS Memory Utilization",
          "period": 60,
          "yAxis": {
            "left": {
              "min": 0,
              "max": 100
            }
          }
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/ApplicationELB", "RequestCount", { "stat": "Sum", "label": "Total Requests" } ],
            [ ".", "TargetResponseTime", { "stat": "Average", "label": "Avg Response Time", "yAxis": "right" } ]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-west-2",
          "title": "ALB Request Count & Response Time",
          "period": 60
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", { "stat": "Sum", "label": "2xx Success", "color": "#2ca02c" } ],
            [ ".", "HTTPCode_Target_4XX_Count", { "stat": "Sum", "label": "4xx Client Error", "color": "#ff7f0e" } ],
            [ ".", "HTTPCode_Target_5XX_Count", { "stat": "Sum", "label": "5xx Server Error", "color": "#d62728" } ]
          ],
          "view": "timeSeries",
          "stacked": true,
          "region": "us-west-2",
          "title": "ALB HTTP Response Codes",
          "period": 60
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/RDS", "DatabaseConnections", { "stat": "Average" } ],
            [ "...", { "stat": "Maximum" } ]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-west-2",
          "title": "RDS Database Connections",
          "period": 60,
          "annotations": {
            "horizontal": [
              {
                "label": "Max Connections (~225)",
                "value": 225
              }
            ]
          }
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/RDS", "CPUUtilization", { "stat": "Average" } ]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-west-2",
          "title": "RDS CPU Utilization",
          "period": 60,
          "yAxis": {
            "left": {
              "min": 0,
              "max": 100
            }
          }
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/ElastiCache", "CPUUtilization", { "stat": "Average" } ],
            [ ".", "NetworkBytesIn", { "stat": "Sum", "yAxis": "right" } ],
            [ ".", "NetworkBytesOut", { "stat": "Sum", "yAxis": "right" } ]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-west-2",
          "title": "Redis Performance",
          "period": 60
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/ECS", "RunningTasksCount", { "stat": "Average", "label": "Running Tasks" } ]
          ],
          "view": "timeSeries",
          "stacked": false,
          "region": "us-west-2",
          "title": "ECS Task Count (for Auto-Scaling Demo)",
          "period": 60,
          "annotations": {
            "horizontal": [
              {
                "label": "Current: 3 tasks",
                "value": 3
              }
            ]
          }
        }
      }
    ]
  }'

if [ $? -eq 0 ]; then
  echo "✓ Dashboard created successfully!"
  echo ""
  echo "View your dashboard at:"
  echo "https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards:name=${DASHBOARD_NAME}"
  echo ""
  echo "📊 Dashboard includes:"
  echo "  - ECS CPU & Memory Utilization"
  echo "  - ALB Request Count & Response Time"
  echo "  - HTTP Response Code Distribution"
  echo "  - RDS Connections & CPU"
  echo "  - Redis Performance"
  echo "  - ECS Task Count (for auto-scaling visibility)"
  echo ""
  echo "💡 TIP: Open this dashboard in a browser window during your demo recording"
else
  echo "✗ Failed to create dashboard"
  exit 1
fi
