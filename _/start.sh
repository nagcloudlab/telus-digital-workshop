#!/bin/bash
echo "🚀 Starting Monitoring Stack..."
docker-compose up -d
echo "✅ Stack started!"
echo ""
echo "Access URLs:"
echo "  Prometheus:   http://localhost:9090"
echo "  Grafana:      http://localhost:3000 (admin/admin123)"
echo "  AlertManager: http://localhost:9093"
echo ""
docker-compose ps
