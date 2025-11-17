


# Deploy monitoring
./deploy-monitoring.sh

# After monitoring is deployed, check from EC2
ssh -i ~/.ssh/id_rsa ubuntu@$STAGING_IP "/opt/money-transfer/check-monitoring.sh"