

aws sts get-caller-identity
./setup.sh


terraform init
terraform plan
terraform apply -auto-approve
terraform output

export STAGING_IP=$(terraform output -raw instance_public_ip)
export INSTANCE_ID=$(terraform output -raw instance_id)

echo "Staging IP: $STAGING_IP"
echo "Instance ID: $INSTANCE_ID"

terraform output -json > outputs.json
cat outputs.json | jq

ssh -i ~/.ssh/id_rsa ubuntu@$STAGING_IP "tail -100 /var/log/user-data.log"

./deploy-monitoring.sh

scp -i ~/.ssh/id_rsa setup-promtail.sh ubuntu@$STAGING_IP:/home/ubuntu/
scp -i ~/.ssh/id_rsa setup-loki.sh ubuntu@$STAGING_IP:/home/ubuntu/
scp -i ~/.ssh/id_rsa setup-jaeger.sh ubuntu@$STAGING_IP:/home/ubuntu/

# SSH to EC2
ssh -i ~/.ssh/id_rsa ubuntu@$STAGING_IP

./setup-promtail.sh
./setup-loki.sh
./setup-jaeger.sh
