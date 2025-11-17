

## Setting up Jaeger on Staging EC2 Instance

cd ~/workspace/telus-digital-workshop

# Set environment variable
export STAGING_IP=$(cd infrastructure/aws-staging/terraform && terraform output -raw instance_public_ip)
echo "Staging IP: $STAGING_IP"

# Copy script to EC2
scp -i ~/.ssh/id_rsa setup-jaeger.sh ubuntu@$STAGING_IP:~/

# SSH to EC2
ssh -i ~/.ssh/id_rsa ubuntu@$STAGING_IP

# Run installation
./setup-jaeger.sh

# Script will complete in ~30 seconds

# Still on EC2

# Check service status
sudo systemctl status jaeger

# View logs
sudo journalctl -u jaeger -n 50

# Test endpoints
curl http://localhost:16686/api/services
curl http://localhost:16686/

# Exit EC2
exit

# From your local machine

# Test Jaeger UI
curl http://$STAGING_IP:16686/

# Open in browser
open http://$STAGING_IP:16686

# Test API
curl http://$STAGING_IP:16686/api/services | jq