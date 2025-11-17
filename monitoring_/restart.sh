#!/bin/bash
echo "🔄 Restarting Monitoring Stack..."
docker-compose restart
echo "✅ Stack restarted!"
docker-compose ps
