# Local Values for Cassandra Cluster

locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Environment = var.environment
    Project     = "cassandra-cluster"
    ManagedBy   = "terraform"
    Owner       = data.aws_caller_identity.current.user_id
    Region      = data.aws_region.current.name
  }

  # Cluster-specific tags
  cluster_tags = merge(local.common_tags, {
    ClusterName = var.cluster_name
    NodeCount   = var.node_count
  })

  # Calculate the number of AZs to use
  az_count = min(length(data.aws_availability_zones.available.names), var.node_count)

  # Create a map of node information
  nodes = {
    for i in range(var.node_count) : "node-${i + 1}" => {
      index            = i
      name            = "${var.cluster_name}-node-${i + 1}"
      availability_zone = data.aws_availability_zones.available.names[i % local.az_count]
      subnet_index     = i % local.az_count
      is_seed         = i == 0  # First node is always seed
      rack_name       = "${var.cassandra_rack_prefix}${(i % local.az_count) + 1}"
    }
  }

  # Security group rules for Cassandra
  cassandra_ports = {
    ssh = {
      port        = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidr
      description = "SSH access"
    }
    cql = {
      port        = 9042
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "CQL native transport"
    }
    storage = {
      port        = 7000
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "Inter-node storage"
    }
    ssl_storage = {
      port        = 7001
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "SSL inter-node storage"
    }
    jmx = {
      port        = 7199
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "JMX monitoring"
    }
    thrift = {
      port        = 9160
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "Thrift client API"
    }
  }

  # User data template variables
  user_data_vars = {
    cluster_name           = var.cluster_name
    node_count            = var.node_count
    cassandra_version     = var.cassandra_version
    cassandra_heap_size   = var.cassandra_heap_size
    cassandra_data_center = var.cassandra_data_center
    enable_monitoring     = var.enable_monitoring
  }
}