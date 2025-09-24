# Variables for Cassandra Cluster Infrastructure

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the Cassandra cluster"
  type        = string
  default     = "cassandra-cluster"
}

variable "node_count" {
  description = "Number of Cassandra nodes to create"
  type        = number
  default     = 3
  
  validation {
    condition     = var.node_count >= 3 && var.node_count <= 10
    error_message = "Node count must be between 3 and 10 for a proper Cassandra cluster."
  }
}

variable "instance_type" {
  description = "EC2 instance type for Cassandra nodes"
  type        = string
  default     = "t2.micro"  # Changed default to free tier
  
  validation {
    condition = contains([
      "t2.micro", "t2.small", "t2.medium",  # Added free tier options
      "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge",
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a valid EC2 instance type. For free tier, use t2.micro."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "ssh_allowed_cidr" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Note: Restrict this in production
}

variable "public_key" {
  description = "Public key for EC2 key pair"
  type        = string
  default     = ""
  
  validation {
    condition     = var.public_key != ""
    error_message = "Public key must be provided for SSH access to instances."
  }
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB."
  }
}

variable "data_volume_size" {
  description = "Size of data EBS volume in GB for Cassandra data"
  type        = number
  default     = 20  # Reduced default for free tier
  
  validation {
    condition     = var.data_volume_size >= 8 && var.data_volume_size <= 1000  # Lowered minimum for free tier
    error_message = "Data volume size must be between 8 and 1000 GB. For free tier, keep total EBS usage under 30GB."
  }
}

variable "data_volume_iops" {
  description = "IOPS for data EBS volume (gp3 only). Set to 0 to use gp2 default (free tier)"
  type        = number
  default     = 0  # Changed to 0 for free tier (use gp2)
  
  validation {
    condition     = var.data_volume_iops == 0 || (var.data_volume_iops >= 3000 && var.data_volume_iops <= 16000)
    error_message = "Data volume IOPS must be 0 (for gp2/free tier) or between 3000 and 16000 (for gp3)."
  }
}

variable "data_volume_throughput" {
  description = "Throughput for data EBS volume in MB/s (gp3 only). Set to 0 to use gp2 default (free tier)"
  type        = number
  default     = 0  # Changed to 0 for free tier (use gp2)
  
  validation {
    condition     = var.data_volume_throughput == 0 || (var.data_volume_throughput >= 125 && var.data_volume_throughput <= 1000)
    error_message = "Data volume throughput must be 0 (for gp2/free tier) or between 125 and 1000 MB/s (for gp3)."
  }
}

variable "assign_elastic_ips" {
  description = "Whether to assign Elastic IPs to instances"
  type        = bool
  default     = true
}

variable "create_load_balancer" {
  description = "Whether to create an Application Load Balancer"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch log retention value."
  }
}

# Cassandra-specific configuration variables
variable "cassandra_version" {
  description = "Version of Cassandra to install"
  type        = string
  default     = "4.1.3"
}

variable "cassandra_heap_size" {
  description = "Cassandra heap size (e.g., 512M, 1G, 4G, 8G). Use 512M for t2.micro free tier."
  type        = string
  default     = "512M"  # Changed default for free tier compatibility
  
  validation {
    condition     = can(regex("^[0-9]+[GM]$", var.cassandra_heap_size))
    error_message = "Cassandra heap size must be in format like '512M', '1G', '4G' or '8G'."
  }
}

variable "cassandra_data_center" {
  description = "Cassandra data center name"
  type        = string
  default     = "dc1"
}

variable "cassandra_rack_prefix" {
  description = "Prefix for Cassandra rack names"
  type        = string
  default     = "rack"
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and logging"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 30
    error_message = "Backup retention days must be between 1 and 30."
  }
}

# Networking variables
variable "enable_private_subnets" {
  description = "Create private subnets for Cassandra nodes"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway for private subnets"
  type        = bool
  default     = false
}

# Security variables
variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for EBS volumes"
  type        = bool
  default     = true
}

variable "enable_encryption_in_transit" {
  description = "Enable encryption in transit for Cassandra"
  type        = bool
  default     = false
}

variable "additional_security_groups" {
  description = "Additional security group IDs to attach to instances"
  type        = list(string)
  default     = []
}

# Load Balancer variables
variable "client_allowed_cidr" {
  description = "CIDR blocks allowed for client connections to load balancer"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Note: Restrict this in production
}

variable "internal_load_balancer" {
  description = "Whether the load balancer should be internal (private)"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the load balancer"
  type        = bool
  default     = false
}

variable "enable_access_logs" {
  description = "Enable access logs for the load balancer"
  type        = bool
  default     = false
}

variable "use_network_load_balancer" {
  description = "Use Network Load Balancer instead of Application Load Balancer"
  type        = bool
  default     = true
}

# Auto Scaling Group variables
variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 3
  
  validation {
    condition     = var.asg_min_size >= 1 && var.asg_min_size <= 10
    error_message = "ASG minimum size must be between 1 and 10."
  }
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 6
  
  validation {
    condition     = var.asg_max_size >= 3 && var.asg_max_size <= 20
    error_message = "ASG maximum size must be between 3 and 20."
  }
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 3
  
  validation {
    condition     = var.asg_desired_capacity >= 1 && var.asg_desired_capacity <= 20
    error_message = "ASG desired capacity must be between 1 and 20."
  }
}

# Mixed Instance Policy variables
variable "enable_mixed_instances" {
  description = "Enable mixed instance types for cost optimization"
  type        = bool
  default     = false
}

variable "instance_types" {
  description = "List of instance types for mixed instance policy"
  type        = list(string)
  default     = ["t2.micro"]  # Changed default to free tier option
}

variable "on_demand_base_capacity" {
  description = "Absolute minimum amount of desired capacity that must be fulfilled by On-Demand instances"
  type        = number
  default     = 1
  
  validation {
    condition     = var.on_demand_base_capacity >= 0
    error_message = "On-demand base capacity must be non-negative."
  }
}

variable "on_demand_percentage" {
  description = "Percentage of On-Demand instances above base capacity (0-100)"
  type        = number
  default     = 50
  
  validation {
    condition     = var.on_demand_percentage >= 0 && var.on_demand_percentage <= 100
    error_message = "On-demand percentage must be between 0 and 100."
  }
}

# Auto Scaling thresholds
variable "cpu_high_threshold" {
  description = "CPU threshold for scaling up"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cpu_high_threshold >= 50 && var.cpu_high_threshold <= 95
    error_message = "CPU high threshold must be between 50 and 95."
  }
}

variable "cpu_low_threshold" {
  description = "CPU threshold for scaling down"
  type        = number
  default     = 30
  
  validation {
    condition     = var.cpu_low_threshold >= 10 && var.cpu_low_threshold <= 50
    error_message = "CPU low threshold must be between 10 and 50."
  }
}