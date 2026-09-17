# Deployment Guide
## AWS SAA Graduation Project — Scalable E-Commerce Web Application
**Author**: Aziz Benchikh

---

## Prerequisites

Before deploying, ensure you have the following:

| Requirement | Check |
|-------------|-------|
| AWS Account | Active account with admin or power-user permissions |
| AWS CLI | Installed and configured (`aws configure`) |
| AWS Region | Set to `us-east-1` |
| S3 Bucket | One S3 bucket to host CloudFormation nested stack templates |

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/<your-username>/aws-scalable-ecommerce.git
cd aws-scalable-ecommerce
```

---

## Step 2: Upload Nested Stack Templates to S3

The `main-stack.yaml` references nested templates via S3 URLs. Upload all individual stack files:

```bash
# Create the templates bucket (replace with your bucket name)
BUCKET_NAME="ecommerce-cfn-templates-$(aws sts get-caller-identity --query Account --output text)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Upload all nested stack templates
aws s3 cp cloudformation/ s3://$BUCKET_NAME/ \
  --recursive \
  --exclude "main-stack.yaml"

# Verify upload
aws s3 ls s3://$BUCKET_NAME/
```

Expected output:
```
network-stack.yaml
security-stack.yaml
database-stack.yaml
compute-stack.yaml
cdn-stack.yaml
monitoring-stack.yaml
```

---

## Step 3: Deploy the Main Stack

> [!IMPORTANT]
> The **database stack** takes ~20 minutes (RDS Multi-AZ provisioning). Total deployment time is approximately **30-40 minutes**.

### Option A: AWS Console (Recommended for learning)

1. Open [AWS CloudFormation Console](https://console.aws.amazon.com/cloudformation)
2. Click **Create stack → With new resources**
3. Upload `cloudformation/main-stack.yaml`
4. Fill in parameters:

| Parameter | Recommended Value |
|-----------|-------------------|
| EnvironmentName | `EcommerceApp` |
| TemplatesBucketName | Your S3 bucket name |
| AlertEmail | Your email address |
| InstanceType | `t3.micro` (free tier) |
| DBInstanceClass | `db.t3.micro` (free tier) |
| MultiAZEnabled | `true` |
| PriceClass | `PriceClass_100` |

5. On **Capabilities** page, check: ☑ `CAPABILITY_IAM` and ☑ `CAPABILITY_NAMED_IAM`
6. Click **Submit**

### Option B: AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name EcommerceApp-Main \
  --template-body file://cloudformation/main-stack.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=EcommerceApp \
    ParameterKey=TemplatesBucketName,ParameterValue=$BUCKET_NAME \
    ParameterKey=AlertEmail,ParameterValue=your-email@example.com \
    ParameterKey=MultiAZEnabled,ParameterValue=true \
    ParameterKey=InstanceType,ParameterValue=t3.micro \
    ParameterKey=DBInstanceClass,ParameterValue=db.t3.micro \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --region us-east-1

# Monitor deployment progress
aws cloudformation wait stack-create-complete \
  --stack-name EcommerceApp-Main \
  --region us-east-1
```

---

## Step 4: Retrieve Your Website URL

After successful deployment:

```bash
# Get the CloudFront URL (your website)
aws cloudformation describe-stacks \
  --stack-name EcommerceApp-Main \
  --query "Stacks[0].Outputs[?OutputKey=='WebsiteURL'].OutputValue" \
  --output text
```

Open the URL in your browser. You should see the ShopAWS product catalog.

---

## Step 5: Upload Static Assets to S3

```bash
# Get the static assets bucket name
STATIC_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name EcommerceApp-Main \
  --query "Stacks[0].Outputs[?OutputKey=='StaticAssetsBucket'].OutputValue" \
  --output text)

# Upload any static files (images, CSS)
aws s3 sync ./static/ s3://$STATIC_BUCKET/static/ \
  --cache-control "public, max-age=2592000"
```

---

## Step 6: Verify the Architecture

### Test ALB Health Checks
```bash
ALB_URL=$(aws cloudformation describe-stacks \
  --stack-name EcommerceApp-Main \
  --query "Stacks[0].Outputs[?OutputKey=='ALBDirectURL'].OutputValue" \
  --output text)

curl $ALB_URL/health   # Should return "healthy"
```

### Verify Multi-AZ Instances
```bash
# Check instances are in both AZs
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names EcommerceApp-ASG \
  --query "AutoScalingGroups[0].Instances[*].{ID:InstanceId,AZ:AvailabilityZone,Status:HealthStatus}"
```

### Test Auto Scaling (Optional)
```bash
# Connect to an instance via SSM Session Manager (no SSH needed!)
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names EcommerceApp-ASG \
  --query "AutoScalingGroups[0].Instances[0].InstanceId" \
  --output text)

aws ssm start-session --target $INSTANCE_ID
```

### View CloudWatch Dashboard
```bash
aws cloudformation describe-stacks \
  --stack-name EcommerceApp-Main \
  --query "Stacks[0].Outputs[?OutputKey=='CloudWatchDashboard'].OutputValue" \
  --output text
```

---

## Step 7: Verify RDS Multi-AZ

```bash
# Get DB instance details
aws rds describe-db-instances \
  --db-instance-identifier EcommerceApp-mysql-db \
  --query "DBInstances[0].{MultiAZ:MultiAZ,Status:DBInstanceStatus,SecondaryAZ:SecondaryAvailabilityZone,Endpoint:Endpoint.Address}"
```

---

## Cleanup (Avoid AWS Charges)

> [!CAUTION]
> This will delete **all resources** including the RDS database (a final snapshot will be created).

```bash
# Delete main stack (this deletes all nested stacks automatically)
aws cloudformation delete-stack \
  --stack-name EcommerceApp-Main \
  --region us-east-1

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name EcommerceApp-Main

# Delete template bucket (only if no longer needed)
aws s3 rb s3://$BUCKET_NAME --force
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Stack fails at Database | Check if `db.t3.micro` is available in your region. Try `db.t3.small`. |
| EC2 instances unhealthy | Check Nginx started via SSM: `systemctl status nginx` |
| Can't access website | Verify CloudFront is deployed (takes ~10-15 min). Try ALB URL directly. |
| SSM Session fails | Ensure VPC endpoints are deployed (security-stack). Check EC2 IAM role. |
| Email alarm not received | Click the confirmation link in the SNS subscription email. |
