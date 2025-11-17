#!/bin/bash

STAGING_HOST=$1
DURATION=${2:-60}  # seconds
RATE=${3:-10}      # requests per second

echo "=========================================="
echo "Advanced Load Test"
echo "=========================================="
echo "Target: $STAGING_HOST"
echo "Duration: ${DURATION}s"
echo "Rate: ${RATE} req/s"
echo "=========================================="

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
REQUEST_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    # Health check
    curl -s http://$STAGING_HOST:8080/actuator/health > /dev/null &
    
    # Metrics endpoint
    curl -s http://$STAGING_HOST:8080/actuator/prometheus > /dev/null &
    
    # API calls
    curl -s http://$STAGING_HOST:8080/api/accounts > /dev/null &
    
    REQUEST_COUNT=$((REQUEST_COUNT + 3))
    
    # Print status every 10 requests
    if [ $((REQUEST_COUNT % 30)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        echo "[$ELAPSED s] Sent $REQUEST_COUNT requests..."
    fi
    
    # Control request rate
    sleep $(echo "scale=3; 1/$RATE" | bc)
done

wait

echo ""
echo "=========================================="
echo "✅ Load Test Complete!"
echo "=========================================="
echo "Total Requests: $REQUEST_COUNT"
echo "Duration: ${DURATION}s"
echo "Avg Rate: $(echo "scale=2; $REQUEST_COUNT/$DURATION" | bc) req/s"
echo "=========================================="
