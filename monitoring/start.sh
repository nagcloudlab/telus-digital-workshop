#!/bin/bash
echo "🚀 Starting Monitoring Stack..."
docker compose up -d

echo ""
echo "Waiting for services to be healthy..."
sleep 15

docker compose ps

echo ""
echo "=========================================="
echo "✅ Monitoring Stack Started"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  📊 Grafana:      http://localhost:3000 (admin/admin123)"
echo "  📈 Prometheus:   http://localhost:9090"
echo "  🔔 AlertManager: http://localhost:9093"
echo ""
echo "Health checks:"
docker compose ps --format "{{.Name}}: {{.Status}}"
echo "=========================================="
