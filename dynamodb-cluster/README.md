# DynamoDB Cluster on AWS

This Terraform configuration creates Amazon DynamoDB tables with comprehensive features including encryption, monitoring, and backup capabilities.

## 🆓 AWS Free Tier Compatible

This configuration supports AWS Free Tier with:
- **25 GB storage** (free for 12 months)
- **25 RCU and 25 WCU** provisioned capacity (free for 12 months)
- **Pay-per-request pricing** for unpredictable workloads
- **$0.00/month** within free tier limits

## 🚀 Quick Deploy

### Using the Database CLI (Recommended)
```bash
# Interactive mode
cd ../../anc-pipelines
./database-deploy.sh

# Direct command
./database-deploy.sh --database dynamodb --mode free-tier --environment dev
```

### Direct Terraform Deployment
```bash
# 1. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# 2. Deploy
terraform init
terraform plan
terraform apply
```

## 📊 Configuration Options

### Free Tier Setup
```hcl
# terraform.tfvars
billing_mode = "PROVISIONED"
read_capacity = 5      # Under 25 RCU free limit
write_capacity = 5     # Under 25 WCU free limit
free_tier_mode = true
enable_encryption = false  # Avoid KMS costs
```

### Production Setup
```hcl
# terraform.tfvars
billing_mode = "PAY_PER_REQUEST"  # Auto-scaling
enable_encryption = true
enable_point_in_time_recovery = true
enable_monitoring = true
```

## 🔧 Key Features

- **Flexible Billing**: Pay-per-request or provisioned capacity
- **Global Secondary Indexes**: Query data using different attributes
- **Local Secondary Indexes**: Additional sort key options
- **DynamoDB Streams**: Real-time data change capture
- **Point-in-time Recovery**: Restore data to any point in the last 35 days
- **Encryption at Rest**: AWS managed or customer managed KMS keys
- **CloudWatch Monitoring**: Built-in metrics and custom alarms
- **IAM Integration**: Fine-grained access control

## 💰 Cost Optimization

### Free Tier Benefits (12 months)
- 25 GB of storage
- 25 RCU and 25 WCU of provisioned capacity
- 2.5 million stream read requests

### Pricing Models
- **Pay-per-request**: $0.25 per million read requests, $1.25 per million write requests
- **Provisioned**: $0.00013 per RCU/hour, $0.00065 per WCU/hour
- **Storage**: $0.25 per GB/month (first 25 GB free)

## 📈 Scaling Options

### Auto Scaling (Provisioned Mode)
- Automatically adjusts capacity based on traffic
- Set target utilization (20-90%)
- Min/max capacity limits

### On-Demand (Pay-per-Request)
- Instantly scales to handle traffic spikes
- No capacity planning required
- Higher cost per request

## 🔐 Security Features

- **Encryption**: Server-side encryption with AWS managed or customer managed keys
- **Access Control**: IAM roles and policies for fine-grained permissions
- **VPC Endpoints**: Private connectivity from VPC resources
- **CloudTrail Integration**: API call logging for auditing

## 📊 Monitoring & Alerting

- **CloudWatch Metrics**: Built-in performance metrics
- **Custom Alarms**: Throttling, capacity, and error rate alerts
- **SNS Integration**: Automated notifications
- **AWS X-Ray**: Request tracing and performance analysis

## 🛠️ Operations

### Common Commands
```bash
# List tables
aws dynamodb list-tables

# Describe table
aws dynamodb describe-table --table-name your-table-name

# Scan table
aws dynamodb scan --table-name your-table-name --max-items 10

# Put item
aws dynamodb put-item --table-name your-table-name --item '{"id":{"S":"example"}}'
```

### Terraform Operations
```bash
# View current state
terraform show

# Import existing table
terraform import aws_dynamodb_table.main_table your-table-name

# Destroy (careful!)
terraform destroy
```

## 🔄 Migration & Backup

### Point-in-Time Recovery
- Enabled by default in this configuration
- 35-day retention period
- Restore to any point in time

### On-Demand Backup
```bash
aws dynamodb create-backup \
    --table-name your-table-name \
    --backup-name "backup-$(date +%Y%m%d)"
```

### Data Export
- Export to S3 for analytics
- Point-in-time export capability
- DynamoDB Streams for real-time processing

## 📚 Documentation

- [AWS DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)
- [Free Tier Details](https://aws.amazon.com/free/)

## 🆘 Troubleshooting

### Common Issues

**Throttling Errors**
- Increase read/write capacity
- Switch to on-demand billing
- Implement exponential backoff

**High Costs**
- Monitor usage in CloudWatch
- Optimize access patterns
- Consider reserved capacity

**Access Denied**
- Check IAM policies
- Verify resource ARNs
- Review VPC endpoint configuration

### Getting Help
- Check CloudWatch metrics
- Review CloudTrail logs
- Use AWS Support (if available)
- Community forums and documentation

---

**Ready to deploy your DynamoDB infrastructure? Start with the database CLI for the best experience!**