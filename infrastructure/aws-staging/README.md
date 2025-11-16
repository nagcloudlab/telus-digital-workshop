# AWS Staging Environment

## Quick Start

### 1. Setup AWS Resources
```bash
cd scripts
./setup.sh
```

### 2. Deploy Infrastructure
```bash
cd ../terraform
terraform init
terraform plan
terraform apply
```

### 3. Get Outputs
```bash
terraform output
```

### 4. Add GitHub Secrets
Go to: https://github.com/YOUR_REPO/settings/secrets/actions

Add the secrets from `scripts/github-secrets.txt`

## Verification
```bash
# SSH to instance
ssh -i ~/.ssh/id_rsa ubuntu@<INSTANCE_IP>

# Check setup
cat /opt/money-transfer/instance-info.txt
docker --version
```

## Cleanup
```bash
terraform destroy
```
