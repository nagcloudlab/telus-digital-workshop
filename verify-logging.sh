#!/bin/bash

STAGING_IP=$1

if [ -z "$STAGING_IP" ]; then
    echo "Usage: ./verify-logging.sh STAGING_IP"
    echo ""
    echo "Example:"
    echo "  export STAGING_IP=\$(cd infrastructure/aws-staging/terraform && terraform output -raw instance_public_ip)"
    echo "  ./verify-logging.sh \$STAGING_IP"
    exit 1
fi

echo "=========================================="
echo "Centralized Logging Verification"
echo "=========================================="
echo "Target: $STAGING_IP"
echo ""

# Test Loki
echo -n "📝 Loki (3100):           "
if curl -sf http://$STAGING_IP:3100/ready > /dev/null; then
    echo "✅ Ready"
else
    echo "❌ Not Ready"
fi

# Test Promtail
echo -n "📤 Promtail (9080):       "
if curl -sf http://$STAGING_IP:9080/metrics > /dev/null; then
    echo "✅ Running"
else
    echo "❌ Not Running"
fi

# Test log collection
echo -n "📋 Log Streams:           "
STREAMS=$(curl -s -G http://$STAGING_IP:3100/loki/api/v1/query \
  --data-urlencode 'query={job="money-transfer"}' \
  --data-urlencode 'limit=1' 2>/dev/null | jq '.data.result | length' 2>/dev/null || echo "0")

if [ "$STREAMS" -gt "0" ]; then
    echo "✅ ($STREAMS active)"
else
    echo "⚠️  No streams yet (generate some traffic)"
fi

# Get sample logs
echo ""
echo "📄 Sample Logs (last 3):"
curl -s -G http://$STAGING_IP:3100/loki/api/v1/query \
  --data-urlencode 'query={job="money-transfer"}' \
  --data-urlencode 'limit=3' 2>/dev/null | jq -r '.data.result[].values[][1]' 2>/dev/null | head -3 || echo "  No logs yet"

echo ""
echo "=========================================="
echo "📍 Access Points:"
echo "  Loki API:        http://$STAGING_IP:3100"
echo "  Promtail:        http://$STAGING_IP:9080/metrics"
echo "  Grafana Explore: http://localhost:3000/explore"
echo ""
echo "🔧 SSH Commands:"
echo "  Loki status:     ssh ubuntu@$STAGING_IP sudo systemctl status loki"
echo "  Promtail status: ssh ubuntu@$STAGING_IP sudo systemctl status promtail"
echo "  Loki logs:       ssh ubuntu@$STAGING_IP sudo journalctl -u loki -f"
echo "  Promtail logs:   ssh ubuntu@$STAGING_IP sudo journalctl -u promtail -f"
echo ""
echo "🧪 Generate test logs:"
echo "  curl http://$STAGING_IP:8080/api/accounts"
echo "  curl http://$STAGING_IP:8080/actuator/health"
echo "=========================================="
