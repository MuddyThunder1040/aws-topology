# Outputs for Cassandra Cluster Infrastructure

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.cassandra_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.cassandra_vpc.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.cassandra_public_subnets[*].id
}

output "security_group_id" {
  description = "ID of the Cassandra security group"
  value       = aws_security_group.cassandra_sg.id
}

# Auto Scaling Group outputs
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.cassandra_asg.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.cassandra_asg.arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.cassandra_template.id
}

# Load Balancer outputs
output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.cassandra_alb.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.cassandra_alb.zone_id
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.cassandra_alb.arn
}

output "network_load_balancer_dns_name" {
  description = "DNS name of the network load balancer (if created)"
  value       = var.use_network_load_balancer && var.create_load_balancer ? aws_lb.cassandra_nlb[0].dns_name : null
}

# Target Group outputs
output "cassandra_target_group_arn" {
  description = "ARN of the Cassandra CQL target group"
  value       = aws_lb_target_group.cassandra_cql_tg.arn
}

output "health_check_target_group_arn" {
  description = "ARN of the health check target group"
  value       = aws_lb_target_group.cassandra_health_tg.arn
}

output "key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.cassandra_key.key_name
}

output "iam_role_arn" {
  description = "ARN of the IAM role for Cassandra instances"
  value       = aws_iam_role.cassandra_role.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.cassandra_logs.name
}

# Auto Scaling Policies
output "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  value       = aws_autoscaling_policy.cassandra_scale_up.arn
}

output "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  value       = aws_autoscaling_policy.cassandra_scale_down.arn
}

# Connection information
output "cassandra_connection_info" {
  description = "Cassandra connection information"
  value = {
    load_balancer_endpoint = "${aws_lb.cassandra_alb.dns_name}:9042"
    nlb_endpoint          = var.use_network_load_balancer && var.create_load_balancer ? "${aws_lb.cassandra_nlb[0].dns_name}:9042" : null
    health_check_endpoint = "http://${aws_lb.cassandra_alb.dns_name}/health"
    cql_port             = 9042
    monitoring_port      = 7199
  }
}

output "connection_examples" {
  description = "Example connection commands"
  value = {
    cqlsh_via_lb = "cqlsh ${aws_lb.cassandra_alb.dns_name} 9042"
    health_check = "curl http://${aws_lb.cassandra_alb.dns_name}/health"
    python_driver = "cluster = Cluster(['${aws_lb.cassandra_alb.dns_name}'], port=9042)"
  }
}

# Scaling configuration
output "scaling_configuration" {
  description = "Auto scaling configuration details"
  value = {
    min_size             = var.asg_min_size
    max_size             = var.asg_max_size
    desired_capacity     = var.asg_desired_capacity
    cpu_high_threshold   = var.cpu_high_threshold
    cpu_low_threshold    = var.cpu_low_threshold
    health_check_type    = "ELB"
    health_check_grace_period = 300
  }
}

# Cluster summary
output "cluster_summary" {
  description = "Summary of the Cassandra cluster"
  value = {
    cluster_name      = var.cluster_name
    node_count        = var.node_count
    instance_type     = var.instance_type
    cassandra_version = var.cassandra_version
    data_center       = var.cassandra_data_center
    region            = var.aws_region
    vpc_id            = aws_vpc.cassandra_vpc.id
    environment       = var.environment
  }
}

# Resource ARNs for reference
output "resource_arns" {
  description = "ARNs of created resources"
  value = {
    iam_role                = aws_iam_role.cassandra_role.arn
    iam_instance_profile    = aws_iam_instance_profile.cassandra_profile.arn
    cloudwatch_log_group    = aws_cloudwatch_log_group.cassandra_logs.arn
    security_group          = aws_security_group.cassandra_sg.arn
    launch_template         = aws_launch_template.cassandra_template.arn
    load_balancer          = aws_lb.cassandra_alb.arn
    autoscaling_group      = aws_autoscaling_group.cassandra_asg.arn
  }
}

# Cost estimation information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    ec2_instances_min = "~$${var.asg_min_size * 69.12} (${var.asg_min_size} x ${var.instance_type} minimum)" # m5.large pricing
    ec2_instances_max = "~$${var.asg_max_size * 69.12} (${var.asg_max_size} x ${var.instance_type} maximum)"
    ebs_storage      = "~$${var.asg_desired_capacity * (var.root_volume_size * 0.10 + var.data_volume_size * 0.10)} (${var.asg_desired_capacity} nodes avg)"
    load_balancer    = "~$22.50 (ALB)"
    data_transfer    = "~$9.00 (estimated inter-AZ transfer)"
    cloudwatch_logs  = "~$5.00 (estimated log ingestion)"
    total_estimate   = "~$${var.asg_desired_capacity * 69.12 + var.asg_desired_capacity * (var.root_volume_size * 0.10 + var.data_volume_size * 0.10) + 22.50 + 9.00 + 5.00}"
  }
}

# Monitoring and maintenance
output "monitoring_endpoints" {
  description = "Monitoring and maintenance endpoints"
  value = {
    cloudwatch_logs    = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.cassandra_logs.name, "/", "$252F")}"
    autoscaling_console = "https://console.aws.amazon.com/ec2/home?region=${var.aws_region}#AutoScalingGroupDetails:id=${aws_autoscaling_group.cassandra_asg.name}"
    load_balancer_console = "https://console.aws.amazon.com/ec2/home?region=${var.aws_region}#LoadBalancer:loadBalancerArn=${aws_lb.cassandra_alb.arn}"
    cloudwatch_alarms  = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#alarmsV2:search=${var.cluster_name}"
    health_check_url   = "http://${aws_lb.cassandra_alb.dns_name}/health"
  }
}