# Cassandra Cluster - AWS Free Tier Configuration

This document describes how to deploy a minimal Cassandra cluster using AWS Free Tier resources to minimize costs.

## 🆓 AWS Free Tier Limits (12 months for new accounts)

### Compute
- **EC2**: 750 hours/month of t2.micro instances
- **EBS Storage**: 30 GB/month of General Purpose (gp2) storage
- **EBS Snapshots**: 1 GB/month of snapshot storage
- **Data Transfer**: 1 GB/month outbound data transfer

### What's NOT Free
- **Load Balancers**: ~$16-25/month (DISABLED in free tier config)
- **Elastic IPs**: FREE when attached to running instances, $3.65/month when unattached
- **NAT Gateway**: ~$45/month (not used in this config)
- **CloudWatch**: Detailed monitoring costs extra (disabled in free tier config)
- **KMS**: $1/month per key (encryption disabled in free tier config)

## 📊 Free Tier Configuration

### Current Settings
```hcl
# Instance Configuration
instance_type = "t2.micro"          # FREE: 750 hours/month
asg_desired_capacity = 1             # Single instance (744 hours/month < 750)

# Storage Configuration  
root_volume_size = 8                 # 8 GB for OS
data_volume_size = 20                # 20 GB for Cassandra data
# Total: 28 GB < 30 GB FREE limit

# Volume Type
volume_type = "gp2"                  # FREE tier EBS type

# Disabled Features (to avoid costs)
create_load_balancer = false         # Saves $16+/month
enable_monitoring = false            # Avoid CloudWatch costs
enable_encryption_at_rest = false    # Avoid KMS costs ($1/month)
```

## ⚠️ Limitations with Free Tier

### Performance
- **t2.micro**: 1 vCPU, 1 GB RAM - Very limited for Cassandra
- **Single Node**: No fault tolerance or high availability
- **Storage**: Limited to 30 GB total EBS storage per month

### Cassandra Specifics
- **Heap Size**: Reduced to 512MB (from 8GB)
- **No Load Balancer**: Direct access to single instance
- **No Auto Scaling**: Limited to 1-2 instances maximum
- **No Encryption**: To avoid KMS costs
- **Basic Monitoring**: No detailed CloudWatch metrics

## 🚀 Deployment Instructions

### 1. Copy and Configure
```bash
cd aws-topology/cassandra-cluster
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars
```hcl
# REQUIRED: Add your SSH public key
public_key = "ssh-rsa AAAAB3NzaC1yc2E... your-key-here"

# OPTIONAL: Adjust region if needed
aws_region = "us-east-1"  # Free tier available in all regions
```

### 3. Deploy
```bash
terraform init
terraform plan    # Review the resources to be created
terraform apply   # Deploy (should cost $0 within free tier limits)
```

### 4. Access Your Cluster
```bash
# Get the instance IP from output
terraform output cassandra_private_ips

# SSH to the instance
ssh -i ~/.ssh/your-key ubuntu@<instance-ip>

# Check Cassandra status
sudo systemctl status cassandra
```

## 💰 Cost Monitoring

### Expected Monthly Costs (within free tier)
- **EC2 t2.micro**: $0.00 (750 hours free)
- **EBS Storage**: $0.00 (28 GB < 30 GB free)
- **Data Transfer**: $0.00 (minimal usage)
- **Total**: $0.00/month

### If You Exceed Free Tier
- **t2.micro overage**: ~$8.50/month for full month
- **EBS overage**: ~$0.10/GB/month for additional storage
- **Data transfer overage**: ~$0.09/GB for additional outbound transfer

## 📈 Scaling Beyond Free Tier

When ready to scale beyond free tier limitations:

### 1. Enable Load Balancer
```hcl
create_load_balancer = true
use_network_load_balancer = true  # Better for Cassandra
```

### 2. Scale Up Instance
```hcl
instance_type = "m5.large"        # Better performance
cassandra_heap_size = "4G"        # Increase heap size
```

### 3. Add More Nodes
```hcl
asg_desired_capacity = 3          # 3-node cluster
asg_max_size = 6                  # Allow scaling to 6 nodes
```

### 4. Enable Features
```hcl
enable_monitoring = true           # CloudWatch monitoring
enable_encryption_at_rest = true  # KMS encryption
data_volume_size = 100            # More storage
```

## 🔧 Troubleshooting

### Common Issues

**Instance Type Not Supported**
```
Error: Instance type must be a valid EC2 instance type
```
Solution: Use t2.micro, t2.small, or t2.medium for free tier

**Volume Size Too Small**
```
Error: Data volume size must be between 8 and 1000 GB
```
Solution: Minimum 8 GB, but keep total under 30 GB for free tier

**Cassandra Won't Start**
```
Service failed to start
```
Solution: t2.micro has limited resources. Check:
- Memory usage: `free -h`
- Disk space: `df -h`
- Logs: `sudo journalctl -u cassandra`

### Performance Tuning for t2.micro

Add to `/etc/cassandra/cassandra.yaml`:
```yaml
# Reduce memory usage
concurrent_reads: 8
concurrent_writes: 8
concurrent_counter_writes: 8

# Smaller commitlog
commitlog_total_space_in_mb: 32

# Reduce batch size
batch_size_warn_threshold_in_kb: 5
```

## 📚 Additional Resources

- [AWS Free Tier Details](https://aws.amazon.com/free/)
- [Cassandra Documentation](https://cassandra.apache.org/doc/)
- [t2.micro Performance Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances.html)

## ⚡ Quick Commands

```bash
# Check free tier usage
aws ce get-dimension-values --dimension Key --time-period Start=2024-01-01,End=2024-12-31

# Monitor instance performance
top
htop
iostat -x 1

# Check Cassandra cluster status
nodetool status
nodetool info
cqlsh -e "DESCRIBE KEYSPACES;"
```

---

**Important**: Always monitor your AWS billing dashboard to ensure you stay within free tier limits!