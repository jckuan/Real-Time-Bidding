#!/bin/bash

# View Stress Test Results
# Displays summary of latest test results

set -e

RESULTS_DIR="./stress-results"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "Stress Test Results Viewer"
echo "==========================================${NC}"
echo ""

# Check if results directory exists
if [ ! -d "$RESULTS_DIR" ]; then
  echo -e "${RED}No results directory found${NC}"
  echo "Run a stress test first: ./run-stress-tests.sh"
  exit 1
fi

# List available summary files
SUMMARIES=($(ls -t "$RESULTS_DIR"/*-summary.json 2>/dev/null))

if [ ${#SUMMARIES[@]} -eq 0 ]; then
  echo -e "${RED}No summary files found${NC}"
  echo "Run a stress test first: ./run-stress-tests.sh"
  exit 1
fi

echo "Available test results (most recent first):"
echo ""

for i in "${!SUMMARIES[@]}"; do
  FILE="${SUMMARIES[$i]}"
  FILENAME=$(basename "$FILE")
  TIMESTAMP=$(echo "$FILENAME" | grep -o '[0-9]\{8\}-[0-9]\{6\}' || echo "unknown")
  TEST_TYPE=$(echo "$FILENAME" | sed 's/-[0-9]\{8\}-[0-9]\{6\}-summary.json//' || echo "unknown")
  
  echo -e "${YELLOW}[$i]${NC} $TEST_TYPE (${TIMESTAMP})"
done

echo ""
read -p "Select test result to view [0-${#SUMMARIES[@]}-1] or 'q' to quit: " choice

if [ "$choice" = "q" ]; then
  exit 0
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -ge "${#SUMMARIES[@]}" ]; then
  echo -e "${RED}Invalid choice${NC}"
  exit 1
fi

SELECTED="${SUMMARIES[$choice]}"

echo ""
echo -e "${BLUE}=========================================="
echo "Test Results: $(basename "$SELECTED")"
echo "==========================================${NC}"
echo ""

# Parse and display key metrics
if command -v jq &> /dev/null; then
  echo -e "${GREEN}Summary Metrics:${NC}"
  echo ""
  
  # Extract key metrics
  CHECKS_PASSED=$(jq -r '.metrics.checks.values.passes // 0' "$SELECTED")
  CHECKS_FAILED=$(jq -r '.metrics.checks.values.fails // 0' "$SELECTED")
  CHECKS_TOTAL=$((CHECKS_PASSED + CHECKS_FAILED))
  
  HTTP_REQS=$(jq -r '.metrics.http_reqs.values.count // 0' "$SELECTED")
  HTTP_FAILED=$(jq -r '.metrics.http_req_failed.values.passes // 0' "$SELECTED")
  HTTP_SUCCESS=$((HTTP_REQS - HTTP_FAILED))
  
  BID_SUCCESS=$(jq -r '.metrics.bid_success_rate.values.count // 0' "$SELECTED")
  BID_FAILURE=$(jq -r '.metrics.bid_failure_rate.values.count // 0' "$SELECTED")
  
  DURATION=$(jq -r '.metrics.iteration_duration.values.avg // 0' "$SELECTED")
  P95_DURATION=$(jq -r '.metrics.iteration_duration.values["p(95)"] // 0' "$SELECTED")
  
  VUS_MAX=$(jq -r '.metrics.vus_max.values.max // 0' "$SELECTED")
  ITERATIONS=$(jq -r '.metrics.iterations.values.count // 0' "$SELECTED")
  
  echo -e "${YELLOW}Virtual Users:${NC}"
  echo "  Max concurrent: $VUS_MAX"
  echo "  Total iterations: $ITERATIONS"
  echo ""
  
  echo -e "${YELLOW}HTTP Requests:${NC}"
  echo "  Total requests: $HTTP_REQS"
  echo "  Success: $HTTP_SUCCESS ($(awk "BEGIN {printf \"%.1f\", ($HTTP_SUCCESS/$HTTP_REQS)*100}")%)"
  echo "  Failed: $HTTP_FAILED ($(awk "BEGIN {printf \"%.1f\", ($HTTP_FAILED/$HTTP_REQS)*100}")%)"
  echo ""
  
  echo -e "${YELLOW}Bid Operations:${NC}"
  echo "  Successful bids: $BID_SUCCESS"
  echo "  Failed bids: $BID_FAILURE"
  if [ "$BID_SUCCESS" -gt 0 ]; then
    echo "  Success rate: $(awk "BEGIN {printf \"%.1f\", ($BID_SUCCESS/($BID_SUCCESS+$BID_FAILURE))*100}")%"
  fi
  echo ""
  
  echo -e "${YELLOW}Performance:${NC}"
  echo "  Avg iteration: $(awk "BEGIN {printf \"%.2f\", $DURATION/1000}")s"
  echo "  P95 iteration: $(awk "BEGIN {printf \"%.2f\", $P95_DURATION/1000}")s"
  echo ""
  
  echo -e "${YELLOW}Checks:${NC}"
  echo "  Passed: $CHECKS_PASSED"
  echo "  Failed: $CHECKS_FAILED"
  if [ "$CHECKS_TOTAL" -gt 0 ]; then
    echo "  Success rate: $(awk "BEGIN {printf \"%.1f\", ($CHECKS_PASSED/$CHECKS_TOTAL)*100}")%"
  fi
  echo ""
  
  # Check thresholds
  echo -e "${YELLOW}Thresholds:${NC}"
  jq -r '.root_group.checks[] | "  \(.name): \(if .passes > 0 then "✓ PASS" else "✗ FAIL" end)"' "$SELECTED" 2>/dev/null || echo "  No threshold data"
  
else
  # Fallback if jq not available
  echo -e "${YELLOW}Install jq for better formatting: brew install jq${NC}"
  echo ""
  cat "$SELECTED"
fi

echo ""
echo -e "${BLUE}=========================================="
echo "Full JSON: $SELECTED"
echo "==========================================${NC}"
echo ""

