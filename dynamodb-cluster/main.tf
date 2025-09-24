# DynamoDB Cluster Configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = "DynamoDB-Cluster"
      ManagedBy     = "Terraform"
      Owner         = var.cluster_name
      CreatedBy     = "Jenkins-Pipeline"
    }
  }
}

# DynamoDB Table for main data
resource "aws_dynamodb_table" "main_table" {
  name           = "${var.cluster_name}-main"
  billing_mode   = var.billing_mode
  hash_key       = var.hash_key
  range_key      = var.range_key
  
  # Provisioned throughput (only used if billing_mode is PROVISIONED)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  dynamic "attribute" {
    for_each = var.range_key != null ? [1] : []
    content {
      name = var.range_key
      type = var.range_key_type
    }
  }

  # Global Secondary Indexes
  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = global_secondary_index.value.projection_type
      
      read_capacity  = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  # Local Secondary Indexes
  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes
    content {
      name            = local_secondary_index.value.name
      range_key       = local_secondary_index.value.range_key
      projection_type = local_secondary_index.value.projection_type
    }
  }

  # Encryption
  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_id  = var.enable_encryption && var.kms_key_id != null ? var.kms_key_id : null
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # TTL
  dynamic "ttl" {
    for_each = var.ttl_attribute != null ? [1] : []
    content {
      attribute_name = var.ttl_attribute
      enabled        = true
    }
  }

  # Streams
  stream_enabled   = var.enable_streams
  stream_view_type = var.enable_streams ? var.stream_view_type : null

  # Deletion protection
  deletion_protection_enabled = var.enable_deletion_protection

  tags = {
    Name        = "${var.cluster_name}-main"
    Type        = "dynamodb-table"
    Environment = var.environment
  }
}

# Additional tables for multi-table setup
resource "aws_dynamodb_table" "additional_tables" {
  count = length(var.additional_tables)
  
  name           = "${var.cluster_name}-${var.additional_tables[count.index].name}"
  billing_mode   = var.billing_mode
  hash_key       = var.additional_tables[count.index].hash_key
  range_key      = lookup(var.additional_tables[count.index], "range_key", null)
  
  read_capacity  = var.billing_mode == "PROVISIONED" ? lookup(var.additional_tables[count.index], "read_capacity", var.read_capacity) : null
  write_capacity = var.billing_mode == "PROVISIONED" ? lookup(var.additional_tables[count.index], "write_capacity", var.write_capacity) : null

  attribute {
    name = var.additional_tables[count.index].hash_key
    type = lookup(var.additional_tables[count.index], "hash_key_type", "S")
  }

  dynamic "attribute" {
    for_each = lookup(var.additional_tables[count.index], "range_key", null) != null ? [1] : []
    content {
      name = var.additional_tables[count.index].range_key
      type = lookup(var.additional_tables[count.index], "range_key_type", "S")
    }
  }

  server_side_encryption {
    enabled    = var.enable_encryption
    kms_key_id = var.enable_encryption && var.kms_key_id != null ? var.kms_key_id : null
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  deletion_protection_enabled = var.enable_deletion_protection

  tags = {
    Name        = "${var.cluster_name}-${var.additional_tables[count.index].name}"
    Type        = "dynamodb-table"
    Environment = var.environment
  }
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "read_throttled_requests" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.cluster_name}-read-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors read throttled requests"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    TableName = aws_dynamodb_table.main_table.name
  }

  tags = {
    Name        = "${var.cluster_name}-read-throttle-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "write_throttled_requests" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.cluster_name}-write-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors write throttled requests"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    TableName = aws_dynamodb_table.main_table.name
  }

  tags = {
    Name        = "${var.cluster_name}-write-throttle-alarm"
    Environment = var.environment
  }
}

# SNS Topic for notifications (optional)
resource "aws_sns_topic" "dynamodb_alerts" {
  count = var.create_sns_topic ? 1 : 0
  name  = "${var.cluster_name}-dynamodb-alerts"

  tags = {
    Name        = "${var.cluster_name}-alerts"
    Environment = var.environment
  }
}

# IAM Role for DynamoDB access (for applications)
resource "aws_iam_role" "dynamodb_access_role" {
  count = var.create_access_role ? 1 : 0
  name  = "${var.cluster_name}-dynamodb-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com", "lambda.amazonaws.com"]
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-access-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "dynamodb_access_policy" {
  count = var.create_access_role ? 1 : 0
  name  = "${var.cluster_name}-dynamodb-access-policy"
  role  = aws_iam_role.dynamodb_access_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = [
          aws_dynamodb_table.main_table.arn,
          "${aws_dynamodb_table.main_table.arn}/*"
        ]
      }
    ]
  })
}

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "dynamodb_access_profile" {
  count = var.create_access_role ? 1 : 0
  name  = "${var.cluster_name}-dynamodb-access-profile"
  role  = aws_iam_role.dynamodb_access_role[0].name
}