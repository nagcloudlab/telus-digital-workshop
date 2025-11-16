#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo "AWS Staging Environment Setup"
echo "==========================================${NC}"

AWS_REGION="ap-south-1"
S3_BUCKET="money-transfer-terraform-state"
DYNAMODB_TABLE="terraform-state-lock"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AWS CLI found${NC}"

# Check credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    exit 1
fi
echo -e "${GREEN}✅ AWS credentials configured${NC}"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}   Account: $AWS_ACCOUNT_ID${NC}"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Terraform found${NC}"

# Check SSH key
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo -e "${YELLOW}⚠️  Generating SSH key...${NC}"
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "money-transfer-staging"
fi
echo -e "${GREEN}✅ SSH key found${NC}"

# Create S3 bucket
echo ""
echo -e "${GREEN}Creating S3 bucket...${NC}"
if aws s3 ls "s3://$S3_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3api create-bucket \
        --bucket $S3_BUCKET \
        --region $AWS_REGION \
        --create-bucket-configuration LocationConstraint=$AWS_REGION
    
    aws s3api put-bucket-versioning \
        --bucket $S3_BUCKET \
        --versioning-configuration Status=Enabled
    
    aws s3api put-bucket-encryption \
        --bucket $S3_BUCKET \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    echo -e "${GREEN}✅ S3 bucket created${NC}"
else
    echo -e "${GREEN}✅ S3 bucket exists${NC}"
fi

# Create DynamoDB table
echo ""
echo -e "${GREEN}Creating DynamoDB table...${NC}"
if aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $AWS_REGION 2>&1 | grep -q 'ResourceNotFoundException'; then
    aws dynamodb create-table \
        --table-name $DYNAMODB_TABLE \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region $AWS_REGION
    
    aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE --region $AWS_REGION
    echo -e "${GREEN}✅ DynamoDB table created${NC}"
else
    echo -e "${GREEN}✅ DynamoDB table exists${NC}"
fi

# Create terraform.tfvars
echo ""
echo -e "${GREEN}Creating terraform.tfvars...${NC}"
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

cat > ../terraform/terraform.tfvars <<TFVARS
aws_region     = "$AWS_REGION"
instance_type  = "t3.medium"
app_version    = "latest"
environment    = "staging"
ssh_public_key = "$SSH_PUBLIC_KEY"
TFVARS

echo -e "${GREEN}✅ terraform.tfvars created${NC}"

# Create GitHub secrets template
cat > github-secrets.txt <<SECRETS
GitHub Secrets to Add
=====================

1. AWS_ACCESS_KEY_ID
   Value: <Your AWS Access Key>

2. AWS_SECRET_ACCESS_KEY
   Value: <Your AWS Secret Key>

3. AWS_REGION
   Value: ap-south-1

4. EC2_SSH_PRIVATE_KEY
   Value:
$(cat ~/.ssh/id_rsa)

5. STAGING_HOST
   Value: <Will get after terraform apply>

Add these to: GitHub Repo → Settings → Secrets → Actions
SECRETS

echo -e "${GREEN}✅ GitHub secrets template created${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. cd ../terraform"
echo "2. terraform init"
echo "3. terraform plan"
echo "4. terraform apply"
echo ""
