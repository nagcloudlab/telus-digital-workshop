#!/bin/bash

STAGING_IP=$1

if [ -z "$STAGING_IP" ]; then
    echo "Usage: ./verify-jaeger.sh STAGING_IP"
    echo ""
    echo "Example:"
    echo "  export STAGING_IP=\$(cd infrastructure/aws-staging/terraform && terraform output -raw instance_public_ip)"
    echo "  ./verify-jaeger.sh \$STAGING_IP"
    exit 1
fi

echo "=========================================="
echo "Jaeger Installation Verification"
echo "=========================================="
echo "Target: $STAGING_IP"
echo ""

# Test Jaeger UI
echo -n "🌐 Jaeger UI (16686):     "
if curl -sf http://$STAGING_IP:16686/ > /dev/null; then
    echo "✅ Running"
else
    echo "❌ Not accessible"
fi

# Test OTLP HTTP
echo -n "📡 OTLP HTTP (4318):      "
if curl -sf http://$STAGING_IP:4318/ > /dev/null 2>&1 || [ $? -eq 52 ]; then
    echo "✅ Ready"
else
    echo "❌ Not ready"
fi

# Test OTLP gRPC
echo -n "📡 OTLP gRPC (4317):      "
if nc -zv $STAGING_IP 4317 2>&1 | grep -q succeeded; then
    echo "✅ Ready"
else
    echo "⚠️  Cannot verify (nc not installed locally)"
fi

# Test API
echo -n "🎯 Jaeger API:            "
SERVICES=$(curl -s http://$STAGING_IP:16686/api/services 2>/dev/null)
if echo "$SERVICES" | jq -e '.data' > /dev/null 2>&1; then
    SERVICE_COUNT=$(echo "$SERVICES" | jq '.data | length')
    echo "✅ Working ($SERVICE_COUNT services)"
    if [ "$SERVICE_COUNT" -gt "0" ]; then
        echo "$SERVICES" | jq -r '.data[]' | sed 's/^/    - /'
    fi
else
    echo "❌ Not responding"
fi

# Test traces
echo -n "📊 Traces Collected:      "
TRACES=$(curl -s "http://$STAGING_IP:16686/api/traces?service=money-transfer&limit=1" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "0")
if [ "$TRACES" -gt "0" ]; then
    echo "✅ $TRACES found"
else
    echo "⚠️  No traces yet (this is normal if app not deployed)"
fi

echo ""
echo "=========================================="
echo "📍 Access Points:"
echo "  Jaeger UI:    http://$STAGING_IP:16686"
echo "  OTLP HTTP:    http://$STAGING_IP:4318"
echo "  OTLP gRPC:    http://$STAGING_IP:4317"
echo ""
echo "🔧 SSH Commands:"
echo "  Status:       ssh ubuntu@$STAGING_IP sudo systemctl status jaeger"
echo "  Logs:         ssh ubuntu@$STAGING_IP sudo journalctl -u jaeger -f"
echo "  Restart:      ssh ubuntu@$STAGING_IP sudo systemctl restart jaeger"
echo ""
echo "🧪 Generate Test Trace:"
echo "  curl -X POST http://$STAGING_IP:8080/api/transfers \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"fromAccountNumber\":\"ACC001\",\"toAccountNumber\":\"ACC002\",\"amount\":100}'"
echo "=========================================="
