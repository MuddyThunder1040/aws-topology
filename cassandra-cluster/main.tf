# Main Terraform configuration for 3-node Cassandra EC2 cluster
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "cassandra-cluster"
      ManagedBy   = "terraform"
    }
  }
}

# Data sources are defined in data.tf

# Create VPC
resource "aws_vpc" "cassandra_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "cassandra_igw" {
  vpc_id = aws_vpc.cassandra_vpc.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Create public subnets for each AZ
resource "aws_subnet" "cassandra_public_subnets" {
  count = var.node_count

  vpc_id                  = aws_vpc.cassandra_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-subnet-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  }
}

# Create route table for public subnets
resource "aws_route_table" "cassandra_public_rt" {
  vpc_id = aws_vpc.cassandra_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cassandra_igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Associate route table with public subnets
resource "aws_route_table_association" "cassandra_public_rta" {
  count = var.node_count

  subnet_id      = aws_subnet.cassandra_public_subnets[count.index].id
  route_table_id = aws_route_table.cassandra_public_rt.id
}

# Security Group for Cassandra cluster
resource "aws_security_group" "cassandra_sg" {
  name_prefix = "${var.cluster_name}-sg"
  vpc_id      = aws_vpc.cassandra_vpc.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr
  }

  # Cassandra CQL native transport port
  ingress {
    description = "Cassandra CQL"
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Cassandra inter-node communication (storage port)
  ingress {
    description = "Cassandra Storage"
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Cassandra SSL storage port
  ingress {
    description = "Cassandra SSL Storage"
    from_port   = 7001
    to_port     = 7001
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # JMX monitoring port
  ingress {
    description = "JMX"
    from_port   = 7199
    to_port     = 7199
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Cassandra Thrift client API (legacy)
  ingress {
    description = "Cassandra Thrift"
    from_port   = 9160
    to_port     = 9160
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-security-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create key pair for EC2 instances
resource "aws_key_pair" "cassandra_key" {
  key_name   = "${var.cluster_name}-key"
  public_key = var.public_key
}

# IAM role for Cassandra instances
resource "aws_iam_role" "cassandra_role" {
  name = "${var.cluster_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CloudWatch monitoring
resource "aws_iam_role_policy" "cassandra_cloudwatch" {
  name = "${var.cluster_name}-cloudwatch-policy"
  role = aws_iam_role.cassandra_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile for Cassandra role
resource "aws_iam_instance_profile" "cassandra_profile" {
  name = "${var.cluster_name}-profile"
  role = aws_iam_role.cassandra_role.name
}

# Launch template for Cassandra instances
resource "aws_launch_template" "cassandra_template" {
  name_prefix   = "${var.cluster_name}-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.cassandra_key.key_name

  vpc_security_group_ids = [aws_security_group.cassandra_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.cassandra_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type          = var.data_volume_iops == 0 ? "gp2" : "gp3"  # Use gp2 for free tier
      delete_on_termination = true
      encrypted            = var.enable_encryption_at_rest  # Conditional encryption
    }
  }

  # Additional EBS volume for Cassandra data
  block_device_mappings {
    device_name = "/dev/xvdf"
    ebs {
      volume_size           = var.data_volume_size
      volume_type          = var.data_volume_iops == 0 ? "gp2" : "gp3"  # Use gp2 for free tier
      delete_on_termination = true
      encrypted            = var.enable_encryption_at_rest  # Conditional encryption
      iops                 = var.data_volume_iops == 0 ? null : var.data_volume_iops
      throughput           = var.data_volume_throughput == 0 ? null : var.data_volume_throughput
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = var.cluster_name
    node_count   = var.node_count
    cassandra_heap_size = var.cassandra_heap_size
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-node"
      Type = "cassandra"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "cassandra_alb_sg" {
  name_prefix = "${var.cluster_name}-alb-sg"
  vpc_id      = aws_vpc.cassandra_vpc.id

  # HTTP access for health checks
  ingress {
    description = "HTTP Health Check"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Cassandra CQL port for client connections
  ingress {
    description = "Cassandra CQL"
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    cidr_blocks = var.client_allowed_cidr
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-alb-security-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Update Cassandra security group to allow ALB traffic
resource "aws_security_group_rule" "cassandra_from_alb" {
  type                     = "ingress"
  from_port                = 9042
  to_port                  = 9042
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cassandra_alb_sg.id
  security_group_id        = aws_security_group.cassandra_sg.id
  description              = "Allow ALB to access Cassandra CQL port"
}

# Update Cassandra security group to allow health check traffic
resource "aws_security_group_rule" "cassandra_health_check" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cassandra_alb_sg.id
  security_group_id        = aws_security_group.cassandra_sg.id
  description              = "Allow ALB health checks"
}

# Create key pair for EC2 instances (moved up for dependency)
resource "aws_key_pair" "cassandra_key" {
  key_name   = "${var.cluster_name}-key"
  public_key = var.public_key
}

# Application Load Balancer for Cassandra
resource "aws_lb" "cassandra_alb" {
  name               = "${var.cluster_name}-alb"
  internal           = var.internal_load_balancer
  load_balancer_type = "application"
  security_groups    = [aws_security_group.cassandra_alb_sg.id]
  subnets            = aws_subnet.cassandra_public_subnets[*].id

  enable_deletion_protection = var.enable_deletion_protection

  access_logs {
    bucket  = var.enable_access_logs ? aws_s3_bucket.alb_logs[0].bucket : ""
    prefix  = "cassandra-alb"
    enabled = var.enable_access_logs
  }

  tags = {
    Name = "${var.cluster_name}-alb"
  }

  depends_on = [aws_internet_gateway.cassandra_igw]
}

# S3 bucket for ALB access logs (conditional)
resource "aws_s3_bucket" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket        = "${var.cluster_name}-alb-logs-${random_string.bucket_suffix[0].result}"
  force_destroy = true

  tags = {
    Name = "${var.cluster_name}-alb-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_string" "bucket_suffix" {
  count = var.enable_access_logs ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

# Target group for Cassandra CQL port
resource "aws_lb_target_group" "cassandra_cql_tg" {
  name     = "${var.cluster_name}-cql-tg"
  port     = 9042
  protocol = "TCP"
  vpc_id   = aws_vpc.cassandra_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "8080"
    protocol            = "HTTP"
    path                = "/health"
    timeout             = 6
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "${var.cluster_name}-cql-target-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target group for health check endpoint
resource "aws_lb_target_group" "cassandra_health_tg" {
  name     = "${var.cluster_name}-health-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.cassandra_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "HTTP"
    path                = "/health"
    timeout             = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "${var.cluster_name}-health-target-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Listener for CQL port
resource "aws_lb_listener" "cassandra_cql" {
  load_balancer_arn = aws_lb.cassandra_alb.arn
  port              = "9042"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cassandra_cql_tg.arn
  }

  tags = {
    Name = "${var.cluster_name}-cql-listener"
  }
}

# ALB Listener for health check
resource "aws_lb_listener" "cassandra_health" {
  load_balancer_arn = aws_lb.cassandra_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cassandra_health_tg.arn
  }

  tags = {
    Name = "${var.cluster_name}-health-listener"
  }
}

# Auto Scaling Group for Cassandra nodes
resource "aws_autoscaling_group" "cassandra_asg" {
  name                = "${var.cluster_name}-asg"
  vpc_zone_identifier = aws_subnet.cassandra_public_subnets[*].id
  target_group_arns   = [
    aws_lb_target_group.cassandra_cql_tg.arn,
    aws_lb_target_group.cassandra_health_tg.arn
  ]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  default_cooldown          = 300
  
  # Use launch template
  launch_template {
    id      = aws_launch_template.cassandra_template.id
    version = "$Latest"
  }

  # Instance distribution for mixed instance types (optional)
  dynamic "mixed_instances_policy" {
    for_each = var.enable_mixed_instances ? [1] : []
    content {
      instances_distribution {
        on_demand_base_capacity                  = var.on_demand_base_capacity
        on_demand_percentage_above_base_capacity = var.on_demand_percentage
        spot_allocation_strategy                 = "diversified"
      }
      
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.cassandra_template.id
          version            = "$Latest"
        }
        
        dynamic "override" {
          for_each = var.instance_types
          content {
            instance_type = override.value
          }
        }
      }
    }
  }

  # ASG Tags
  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Type"
    value               = "cassandra"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "cassandra-cluster"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

  # Lifecycle configuration
  lifecycle {
    create_before_destroy = true
    ignore_changes       = [desired_capacity]
  }

  # Dependencies
  depends_on = [
    aws_lb_target_group.cassandra_cql_tg,
    aws_lb_target_group.cassandra_health_tg,
    aws_internet_gateway.cassandra_igw
  ]
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "cassandra_scale_up" {
  name                   = "${var.cluster_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.cassandra_asg.name

  policy_type = "SimpleScaling"
}

resource "aws_autoscaling_policy" "cassandra_scale_down" {
  name                   = "${var.cluster_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.cassandra_asg.name

  policy_type = "SimpleScaling"
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "cassandra_cpu_high" {
  alarm_name          = "${var.cluster_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "This alarm monitors cassandra cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.cassandra_scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.cassandra_asg.name
  }

  tags = {
    Name = "${var.cluster_name}-cpu-high-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "cassandra_cpu_low" {
  alarm_name          = "${var.cluster_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = var.cpu_low_threshold
  alarm_description   = "This alarm monitors cassandra cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.cassandra_scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.cassandra_asg.name
  }

  tags = {
    Name = "${var.cluster_name}-cpu-low-alarm"
  }
}

# Network Load Balancer for better Cassandra performance (alternative to ALB)
resource "aws_lb" "cassandra_nlb" {
  count = var.create_load_balancer && var.use_network_load_balancer ? 1 : 0

  name               = "${var.cluster_name}-nlb"
  internal           = var.internal_load_balancer
  load_balancer_type = "network"
  subnets            = aws_subnet.cassandra_public_subnets[*].id

  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Name = "${var.cluster_name}-nlb"
  }

  depends_on = [aws_internet_gateway.cassandra_igw]
}

# NLB Target group for Cassandra CQL port  
resource "aws_lb_target_group" "cassandra_nlb_tg" {
  count = var.create_load_balancer && var.use_network_load_balancer ? 1 : 0

  name     = "${var.cluster_name}-nlb-tg"
  port     = 9042
  protocol = "TCP"
  vpc_id   = aws_vpc.cassandra_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "9042"
    protocol            = "TCP"
    timeout             = 6
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.cluster_name}-nlb-target-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# NLB Listener for CQL port
resource "aws_lb_listener" "cassandra_nlb_cql" {
  count = var.create_load_balancer && var.use_network_load_balancer ? 1 : 0

  load_balancer_arn = aws_lb.cassandra_nlb[0].arn
  port              = "9042"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cassandra_nlb_tg[0].arn
  }

  tags = {
    Name = "${var.cluster_name}-nlb-cql-listener"
  }
}

# CloudWatch Log Group for Cassandra logs
resource "aws_cloudwatch_log_group" "cassandra_logs" {
  name              = "/aws/ec2/${var.cluster_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.cluster_name}-logs"
  }
}