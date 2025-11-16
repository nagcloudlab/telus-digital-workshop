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
apt-get install -y jq htop net-tools unzip git nginx
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

# Create directories
echo "Creating directories..."
mkdir -p /opt/money-transfer
mkdir -p /var/log/money-transfer
chown -R ubuntu:ubuntu /opt/money-transfer
chown -R ubuntu:ubuntu /var/log/money-transfer
echo "✅ Directories created"

# Create deployment script
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

# Start new container
docker run -d \
    --name ${CONTAINER_NAME} \
    --restart unless-stopped \
    -p 8080:8080 \
    -e SPRING_PROFILES_ACTIVE=staging \
    -e JAVA_OPTS="-Xmx1024m -Xms512m" \
    -v /var/log/money-transfer:/logs \
    ${APP_NAME}:${IMAGE_TAG}

echo "Waiting for application..."
sleep 15

# Health check
RETRY=0
while [ $RETRY -lt 20 ]; do
    if curl -f http://localhost:8080/actuator/health 2>/dev/null; then
        echo "✅ Application healthy!"
        docker ps --filter "name=${CONTAINER_NAME}"
        exit 0
    fi
    RETRY=$((RETRY + 1))
    echo "Attempt $RETRY/20..."
    sleep 3
done

echo "❌ Health check failed"
docker logs ${CONTAINER_NAME}
exit 1
ENDDEPLOY

chmod +x /opt/money-transfer/deploy.sh
chown ubuntu:ubuntu /opt/money-transfer/deploy.sh
echo "✅ Deployment script created"

# Create health check script
echo "Creating health check..."
cat > /opt/money-transfer/health-check.sh << 'ENDHEALTH'
#!/bin/bash
curl -f http://localhost:8080/actuator/health || exit 1
ENDHEALTH

chmod +x /opt/money-transfer/health-check.sh
chown ubuntu:ubuntu /opt/money-transfer/health-check.sh
echo "✅ Health check script created"

# Create instance info
echo "Creating instance info..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /opt/money-transfer/instance-info.txt << ENDINFO
========================================
Money Transfer Staging Instance
========================================

Instance Details:
  Instance ID: ${INSTANCE_ID}
  Public IP: ${PUBLIC_IP}
  Private IP: ${PRIVATE_IP}
  Availability Zone: ${AZ}
  
Application Details:
  Environment: staging
  Setup Date: $(date)

Useful Commands:
  View logs: docker logs money-transfer-staging -f
  Check status: docker ps
  Health check: curl http://localhost:8080/actuator/health
  Redeploy: /opt/money-transfer/deploy.sh [version]
  
URLs:
  Application: http://${PUBLIC_IP}:8080
  Health: http://${PUBLIC_IP}:8080/actuator/health
  Via Nginx: http://${PUBLIC_IP}

========================================
ENDINFO

chown ubuntu:ubuntu /opt/money-transfer/instance-info.txt

# Completion markers
touch /opt/money-transfer/.setup-complete
date > /opt/money-transfer/.setup-timestamp

echo ""
echo "=========================================="
echo "✅ SETUP COMPLETE!"
echo "=========================================="
echo "Instance ID: ${INSTANCE_ID}"
echo "Public IP: ${PUBLIC_IP}"
echo "Completed: $(date)"
echo "=========================================="