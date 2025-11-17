#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Money Transfer Staging Setup"
echo "Started: $(date)"
echo "=========================================="

# Prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Update system
echo "Updating packages..."
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Install Docker
echo "Installing Docker..."
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu
echo "✅ Docker installed"

# Install tools
echo "Installing tools..."
apt-get install -y jq htop net-tools unzip git nginx netcat-openbsd
echo "✅ Tools installed"

# Configure Nginx
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/money-transfer << 'ENDNGINX'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    location /health {
        access_log off;
        proxy_pass http://localhost:8080/actuator/health;
    }
}
ENDNGINX

ln -sf /etc/nginx/sites-available/money-transfer /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

if nginx -t; then
    systemctl restart nginx
    systemctl enable nginx
    echo "✅ Nginx configured"
else
    echo "❌ Nginx config failed"
fi

# Create application directories
echo "Creating application directories..."
mkdir -p /opt/money-transfer
mkdir -p /var/log/money-transfer
chown -R ubuntu:ubuntu /opt/money-transfer
chown -R ubuntu:ubuntu /var/log/money-transfer
echo "✅ Application directories created"

# Create monitoring directories
echo "Creating monitoring directories..."
mkdir -p /home/ubuntu/monitoring/{prometheus,grafana/provisioning/{dashboards,datasources},alertmanager}
chown -R ubuntu:ubuntu /home/ubuntu/monitoring
echo "✅ Monitoring directories created"

# Create deployment script with tracing support
echo "Creating deployment script..."
cat > /opt/money-transfer/deploy.sh << 'ENDDEPLOY'
#!/bin/bash
set -e

APP_NAME="money-transfer"
CONTAINER_NAME="money-transfer-staging"
IMAGE_TAG="${1:-latest}"

echo "=========================================="
echo "Deploying ${APP_NAME}:${IMAGE_TAG}"
echo "=========================================="

# Stop existing container
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Start new container with full configuration
docker run -d \
    --name ${CONTAINER_NAME} \
    --restart unless-stopped \
    --network host \
    -e SPRING_PROFILES_ACTIVE=staging \
    -e JAVA_OPTS="-Xmx1024m -Xms512m" \
    -e MANAGEMENT_OTLP_TRACING_ENDPOINT="http://localhost:4318/v1/traces" \
    -e MANAGEMENT_TRACING_ENABLED=true \
    -e MANAGEMENT_TRACING_SAMPLING_PROBABILITY=1.0 \
    -e SPRING_APPLICATION_NAME=money-transfer \
    -e OTEL_SERVICE_NAME=money-transfer \
    -e OTEL_RESOURCE_ATTRIBUTES="service.name=money-transfer,service.version=${IMAGE_TAG},deployment.environment=staging,service.instance.id=${INSTANCE_ID},cloud.provider=aws,cloud.region=${AZ%?},host.id=${INSTANCE_ID},host.name=${PRIVATE_IP}" \
    -v /var/log/money-transfer:/logs \
    ${APP_NAME}:${IMAGE_TAG}

echo "Waiting for application to start..."
sleep 20

# Health check with retries
RETRY=0
MAX_RETRIES=30
while [ $RETRY -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:8080/actuator/health 2>/dev/null; then
        echo "✅ Application healthy!"
        echo ""
        echo "Application Info:"
        echo "  Container: ${CONTAINER_NAME}"
        echo "  Image: ${APP_NAME}:${IMAGE_TAG}"
        echo "  Instance: ${INSTANCE_ID}"
        echo ""
        echo "URLs:"
        echo "  Application: http://${PUBLIC_IP}:8080"
        echo "  Health: http://${PUBLIC_IP}:8080/actuator/health"
        echo "  Metrics: http://${PUBLIC_IP}:8080/actuator/prometheus"
        echo ""
        docker ps --filter "name=${CONTAINER_NAME}"
        exit 0
    fi
    RETRY=$((RETRY + 1))
    echo "Attempt $RETRY/$MAX_RETRIES..."
    sleep 3
done

echo "❌ Health check failed after $MAX_RETRIES attempts"
echo ""
echo "Container logs:"
docker logs ${CONTAINER_NAME} --tail 100
exit 1
ENDDEPLOY

chmod +x /opt/money-transfer/deploy.sh
chown ubuntu:ubuntu /opt/money-transfer/deploy.sh
echo "✅ Deployment script created"

# Create health check script
echo "Creating health check script..."
cat > /opt/money-transfer/health-check.sh << 'ENDHEALTH'
#!/bin/bash
# Check application health
if ! curl -f http://localhost:8080/actuator/health 2>/dev/null; then
    echo "❌ Application unhealthy"
    exit 1
fi
echo "✅ Application healthy"
exit 0
ENDHEALTH

chmod +x /opt/money-transfer/health-check.sh
chown ubuntu:ubuntu /opt/money-transfer/health-check.sh
echo "✅ Health check script created"

# Create monitoring check script
echo "Creating monitoring check script..."
cat > /opt/money-transfer/check-monitoring.sh << 'ENDMONCHECK'
#!/bin/bash
echo "=========================================="
echo "Monitoring Stack Status"
echo "=========================================="
echo ""

cd /home/ubuntu/monitoring 2>/dev/null || {
    echo "❌ Monitoring not deployed yet"
    echo "Run: ./deploy-monitoring.sh"
    exit 1
}

# Check if docker-compose.yml exists
if [ ! -f docker-compose.yml ]; then
    echo "❌ Monitoring stack not configured"
    exit 1
fi

# Check containers
echo "Container Status:"
docker-compose ps

echo ""
echo "Health Checks:"
curl -sf http://localhost:9090/-/healthy && echo "✅ Prometheus healthy" || echo "❌ Prometheus unhealthy"
curl -sf http://localhost:3000/api/health && echo "✅ Grafana healthy" || echo "❌ Grafana unhealthy"
curl -sf http://localhost:9093/-/healthy && echo "✅ AlertManager healthy" || echo "❌ AlertManager unhealthy"

echo ""
echo "=========================================="
ENDMONCHECK

chmod +x /opt/money-transfer/check-monitoring.sh
chown ubuntu:ubuntu /opt/money-transfer/check-monitoring.sh
echo "✅ Monitoring check script created"

# Create instance info
echo "Creating instance info..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${AZ%?}

cat > /opt/money-transfer/instance-info.txt << ENDINFO
========================================
Money Transfer Staging Instance
========================================

Instance Details:
  Instance ID: ${INSTANCE_ID}
  Public IP: ${PUBLIC_IP}
  Private IP: ${PRIVATE_IP}
  Availability Zone: ${AZ}
  Region: ${REGION}
  
Application Details:
  Environment: staging
  Setup Date: $(date)
  Tracing: Enabled (OpenTelemetry)
  Tracing Endpoint: http://localhost:4318/v1/traces

Application URLs:
  Main: http://${PUBLIC_IP}:8080
  Health: http://${PUBLIC_IP}:8080/actuator/health
  Metrics: http://${PUBLIC_IP}:8080/actuator/prometheus
  Info: http://${PUBLIC_IP}:8080/actuator/info
  Via Nginx: http://${PUBLIC_IP}

Monitoring URLs (after deployment):
  Grafana: http://${PUBLIC_IP}:3000 (admin/admin123)
  Prometheus: http://${PUBLIC_IP}:9090
  AlertManager: http://${PUBLIC_IP}:9093
  Node Exporter: http://${PUBLIC_IP}:9100/metrics

Useful Commands:
  # Application
  View logs: docker logs money-transfer-staging -f
  Check status: docker ps
  Health check: /opt/money-transfer/health-check.sh
  Redeploy: /opt/money-transfer/deploy.sh [version]
  
  # Monitoring
  Check monitoring: /opt/money-transfer/check-monitoring.sh
  Monitoring logs: cd ~/monitoring && docker-compose logs -f
  Restart monitoring: cd ~/monitoring && docker-compose restart
  
  # Debugging
  View setup log: tail -f /var/log/user-data.log
  Check ports: netstat -tlnp | grep -E '(8080|3000|9090|9093|9100)'
  Test health: curl http://localhost:8080/actuator/health

========================================
ENDINFO

chown ubuntu:ubuntu /opt/money-transfer/instance-info.txt

# Create welcome message
cat > /etc/update-motd.d/99-money-transfer << 'ENDMOTD'
#!/bin/bash
cat /opt/money-transfer/instance-info.txt 2>/dev/null || echo "Setup in progress..."
ENDMOTD

chmod +x /etc/update-motd.d/99-money-transfer

# Completion markers
touch /opt/money-transfer/.setup-complete
date > /opt/money-transfer/.setup-timestamp

echo ""
echo "=========================================="
echo "✅ SETUP COMPLETE!"
echo "=========================================="
echo "Instance ID: ${INSTANCE_ID}"
echo "Public IP: ${PUBLIC_IP}"
echo "Region: ${REGION}"
echo "Completed: $(date)"
echo ""
echo "Next Steps:"
echo "1. Deploy monitoring stack: Run deploy-monitoring.sh script"
echo "2. Deploy application: Trigger GitHub Actions pipeline"
echo ""
echo "View instance info: cat /opt/money-transfer/instance-info.txt"
echo "=========================================="
