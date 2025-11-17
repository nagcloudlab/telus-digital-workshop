#!/bin/bash
echo "📊 Monitoring Stack Status"
echo "=========================================="
docker-compose ps
echo ""
echo "Container Health:"
docker ps --filter "name=prometheus" --format "{{.Names}}: {{.Status}}"
docker ps --filter "name=grafana" --format "{{.Names}}: {{.Status}}"
docker ps --filter "name=alertmanager" --format "{{.Names}}: {{.Status}}"
