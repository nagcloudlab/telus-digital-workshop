#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Starting Money Transfer Staging Setup"
echo "Version: ${app_version}"
echo "Environment: ${environment}"
echo "=========================================="

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

echo "✅ Docker installed"

# Install tools
apt-get install -y jq htop net-tools unzip git nginx

echo "✅ Tools installed"

# Configure Nginx
cat > /etc/nginx/sites-available/money-transfer << 'NGINX_EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080\;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /health {
        access_log off;
        proxy_pass http://localhost:8080/actuator/health\;
    }
}
NGINX_EOF

ln -sf /etc/nginx/sites-available/money-transfer /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "✅ Nginx configured"

# Create application directories
mkdir -p /opt/money-transfer
mkdir -p /var/log/money-transfer
chown -R ubuntu:ubuntu /opt/money-transfer
chown -R ubuntu:ubuntu /var/log/money-transfer

echo "✅ Directories created"

# Create deployment script
cat > /opt/money-transfer/deploy.sh << 'DEPLOY_EOF'
#!/bin/bash
set -e

APP_NAME="money-transfer"
CONTAINER_NAME="money-transfer-staging"
IMAGE_TAG="$${1:-latest}"

echo "=========================================="
echo "Deploying $${APP_NAME}:$${IMAGE_TAG}"
echo "=========================================="

# Stop existing container
docker stop $${CONTAINER_NAME} 2>/dev/null || true
docker rm $${CONTAINER_NAME} 2>/dev/null || true

# Start new container
docker run -d \
    --name $${CONTAINER_NAME} \
    --restart unless-stopped \
    -p 8080:8080 \
    -e SPRING_PROFILES_ACTIVE=staging \
    -e JAVA_OPTS="-Xmx1024m -Xms512m" \
    -v /var/log/money-transfer:/logs \
    $${APP_NAME}:$${IMAGE_TAG}

echo "⏳ Waiting for application to start..."
sleep 15

# Health check
RETRY_COUNT=0
MAX_RETRIES=20

while [ $${RETRY_COUNT} -lt $${MAX_RETRIES} ]; do
    if curl -f http://localhost:8080/actuator/health 2>/dev/null; then
        echo "✅ Application is healthy!"
        docker ps --filter "name=$${CONTAINER_NAME}"
        exit 0
    fi
    RETRY_COUNT=$$((RETRY_COUNT + 1))
    echo "Attempt $${RETRY_COUNT}/$${MAX_RETRIES} - waiting..."
    sleep 3
done

echo "❌ Health check failed"
echo "Container logs:"
docker logs $${CONTAINER_NAME}
exit 1
DEPLOY_EOF

chmod +x /opt/money-transfer/deploy.sh
chown ubuntu:ubuntu /opt/money-transfer/deploy.sh

echo "✅ Deployment script created"

# Create health check script
cat > /opt/money-transfer/health-check.sh << 'HEALTH_EOF'
#!/bin/bash
curl -f http://localhost:8080/actuator/health || exit 1
HEALTH_EOF

chmod +x /opt/money-transfer/health-check.sh
chown ubuntu:ubuntu /opt/money-transfer/health-check.sh

echo "✅ Health check script created"

# Create instance info
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /opt/money-transfer/instance-info.txt << INFO_EOF
========================================
Money Transfer Staging Instance
========================================

Instance Details:
  Instance ID: $${INSTANCE_ID}
  Public IP: $${PUBLIC_IP}
  Private IP: $${PRIVATE_IP}
  Availability Zone: $${AZ}
  
Application Details:
  Version: ${app_version}
  Environment: ${environment}
  Setup Date: $(date)

Useful Commands:
  View logs: docker logs money-transfer-staging -f
  Check status: docker ps
  Health check: curl http://localhost:8080/actuator/health
  Redeploy: /opt/money-transfer/deploy.sh [version]
  
URLs:
  Application: http://$$\{PUBLIC_IP\}:8080
  Health: http://$$\{PUBLIC_IP\}:8080/actuator/health
  Via Nginx: http://$$\{PUBLIC_IP\}

========================================
INFO_EOF

chown ubuntu:ubuntu /opt/money-transfer/instance-info.txt

# Create completion marker
touch /opt/money-transfer/.setup-complete
date > /opt/money-transfer/.setup-timestamp

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo "Instance ID: $${INSTANCE_ID}"
echo "Public IP: $${PUBLIC_IP}"
echo "Application ready for deployment"
echo "=========================================="
