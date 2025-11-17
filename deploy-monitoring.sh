#!/bin/bash

# Get EC2 IP
if [ -z "$STAGING_IP" ]; then
    echo "Error: STAGING_IP not set"
    echo "Run: export STAGING_IP=your_ec2_ip"
    exit 1
fi

SSH_KEY="${SSH_KEY:-~/.ssh/id_rsa}"

echo "=========================================="
echo "🚀 Deploying Monitoring Stack to EC2"
echo "=========================================="
echo "Target: ubuntu@$STAGING_IP"
echo ""

# Create directory on EC2
echo "📁 Creating directories..."
ssh -i $SSH_KEY ubuntu@$STAGING_IP "mkdir -p ~/monitoring"

# Copy monitoring directory
echo "📦 Copying monitoring stack..."
scp -i $SSH_KEY -r monitoring/* ubuntu@$STAGING_IP:~/monitoring/

# Start monitoring stack
echo "🚀 Starting monitoring stack..."
ssh -i $SSH_KEY ubuntu@$STAGING_IP << 'ENDSSH'
cd ~/monitoring
docker compose up -d
echo ""
echo "Waiting for services to start..."
sleep 15
docker compose ps
ENDSSH

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  📊 Grafana:      http://$STAGING_IP:3000 (admin/admin123)"
echo "  📈 Prometheus:   http://$STAGING_IP:9090"
echo "  🔔 AlertManager: http://$STAGING_IP:9093"
echo "  💻 Application:  http://$STAGING_IP:8080"
echo ""
echo "Check status:"
echo "  ssh -i $SSH_KEY ubuntu@$STAGING_IP 'cd ~/monitoring && docker compose ps'"
echo ""
