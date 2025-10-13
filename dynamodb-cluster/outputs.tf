# Outputs for DynamoDB Cluster

output "main_table_name" {
  description = "Name of the main DynamoDB table"
  value       = aws_dynamodb_table.main_table.name
}

output "main_table_arn" {
  description = "ARN of the main DynamoDB table"
  value       = aws_dynamodb_table.main_table.arn
}

output "main_table_stream_arn" {
  description = "ARN of the main DynamoDB table stream"
  value       = var.enable_streams ? aws_dynamodb_table.main_table.stream_arn : null
}

output "additional_table_names" {
  description = "Names of additional DynamoDB tables"
  value       = aws_dynamodb_table.additional_tables[*].name
}

output "additional_table_arns" {
  description = "ARNs of additional DynamoDB tables"
  value       = aws_dynamodb_table.additional_tables[*].arn
}

output "table_endpoints" {
  description = "DynamoDB endpoints for all tables"
  value = {
    main_table = {
      name     = aws_dynamodb_table.main_table.name
      arn      = aws_dynamodb_table.main_table.arn
      endpoint = "https://dynamodb.${var.aws_region}.amazonaws.com"
    }
    additional_tables = [
      for table in aws_dynamodb_table.additional_tables : {
        name     = table.name
        arn      = table.arn
        endpoint = "https://dynamodb.${var.aws_region}.amazonaws.com"
      }
    ]
  }
}

output "access_role_arn" {
  description = "ARN of the IAM role for DynamoDB access"
  value       = var.create_access_role ? aws_iam_role.dynamodb_access_role[0].arn : null
}

output "access_role_name" {
  description = "Name of the IAM role for DynamoDB access"
  value       = var.create_access_role ? aws_iam_role.dynamodb_access_role[0].name : null
}

output "instance_profile_name" {
  description = "Name of the instance profile for EC2 DynamoDB access"
  value       = var.create_access_role ? aws_iam_instance_profile.dynamodb_access_profile[0].name : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  value       = var.create_sns_topic ? aws_sns_topic.dynamodb_alerts[0].arn : null
}

output "cloudwatch_alarms" {
  description = "CloudWatch alarm names and ARNs"
  value = var.enable_monitoring ? {
    read_throttled_alarm = {
      name = aws_cloudwatch_metric_alarm.read_throttled_requests[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.read_throttled_requests[0].arn
    }
    write_throttled_alarm = {
      name = aws_cloudwatch_metric_alarm.write_throttled_requests[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.write_throttled_requests[0].arn
    }
  } : null
}

output "connection_details" {
  description = "Connection details for applications"
  value = {
    region             = var.aws_region
    main_table_name    = aws_dynamodb_table.main_table.name
    endpoint           = "https://dynamodb.${var.aws_region}.amazonaws.com"
    access_key_id      = "Use IAM role or AWS credentials"
    secret_access_key  = "Use IAM role or AWS credentials"
    billing_mode       = var.billing_mode
    
    # SDK connection examples
    sdk_config = {
      aws_cli = "aws dynamodb list-tables --region ${var.aws_region}"
      boto3   = "boto3.resource('dynamodb', region_name='${var.aws_region}')"
      aws_sdk_js = "new AWS.DynamoDB({region: '${var.aws_region}'})"
    }
  }
}

output "free_tier_status" {
  description = "Free tier usage information"
  value = var.free_tier_mode ? {
    enabled = true
    notes = [
      "DynamoDB Free Tier includes:",
      "- 25 GB of storage",
      "- 25 RCU and 25 WCU of provisioned capacity",
      "- 2.5M stream read requests (if streams enabled)",
      "- Data transfer is charged separately"
    ]
    current_config = {
      billing_mode    = var.billing_mode
      read_capacity   = var.billing_mode == "PROVISIONED" ? var.read_capacity : "On-demand"
      write_capacity  = var.billing_mode == "PROVISIONED" ? var.write_capacity : "On-demand"
      storage_cost    = "First 25 GB free, then $0.25/GB/month"
    }
  } : {
    enabled = false
    notes   = ["Free tier optimizations not enabled"]
  }
}

output "cost_estimation" {
  description = "Estimated monthly costs"
  value = {
    free_tier_eligible = var.free_tier_mode
    estimated_costs = var.billing_mode == "PAY_PER_REQUEST" ? {
      model = "On-demand pricing"
      read_requests = "$0.25 per million read requests"
      write_requests = "$1.25 per million write requests"
      storage = "First 25 GB free (free tier), then $0.25/GB/month"
      note = "Actual costs depend on usage patterns"
    } : {
      model = "Provisioned capacity"
      read_capacity = "${var.read_capacity} RCU at $0.00013/hour/RCU"
      write_capacity = "${var.write_capacity} WCU at $0.00065/hour/WCU"
      storage = "First 25 GB free (free tier), then $0.25/GB/month"
      free_tier_savings = var.free_tier_mode ? "Up to 25 RCU and 25 WCU free with free tier" : "Not using free tier optimizations"
    }
  }
}

output "operational_commands" {
  description = "Useful operational commands"
  value = {
    aws_cli = {
      list_tables     = "aws dynamodb list-tables --region ${var.aws_region}"
      describe_table  = "aws dynamodb describe-table --table-name ${aws_dynamodb_table.main_table.name} --region ${var.aws_region}"
      scan_table      = "aws dynamodb scan --table-name ${aws_dynamodb_table.main_table.name} --region ${var.aws_region}"
      put_item        = "aws dynamodb put-item --table-name ${aws_dynamodb_table.main_table.name} --item '{\"${var.hash_key}\":{\"S\":\"example\"}}' --region ${var.aws_region}"
    }
    monitoring = {
      cloudwatch_metrics = "aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name ConsumedReadCapacityUnits --dimensions Name=TableName,Value=${aws_dynamodb_table.main_table.name} --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 3600 --statistics Average --region ${var.aws_region}"
    }
  }
}

output "security_recommendations" {
  description = "Security best practices and recommendations"
  value = {
    encryption = {
      enabled = var.enable_encryption
      kms_key = var.kms_key_id != null ? "Customer managed KMS key" : "AWS managed key"
      recommendation = var.enable_encryption ? "✅ Encryption enabled" : "⚠️ Enable encryption for production workloads"
    }
    access_control = {
      iam_role_created = var.create_access_role
      recommendation = "Use IAM roles and policies for fine-grained access control"
      least_privilege = "Grant only necessary DynamoDB permissions to applications"
    }
    monitoring = {
      enabled = var.enable_monitoring
      recommendation = var.enable_monitoring ? "✅ Monitoring enabled" : "⚠️ Enable monitoring for production workloads"
    }
    point_in_time_recovery = {
      enabled = var.enable_point_in_time_recovery
      recommendation = var.enable_point_in_time_recovery ? "✅ Point-in-time recovery enabled" : "⚠️ Enable PITR for data protection"
    }
  }
}