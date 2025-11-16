#!/bin/bash
set -e

STAGING_HOST=$1
STAGING_USER=$2
IMAGE_TAG=$3

echo "=========================================="
echo "Deploying to AWS Staging"
echo "Host: ${STAGING_USER}@${STAGING_HOST}"
echo "Image: money-transfer:${IMAGE_TAG}"
echo "=========================================="

# Find image file
IMAGE_FILE=$(ls money-transfer-*.tar.gz 2>/dev/null | head -1)
if [ -z "$IMAGE_FILE" ]; then
    echo "❌ No image file found"
    ls -la
    exit 1
fi
echo "Found: $IMAGE_FILE"

# Transfer to EC2
echo "📦 Transferring image to EC2..."
scp -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/staging_key \
    $IMAGE_FILE ${STAGING_USER}@${STAGING_HOST}:/home/ubuntu/

echo "✅ Transfer complete"

# Deploy on EC2
echo "🚀 Deploying on EC2..."
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/staging_key \
    ${STAGING_USER}@${STAGING_HOST} << 'REMOTE'

set -e
cd /home/ubuntu

# Find the image file
IMAGE_FILE=$(ls money-transfer-*.tar.gz 2>/dev/null | head -1)

if [ -z "$IMAGE_FILE" ]; then
    echo "❌ Image file not found on EC2"
    exit 1
fi

echo "Found on EC2: $IMAGE_FILE"

# Load Docker image
echo "Loading Docker image..."
docker load < $IMAGE_FILE

# Extract tag from filename
IMAGE_TAG=$(echo $IMAGE_FILE | sed 's/money-transfer-//;s/.tar.gz//')
echo "Image tag: $IMAGE_TAG"

# Tag as latest
echo "Tagging image as latest..."
docker tag money-transfer:${IMAGE_TAG} money-transfer:latest

# Deploy using deployment script
echo "Running deployment script..."
/opt/money-transfer/deploy.sh latest

# Cleanup
echo "Cleaning up..."
rm -f $IMAGE_FILE

echo "✅ Deployment complete on EC2!"
REMOTE

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Deployment Successful!"
    echo "=========================================="
    echo "Application URL: http://${STAGING_HOST}:8080"
    echo "Health Check: http://${STAGING_HOST}:8080/actuator/health"
else
    echo ""
    echo "=========================================="
    echo "❌ Deployment Failed!"
    echo "=========================================="
    exit 1
fi