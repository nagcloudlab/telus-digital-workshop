#!/bin/bash
echo "=========================================="
echo "📊 Monitoring Stack Status"
echo "=========================================="
echo ""

# Container status
echo "🐳 Containers:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "💾 Disk Usage:"
docker system df

echo ""
echo "🔍 Health Checks:"
echo -n "  Prometheus:   "
curl -sf http://localhost:9090/-/healthy && echo "✅ Healthy" || echo "❌ Unhealthy"

echo -n "  Grafana:      "
curl -sf http://localhost:3000/api/health && echo "✅ Healthy" || echo "❌ Unhealthy"

echo -n "  AlertManager: "
curl -sf http://localhost:9093/-/healthy && echo "✅ Healthy" || echo "❌ Unhealthy"

echo ""
echo "=========================================="
