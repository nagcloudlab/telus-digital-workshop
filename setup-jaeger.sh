cd ~/workspace/telus-digital-workshop

cat > setup-jaeger.sh << 'SCRIPT'
#!/bin/bash

set -e

echo "=========================================="
echo "Installing Jaeger All-in-One on EC2"
echo "=========================================="
echo ""

# Check if running as ubuntu user
if [ "$USER" != "ubuntu" ]; then
    echo "⚠️  Warning: This script should be run as ubuntu user"
fi

# Create Jaeger directory
echo "📁 Creating directories..."
sudo mkdir -p /opt/jaeger
sudo chown ubuntu:ubuntu /opt/jaeger

# Download Jaeger
echo "📥 Downloading Jaeger v1.52.0..."
cd /tmp
wget -q https://github.com/jaegertracing/jaeger/releases/download/v1.52.0/jaeger-1.52.0-linux-amd64.tar.gz

if [ ! -f "jaeger-1.52.0-linux-amd64.tar.gz" ]; then
    echo "❌ Failed to download Jaeger"
    exit 1
fi

# Extract
echo "📦 Extracting Jaeger..."
tar -xzf jaeger-1.52.0-linux-amd64.tar.gz

# Install binary
echo "⚙️  Installing Jaeger binary..."
sudo cp jaeger-1.52.0-linux-amd64/jaeger-all-in-one /usr/local/bin/
sudo chmod +x /usr/local/bin/jaeger-all-in-one

# Verify installation
echo ""
echo "✅ Verifying installation..."
/usr/local/bin/jaeger-all-in-one version

# Create systemd service
echo ""
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/jaeger.service > /dev/null << 'EOF'
[Unit]
Description=Jaeger All-in-One
Documentation=https://www.jaegertracing.io/docs/
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
ExecStart=/usr/local/bin/jaeger-all-in-one \
    --collector.otlp.enabled=true \
    --collector.otlp.http.host-port=:4318 \
    --collector.otlp.grpc.host-port=:4317
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

# Enable service
echo "✅ Enabling Jaeger service..."
sudo systemctl enable jaeger

# Start service
echo "🚀 Starting Jaeger service..."
sudo systemctl start jaeger

# Wait for Jaeger to start
echo "⏳ Waiting for Jaeger to be ready..."
sleep 15

# Check service status
echo ""
echo "📊 Checking service status..."
sudo systemctl status jaeger --no-pager -l

# Verify Jaeger is running
echo ""
echo "🔍 Verifying Jaeger endpoints..."

# Check UI
if curl -sf http://localhost:16686/ > /dev/null; then
    echo "  ✅ Jaeger UI: http://localhost:16686"
else
    echo "  ❌ Jaeger UI not accessible"
fi

# Check OTLP HTTP
if nc -zv localhost 4318 2>&1 | grep -q succeeded || curl -sf http://localhost:4318/ > /dev/null 2>&1 || [ $? -eq 52 ]; then
    echo "  ✅ OTLP HTTP: http://localhost:4318"
else
    echo "  ❌ OTLP HTTP not accessible"
fi

# Check OTLP gRPC
if nc -zv localhost 4317 2>&1 | grep -q succeeded; then
    echo "  ✅ OTLP gRPC: http://localhost:4317"
else
    echo "  ❌ OTLP gRPC not accessible"
fi

# Check services endpoint
echo ""
echo "🎯 Testing Jaeger API..."
SERVICES=$(curl -s http://localhost:16686/api/services 2>/dev/null || echo '{"data":[]}')
SERVICE_COUNT=$(echo "$SERVICES" | jq '.data | length' 2>/dev/null || echo "0")
echo "  Services registered: $SERVICE_COUNT"

# Cleanup
echo ""
echo "🧹 Cleaning up..."
rm -rf /tmp/jaeger-1.52.0-linux-amd64*

echo ""
echo "=========================================="
echo "✅ Jaeger Installation Complete!"
echo "=========================================="
echo ""
echo "📍 Access Points:"
echo "  UI:           http://localhost:16686"
echo "  OTLP HTTP:    http://localhost:4318"
echo "  OTLP gRPC:    http://localhost:4317"
echo ""
echo "📋 Useful Commands:"
echo "  Status:       sudo systemctl status jaeger"
echo "  Logs:         sudo journalctl -u jaeger -f"
echo "  Restart:      sudo systemctl restart jaeger"
echo "  Stop:         sudo systemctl stop jaeger"
echo ""
echo "🧪 Test Endpoints:"
echo "  curl http://localhost:16686/api/services"
echo "  curl http://localhost:16686/"
echo ""
echo "🔥 From your local machine:"
echo "  export STAGING_IP=\$(cd infrastructure/aws-staging/terraform && terraform output -raw instance_public_ip)"
echo "  open http://\$STAGING_IP:16686"
echo "=========================================="
SCRIPT

chmod +x setup-jaeger.sh