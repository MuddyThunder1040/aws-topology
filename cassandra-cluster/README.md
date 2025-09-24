# Cassandra EC2 Cluster on AWS

This Terraform configuration creates an Apache Cassandra cluster on AWS EC2 instances with support for both production and AWS Free Tier deployments.

## 🆓 AWS Free Tier Option

**New to AWS?** This configuration includes a **free tier optimized** setup that can run within AWS Free Tier limits (for new accounts).

- **Cost**: $0/month within free tier limits
- **Configuration**: Single t2.micro instance with minimal storage
- **Perfect for**: Learning, development, and testing

👉 **[See Free Tier Guide](README-FreeTier.md)** for detailed setup instructions and cost optimization.

## 🏗️ Architecture Overview

The infrastructure includes:

- **VPC** with public subnets across multiple Availability Zones
- **3 EC2 instances** running Cassandra (one per AZ for high availability)
- **Security Groups** with proper Cassandra ports configured
- **EBS volumes** for persistent data storage
- **Elastic IPs** for stable networking (optional)
- **IAM roles** for CloudWatch monitoring
- **CloudWatch logging** for centralized log management

## 📋 Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** installed (>= 1.0)
3. **SSH key pair** for accessing instances
4. **AWS permissions** for creating VPC, EC2, IAM, and CloudWatch resources

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
cd aws-topology/cassandra-cluster
```

### 2. Generate SSH Key Pair

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cassandra-cluster-key
```

### 3. Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file
vim terraform.tfvars
```

**Important**: Update the following required variables:
- `public_key`: Content of your public key file (`~/.ssh/cassandra-cluster-key.pub`)
- `ssh_allowed_cidr`: Your IP address for SSH access (e.g., `["203.0.113.0/32"]`)

### 4. Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Deploy the resources
terraform apply
```

### 5. Connect to Your Cluster

After deployment, Terraform will output connection information:

```bash
# SSH to first node (seed node)
ssh -i ~/.ssh/cassandra-cluster-key ec2-user@<ELASTIC_IP_1>

# Check cluster status
/opt/cassandra/bin/nodetool status

# Connect to Cassandra with CQL shell
/opt/cassandra/bin/cqlsh <PRIVATE_IP>
```

## 📊 Cluster Configuration

### Default Settings

| Component | Configuration |
|-----------|---------------|
| **Nodes** | 3 (configurable) |
| **Instance Type** | m5.large |
| **Cassandra Version** | 4.1.3 |
| **Data Center** | dc1 |
| **Replication Strategy** | SimpleStrategy |
| **Storage** | 100GB EBS gp3 per node |
| **Java** | Amazon Corretto 11 |

### Cassandra Ports

| Port | Service | Access |
|------|---------|--------|
| 9042 | CQL Native Transport | Cluster internal |
| 7000 | Inter-node communication | Cluster internal |
| 7001 | SSL Inter-node | Cluster internal |
| 7199 | JMX | Cluster internal |
| 9160 | Thrift (legacy) | Cluster internal |
| 22 | SSH | External (restricted) |

## 🔧 Configuration Options

### Variables Reference

#### Basic Configuration
```hcl
cluster_name  = "my-cassandra-cluster"
node_count    = 3                    # 3-10 nodes supported
environment   = "production"
aws_region    = "us-east-1"
```

#### Instance Configuration
```hcl
instance_type     = "m5.xlarge"      # Scale up for production
root_volume_size  = 20               # GB
data_volume_size  = 500              # GB - adjust for your data needs
```

#### Security Configuration
```hcl
ssh_allowed_cidr = ["10.0.0.0/8"]   # Restrict to your network
public_key       = "ssh-rsa AAAA..."  # Your SSH public key
```

### Instance Type Recommendations

| Use Case | Instance Type | Memory | vCPUs | Storage Rec. |
|----------|--------------|---------|-------|--------------|
| **Development** | t3.medium | 4 GB | 2 | 50-100 GB |
| **Testing** | m5.large | 8 GB | 2 | 100-200 GB |
| **Production (Small)** | m5.xlarge | 16 GB | 4 | 200-500 GB |
| **Production (Large)** | r5.2xlarge | 64 GB | 8 | 500+ GB |

## 📱 Operations Guide

### Connecting to Cassandra

```bash
# Using CQL Shell locally
/opt/cassandra/bin/cqlsh <NODE_PRIVATE_IP>

# From your local machine (if properly configured)
cqlsh <NODE_PUBLIC_IP> 9042
```

### Common CQL Commands

```sql
-- Check cluster status
SELECT cluster_name, listen_address FROM system.local;

-- View all keyspaces
DESCRIBE KEYSPACES;

-- Create a keyspace
CREATE KEYSPACE mykeyspace 
WITH REPLICATION = {
    'class' : 'SimpleStrategy',
    'replication_factor' : 3
};

-- Use keyspace
USE mykeyspace;

-- Create a table
CREATE TABLE users (
    id UUID PRIMARY KEY,
    name TEXT,
    email TEXT,
    created_at TIMESTAMP
);
```

### Monitoring Commands

```bash
# Check cluster status
/opt/cassandra/bin/nodetool status

# Check node info
/opt/cassandra/bin/nodetool info

# Check ring status
/opt/cassandra/bin/nodetool ring

# Check compaction status
/opt/cassandra/bin/nodetool compactionstats

# Check repair status
/opt/cassandra/bin/nodetool repair

# View logs
sudo tail -f /var/log/cassandra/system.log
```

## 🔍 Monitoring and Logging

### CloudWatch Integration

The cluster automatically sends logs to CloudWatch:

- **System Logs**: `/aws/ec2/${cluster_name}/cassandra-system`
- **GC Logs**: `/aws/ec2/${cluster_name}/cassandra-gc`
- **Installation Logs**: `/aws/ec2/${cluster_name}/user-data`

### JMX Monitoring

Each node exposes JMX metrics on port 7199:

```bash
# Connect with JConsole or other JMX tools
jconsole <NODE_IP>:7199
```

### Health Checks

```bash
# Run health check script
/opt/cassandra/bin/health-check.sh

# Check service status
sudo systemctl status cassandra
```

## 🛡️ Security Best Practices

### Network Security

1. **Restrict SSH Access**: Update `ssh_allowed_cidr` to your specific IP range
2. **Use VPN**: Consider placing nodes in private subnets with VPN access
3. **Security Groups**: Default security groups allow cluster-internal communication only

### Data Security

```hcl
# Enable encryption
enable_encryption_at_rest    = true
enable_encryption_in_transit = true
```

### Authentication (Production)

Update `/etc/cassandra/cassandra.yaml`:

```yaml
authenticator: PasswordAuthenticator
authorizer: CassandraAuthorizer
```

Then create users:

```sql
-- Create admin user
CREATE ROLE admin WITH PASSWORD = 'strong_password' 
    AND SUPERUSER = true 
    AND LOGIN = true;

-- Create application user
CREATE ROLE app_user WITH PASSWORD = 'app_password' 
    AND LOGIN = true;

-- Grant permissions
GRANT ALL ON KEYSPACE mykeyspace TO app_user;
```

## 💰 Cost Optimization

### Estimated Monthly Costs (us-east-1)

| Component | Configuration | Monthly Cost |
|-----------|---------------|--------------|
| **EC2 Instances** | 3 × m5.large | ~$207 |
| **EBS Storage** | 3 × 100GB gp3 | ~$30 |
| **Elastic IPs** | 3 × EIP | ~$11 |
| **Data Transfer** | Inter-AZ | ~$9 |
| **Total** | | **~$257** |

### Cost Reduction Tips

1. **Use Reserved Instances**: Save up to 75% with 1-3 year commitments
2. **Right-size Instances**: Start with smaller instances, monitor, and scale up
3. **Optimize Storage**: Use gp2 instead of gp3 if IOPS requirements are lower
4. **Remove Elastic IPs**: If stable IPs aren't required (not recommended for production)

## 🔄 Scaling Operations

### Adding Nodes

1. Update `node_count` in `terraform.tfvars`
2. Run `terraform apply`
3. New nodes will automatically join the cluster

### Scaling Instance Types

1. Update `instance_type` in `terraform.tfvars`
2. Run `terraform apply`
3. Instances will be replaced with new types

⚠️ **Warning**: Scaling operations may cause temporary service interruption

## 🚨 Troubleshooting

### Common Issues

#### 1. SSH Connection Refused
```bash
# Check security group allows SSH from your IP
# Verify key pair is correct
ssh -i ~/.ssh/cassandra-cluster-key ec2-user@<IP> -v
```

#### 2. Cassandra Won't Start
```bash
# Check logs
sudo tail -f /var/log/cassandra/system.log

# Check disk space
df -h

# Check Java process
ps aux | grep cassandra
```

#### 3. Nodes Can't Communicate
```bash
# Check security groups allow inter-cluster communication
# Verify network connectivity
telnet <OTHER_NODE_IP> 7000
```

#### 4. High Memory Usage
```bash
# Check heap settings in /etc/cassandra/jvm.options
# Adjust -Xms and -Xmx values
# Restart Cassandra: sudo systemctl restart cassandra
```

### Log Locations

```bash
# Cassandra logs
/var/log/cassandra/system.log
/var/log/cassandra/gc.log

# Installation logs
/var/log/user-data.log

# System logs
/var/log/messages
```

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will permanently delete all data. Ensure you have backups!

## 📚 Additional Resources

- [Apache Cassandra Documentation](https://cassandra.apache.org/doc/)
- [AWS EC2 Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-best-practices.html)
- [Cassandra Operations Guide](https://cassandra.apache.org/doc/latest/operating/)
- [DataStax Academy](https://academy.datastax.com/) - Free Cassandra training

## 🤝 Support

For issues with this Terraform configuration:
1. Check the troubleshooting section above
2. Review AWS CloudWatch logs
3. Consult Cassandra documentation for database-specific issues

## 📄 License

This configuration is provided as-is for educational and operational purposes.