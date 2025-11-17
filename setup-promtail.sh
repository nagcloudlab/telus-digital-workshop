#!/bin/bash

set -e

echo "=========================================="
echo "Installing Promtail on EC2"
echo "=========================================="
echo ""

# Download Promtail
echo "📥 Downloading Promtail v2.9.3..."
cd /tmp
wget -q https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip

if [ ! -f "promtail-linux-amd64.zip" ]; then
    echo "❌ Failed to download Promtail"
    exit 1
fi

unzip -q promtail-linux-amd64.zip

# Install binary
echo "⚙️  Installing Promtail binary..."
chmod +x promtail-linux-amd64
sudo mv promtail-linux-amd64 /usr/local/bin/promtail

# Verify installation
echo "✅ Verifying installation..."
/usr/local/bin/promtail --version

# Configure Docker to use json-file logging
echo "🐳 Configuring Docker logging..."
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker
echo "🔄 Restarting Docker daemon..."
sudo systemctl restart docker

# Wait for Docker to restart
sleep 5

# Redeploy application with new logging driver
echo "🔄 Redeploying application..."
if docker ps -a | grep -q money-transfer-staging; then
    docker stop money-transfer-staging || true
    docker rm money-transfer-staging || true
    
    # Redeploy
    if [ -f /opt/money-transfer/deploy.sh ]; then
        /opt/money-transfer/deploy.sh latest
        echo "✅ Application redeployed"
    else
        echo "⚠️  Warning: deploy.sh not found, skipping app redeployment"
    fi
    
    # Wait for app to start
    echo "⏳ Waiting for application to start..."
    sleep 30
fi

# Create Promtail config directory
echo "📁 Creating Promtail configuration..."
sudo mkdir -p /etc/promtail

# Create Promtail configuration
sudo tee /etc/promtail/config.yml > /dev/null << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0
  log_level: info

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  # Docker Container Logs
  - job_name: docker-containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: money-transfer
          environment: staging
          host: ec2-staging
          __path__: /var/lib/docker/containers/*/*-json.log
    
    pipeline_stages:
      # Parse Docker's JSON wrapper
      - json:
          expressions:
            output: log
            stream: stream
            timestamp: time
      
      # Parse application JSON from 'log' field
      - json:
          expressions:
            level: level
            message: message
            logger: logger_name
            thread: thread_name
            traceId: traceId
            spanId: spanId
          source: output
      
      # Add labels
      - labels:
          level:
          stream:
      
      # Set timestamp
      - timestamp:
          source: timestamp
          format: RFC3339Nano
      
      # Output message
      - output:
          source: message

  # System Logs (optional)
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: ec2-staging
          __path__: /var/log/*.log
EOF

# Create systemd service (run as root for Docker log access)
echo "🚀 Creating systemd service..."
sudo tee /etc/systemd/system/promtail.service > /dev/null << 'EOF'
[Unit]
Description=Promtail Log Shipper
Documentation=https://grafana.com/docs/loki/
After=network.target loki.service

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=on-failure
RestartSec=20
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "🔄 Starting Promtail service..."
sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail

# Wait for Promtail to start
echo "⏳ Waiting for Promtail to be ready..."
sleep 10

# Verify Promtail is running
if sudo systemctl is-active --quiet promtail; then
    echo ""
    echo "=========================================="
    echo "✅ Promtail installed successfully!"
    echo "=========================================="
    echo "Status:    Active"
    echo "Port:      9080"
    echo "Config:    /etc/promtail/config.yml"
    echo "Positions: /tmp/positions.yaml"
    echo ""
    echo "📋 Useful Commands:"
    echo "  Status:  sudo systemctl status promtail"
    echo "  Logs:    sudo journalctl -u promtail -f"
    echo "  Restart: sudo systemctl restart promtail"
    echo ""
    echo "🧪 Test:"
    echo "  curl http://localhost:9080/metrics"
    echo "  cat /tmp/positions.yaml"
    echo ""
    
    # Check if logs are being collected
    sleep 5
    if [ -f /tmp/positions.yaml ]; then
        echo "📊 Positions file created:"
        cat /tmp/positions.yaml | head -5
    fi
    
    echo "=========================================="
else
    echo ""
    echo "❌ Promtail failed to start!"
    echo "Check logs: sudo journalctl -u promtail -n 50"
    exit 1
fi

# Cleanup
rm -rf /tmp/promtail-linux-amd64*

