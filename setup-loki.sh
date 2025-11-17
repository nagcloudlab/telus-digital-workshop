#!/bin/bash

set -e

echo "=========================================="
echo "Installing Loki on EC2"
echo "=========================================="
echo ""

# Create directories
echo "📁 Creating directories..."
sudo mkdir -p /opt/loki/{data,config}
sudo mkdir -p /opt/loki/data/{chunks,rules,compactor}

# Download Loki
echo "📥 Downloading Loki v2.9.3..."
cd /tmp
wget -q https://github.com/grafana/loki/releases/download/v2.9.3/loki-linux-amd64.zip

if [ ! -f "loki-linux-amd64.zip" ]; then
    echo "❌ Failed to download Loki"
    exit 1
fi

unzip -q loki-linux-amd64.zip

# Install binary
echo "⚙️  Installing Loki binary..."
sudo chmod +x loki-linux-amd64
sudo mv loki-linux-amd64 /usr/local/bin/loki

# Verify installation
echo "✅ Verifying installation..."
/usr/local/bin/loki --version

# Create configuration
echo "🔧 Creating Loki configuration..."
sudo tee /opt/loki/config/loki-config.yml > /dev/null << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  path_prefix: /opt/loki/data
  storage:
    filesystem:
      chunks_directory: /opt/loki/data/chunks
      rules_directory: /opt/loki/data/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
  max_query_length: 721h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h

compactor:
  working_directory: /opt/loki/data/compactor
  shared_store: filesystem
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
EOF

# Set ownership
echo "🔐 Setting permissions..."
sudo chown -R ubuntu:ubuntu /opt/loki

# Create systemd service
echo "🚀 Creating systemd service..."
sudo tee /etc/systemd/system/loki.service > /dev/null << 'EOF'
[Unit]
Description=Loki Log Aggregation System
Documentation=https://grafana.com/docs/loki/
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
ExecStart=/usr/local/bin/loki -config.file=/opt/loki/config/loki-config.yml
Restart=on-failure
RestartSec=20
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "🔄 Starting Loki service..."
sudo systemctl daemon-reload
sudo systemctl enable loki
sudo systemctl start loki

# Wait for Loki to start
echo "⏳ Waiting for Loki to be ready..."
sleep 20

# Verify Loki is running
if curl -sf http://localhost:3100/ready > /dev/null; then
    echo ""
    echo "=========================================="
    echo "✅ Loki installed successfully!"
    echo "=========================================="
    echo "Status:  $(curl -s http://localhost:3100/ready)"
    echo "Port:    3100"
    echo "Config:  /opt/loki/config/loki-config.yml"
    echo "Data:    /opt/loki/data"
    echo ""
    echo "📋 Useful Commands:"
    echo "  Status:  sudo systemctl status loki"
    echo "  Logs:    sudo journalctl -u loki -f"
    echo "  Restart: sudo systemctl restart loki"
    echo ""
    echo "🧪 Test:"
    echo "  curl http://localhost:3100/ready"
    echo "  curl http://localhost:3100/metrics"
    echo "=========================================="
else
    echo ""
    echo "❌ Loki failed to start!"
    echo "Check logs: sudo journalctl -u loki -n 50"
    exit 1
fi

# Cleanup
rm -rf /tmp/loki-linux-amd64*

