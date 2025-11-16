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
    exit 1
fi
echo "Found: $IMAGE_FILE"

# Transfer to EC2
echo "📦 Transferring image..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $IMAGE_FILE ${STAGING_USER}@${STAGING_HOST}:/home/ubuntu/

# Deploy on EC2
echo "🚀 Deploying on EC2..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ${STAGING_USER}@${STAGING_HOST} << REMOTE

set -e
cd /home/ubuntu

# Load image
echo "Loading Docker image..."
docker load < $IMAGE_FILE

# Tag image
echo "Tagging image..."
docker tag money-transfer:${IMAGE_TAG} money-transfer:latest

# Deploy
echo "Deploying application..."
/opt/money-transfer/deploy.sh latest

# Cleanup
rm -f $IMAGE_FILE

echo "✅ Deployment complete!"
REMOTE

echo "=========================================="
echo "✅ Deployment Successful!"
echo "=========================================="
