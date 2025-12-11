#!/bin/bash

# Fix database saturation - Option 1: Upgrade RDS instance
# Upgrades from db.t3.micro to db.t3.small for higher max_connections

set -e

REGION="us-west-2"
DB_INSTANCE="rtb-db"

echo "=========================================="
echo "RDS Instance Upgrade (Quick Fix)"
echo "=========================================="
echo ""

echo "Current: db.t3.micro (~80 max_connections)"
echo "Upgrade: db.t3.small (~200 max_connections)"
echo ""
echo "This will cause ~30 seconds of downtime."
read -p "Continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "Upgrading RDS instance..."

aws rds modify-db-instance \
  --region $REGION \
  --db-instance-identifier $DB_INSTANCE \
  --db-instance-class db.t3.small \
  --apply-immediately \
  --no-cli-pager

echo ""
echo "✓ Upgrade initiated"
echo ""
echo "Waiting for modification to complete (3-5 minutes)..."

aws rds wait db-instance-available \
  --region $REGION \
  --db-instance-identifier $DB_INSTANCE

echo ""
echo "=========================================="
echo "RDS Upgrade Complete!"
echo "=========================================="
echo ""
echo "Instance class: db.t3.micro → db.t3.small"
echo "Max connections: ~80 → ~200"
echo "Monthly cost: ~$12.41 → ~$24.82"
echo ""
echo "ECS tasks will reconnect automatically."
echo "Wait 1 minute, then re-run stress test."
echo ""
