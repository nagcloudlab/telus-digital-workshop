#!/bin/bash

NEW_IP=$1

if [ -z "$NEW_IP" ]; then
    echo "Usage: ./update-targets.sh NEW_IP"
    exit 1
fi

echo "Updating Prometheus targets to: $NEW_IP"

# Update prometheus.yml
sed -i.bak "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/$NEW_IP/g" prometheus/prometheus.yml

echo "✅ Configuration updated!"
echo "Restarting Prometheus..."

docker-compose restart prometheus

echo "✅ Done! Check targets: http://localhost:9090/targets"
