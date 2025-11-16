#!/bin/bash
set -e

echo "=========================================="
echo "Deploying to AWS Staging"
echo "=========================================="

STAGING_HOST=$1
STAGING_USER=$2
IMAGE_NAME="money-transfer"
IMAGE_TAG=$3

echo "Host: ${STAGING_USER}@${STAGING_HOST}"
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"

# Transfer Docker image to EC2
echo "📦 Transferring Docker image..."
scp -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ${IMAGE_NAME}-${IMAGE_TAG}.tar.gz \
    ${STAGING_USER}@${STAGING_HOST}:/home/ubuntu/

# Load and deploy on EC2
echo "🚀 Deploying on EC2..."
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ${STAGING_USER}@${STAGING_HOST} << REMOTE_SCRIPT

set -e

echo "Loading Docker image..."
docker load < /home/ubuntu/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz

echo "Tagging image..."
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest

echo "Deploying application..."
/opt/money-transfer/deploy.sh latest

echo "Cleaning up..."
rm -f /home/ubuntu/${IMAGE_NAME}-${IMAGE_TAG}.tar.gz

echo "✅ Deployment complete!"
REMOTE_SCRIPT

echo ""
echo "=========================================="
echo "✅ Deployment Successful!"
echo "=========================================="
