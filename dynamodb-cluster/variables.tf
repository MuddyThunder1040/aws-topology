# Variables for DynamoDB Cluster Configuration

variable "aws_region" {
  description = "AWS region for DynamoDB deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "Name of the DynamoDB cluster (prefix for table names)"
  type        = string
  default     = "dynamodb-cluster"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.cluster_name))
    error_message = "Cluster name can only contain alphanumeric characters, hyphens, and underscores."
  }
}

variable "billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
  
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "Billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "hash_key" {
  description = "Hash key (partition key) for the main DynamoDB table"
  type        = string
  default     = "id"
}

variable "hash_key_type" {
  description = "Data type of the hash key"
  type        = string
  default     = "S"
  
  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "Hash key type must be S (String), N (Number), or B (Binary)."
  }
}

variable "range_key" {
  description = "Range key (sort key) for the main DynamoDB table"
  type        = string
  default     = null
}

variable "range_key_type" {
  description = "Data type of the range key"
  type        = string
  default     = "S"
  
  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "Range key type must be S (String), N (Number), or B (Binary)."
  }
}

variable "read_capacity" {
  description = "Read capacity units for provisioned billing mode"
  type        = number
  default     = 5
  
  validation {
    condition     = var.read_capacity >= 1 && var.read_capacity <= 40000
    error_message = "Read capacity must be between 1 and 40000."
  }
}

variable "write_capacity" {
  description = "Write capacity units for provisioned billing mode"
  type        = number
  default     = 5
  
  validation {
    condition     = var.write_capacity >= 1 && var.write_capacity <= 40000
    error_message = "Write capacity must be between 1 and 40000."
  }
}

variable "global_secondary_indexes" {
  description = "Global Secondary Indexes for the main table"
  type = list(object({
    name            = string
    hash_key        = string
    range_key       = optional(string)
    projection_type = string
    read_capacity   = optional(number)
    write_capacity  = optional(number)
  }))
  default = []
}

variable "local_secondary_indexes" {
  description = "Local Secondary Indexes for the main table"
  type = list(object({
    name            = string
    range_key       = string
    projection_type = string
  }))
  default = []
}

variable "additional_tables" {
  description = "Additional DynamoDB tables to create"
  type = list(object({
    name           = string
    hash_key       = string
    hash_key_type  = optional(string, "S")
    range_key      = optional(string)
    range_key_type = optional(string, "S")
    read_capacity  = optional(number)
    write_capacity = optional(number)
  }))
  default = []
}

variable "enable_encryption" {
  description = "Enable server-side encryption for DynamoDB tables"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for DynamoDB encryption (null for AWS managed key)"
  type        = string
  default     = null
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
}

variable "ttl_attribute" {
  description = "Attribute name for TTL (Time To Live)"
  type        = string
  default     = null
}

variable "enable_streams" {
  description = "Enable DynamoDB Streams"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Stream view type when streams are enabled"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
  
  validation {
    condition = contains([
      "KEYS_ONLY",
      "NEW_IMAGE",
      "OLD_IMAGE",
      "NEW_AND_OLD_IMAGES"
    ], var.stream_view_type)
    error_message = "Stream view type must be KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, or NEW_AND_OLD_IMAGES."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for DynamoDB tables"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (optional)"
  type        = string
  default     = null
}

variable "create_sns_topic" {
  description = "Create an SNS topic for notifications"
  type        = bool
  default     = false
}

variable "create_access_role" {
  description = "Create IAM role for DynamoDB access"
  type        = bool
  default     = true
}

# Free Tier specific variables
variable "free_tier_mode" {
  description = "Enable free tier optimizations"
  type        = bool
  default     = false
}

variable "free_tier_read_capacity" {
  description = "Read capacity for free tier (max 25 RCU free)"
  type        = number
  default     = 5
  
  validation {
    condition     = var.free_tier_read_capacity >= 1 && var.free_tier_read_capacity <= 25
    error_message = "Free tier read capacity must be between 1 and 25 RCU."
  }
}

variable "free_tier_write_capacity" {
  description = "Write capacity for free tier (max 25 WCU free)"
  type        = number
  default     = 5
  
  validation {
    condition     = var.free_tier_write_capacity >= 1 && var.free_tier_write_capacity <= 25
    error_message = "Free tier write capacity must be between 1 and 25 WCU."
  }
}

# Cost optimization variables
variable "enable_auto_scaling" {
  description = "Enable auto scaling for DynamoDB tables"
  type        = bool
  default     = false
}

variable "auto_scaling_read_target" {
  description = "Target utilization for read capacity auto scaling"
  type        = number
  default     = 70
  
  validation {
    condition     = var.auto_scaling_read_target >= 20 && var.auto_scaling_read_target <= 90
    error_message = "Auto scaling read target must be between 20 and 90 percent."
  }
}

variable "auto_scaling_write_target" {
  description = "Target utilization for write capacity auto scaling"
  type        = number
  default     = 70
  
  validation {
    condition     = var.auto_scaling_write_target >= 20 && var.auto_scaling_write_target <= 90
    error_message = "Auto scaling write target must be between 20 and 90 percent."
  }
}