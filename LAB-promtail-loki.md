
## Setting up Promtail and Loki on Staging EC2 Instance

cd ~/workspace/telus-digital-workshop

# Set environment variable
export STAGING_IP=$(cd infrastructure/aws-staging/terraform && terraform output -raw instance_public_ip)
echo "Staging IP: $STAGING_IP"

# Copy scripts to EC2
scp -i ~/.ssh/id_rsa setup-loki.sh ubuntu@$STAGING_IP:~/
scp -i ~/.ssh/id_rsa setup-promtail.sh ubuntu@$STAGING_IP:~/

# SSH to EC2
ssh -i ~/.ssh/id_rsa ubuntu@$STAGING_IP

# Now you're on EC2

# Install Loki first
./setup-loki.sh

# Should complete in ~30 seconds with ✅

# Verify Loki is running
sudo systemctl status loki
curl http://localhost:3100/ready
# Should return: ready

# Install Promtail
./setup-promtail.sh

# Should complete in ~60 seconds with ✅

# Verify Promtail is running
sudo systemctl status promtail
curl http://localhost:9080/metrics | head -20

# Check positions file (shows what logs are being read)
cat /tmp/positions.yaml

# Exit EC2
exit





# Generate some traffic to create logs
curl http://$STAGING_IP:8080/api/accounts
curl http://$STAGING_IP:8080/actuator/health
curl http://$STAGING_IP:8080/actuator/prometheus > /dev/null

# Wait for logs to be processed
sleep 10

# Query logs from Loki
curl -G http://$STAGING_IP:3100/loki/api/v1/query \
  --data-urlencode 'query={job="money-transfer"}' | jq '.data.result[].values[][1]' -r

# Query INFO logs
curl -G http://$STAGING_IP:3100/loki/api/v1/query \
  --data-urlencode 'query={job="money-transfer", level="info"}' \
  --data-urlencode 'limit=5' | jq '.data.result[].values[][1]' -r