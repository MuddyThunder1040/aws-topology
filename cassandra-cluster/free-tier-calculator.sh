#!/bin/bash

# AWS Free Tier Cost Calculator for Cassandra Cluster
# This script helps estimate your AWS costs based on the configuration

echo "🧮 AWS Free Tier Cost Calculator - Cassandra Cluster"
echo "=================================================="
echo

# Read terraform.tfvars if it exists
if [ -f "terraform.tfvars" ]; then
    echo "📁 Reading configuration from terraform.tfvars..."
    
    # Extract key values
    INSTANCE_TYPE=$(grep -E "^instance_type" terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "t2.micro")
    ASG_DESIRED=$(grep -E "^asg_desired_capacity" terraform.tfvars | cut -d'=' -f2 | tr -d ' ' 2>/dev/null || echo "1")
    ROOT_SIZE=$(grep -E "^root_volume_size" terraform.tfvars | cut -d'=' -f2 | tr -d ' ' 2>/dev/null || echo "8")
    DATA_SIZE=$(grep -E "^data_volume_size" terraform.tfvars | cut -d'=' -f2 | tr -d ' ' 2>/dev/null || echo "20")
    CREATE_LB=$(grep -E "^create_load_balancer" terraform.tfvars | cut -d'=' -f2 | tr -d ' ' 2>/dev/null || echo "false")
    
else
    echo "⚠️  terraform.tfvars not found, using defaults..."
    INSTANCE_TYPE="t2.micro"
    ASG_DESIRED=1
    ROOT_SIZE=8
    DATA_SIZE=20
    CREATE_LB="false"
fi

echo
echo "📊 Current Configuration:"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Number of Instances: $ASG_DESIRED"
echo "  Root Volume Size: ${ROOT_SIZE} GB"
echo "  Data Volume Size: ${DATA_SIZE} GB"
echo "  Load Balancer: $CREATE_LB"
echo

# Calculate costs
TOTAL_STORAGE=$((ROOT_SIZE * ASG_DESIRED + DATA_SIZE * ASG_DESIRED))
MONTHLY_HOURS=$((ASG_DESIRED * 744))  # 744 hours per month per instance

echo "💰 Cost Breakdown:"
echo "=================="

# EC2 Costs
if [ "$INSTANCE_TYPE" = "t2.micro" ]; then
    if [ $MONTHLY_HOURS -le 750 ]; then
        echo "  ✅ EC2 (t2.micro): \$0.00 (within 750 free hours)"
    else
        OVERAGE_HOURS=$((MONTHLY_HOURS - 750))
        OVERAGE_COST=$(echo "scale=2; $OVERAGE_HOURS * 0.0116" | bc 2>/dev/null || echo "~$OVERAGE_HOURS * 0.0116")
        echo "  ⚠️  EC2 (t2.micro): \$$OVERAGE_COST (${OVERAGE_HOURS}h over free tier)"
    fi
else
    echo "  ❌ EC2 ($INSTANCE_TYPE): Not free tier eligible - check AWS pricing"
fi

# EBS Costs
if [ $TOTAL_STORAGE -le 30 ]; then
    echo "  ✅ EBS Storage: \$0.00 (${TOTAL_STORAGE} GB within 30 GB free)"
else
    OVERAGE_GB=$((TOTAL_STORAGE - 30))
    OVERAGE_COST=$(echo "scale=2; $OVERAGE_GB * 0.10" | bc 2>/dev/null || echo "~$OVERAGE_GB * 0.10")
    echo "  ⚠️  EBS Storage: \$$OVERAGE_COST (${OVERAGE_GB} GB over free tier)"
fi

# Load Balancer Costs
if [ "$CREATE_LB" = "true" ]; then
    echo "  ❌ Load Balancer: ~\$16.20/month (NOT covered by free tier)"
else
    echo "  ✅ Load Balancer: \$0.00 (disabled)"
fi

# Other potential costs
echo "  ✅ Data Transfer: \$0.00 (assuming < 1GB outbound/month)"
echo "  ✅ CloudWatch: \$0.00 (basic monitoring, detailed disabled)"
echo "  ✅ KMS: \$0.00 (encryption disabled)"

echo
echo "🎯 Free Tier Recommendations:"
echo "============================="

# Recommendations
if [ "$INSTANCE_TYPE" != "t2.micro" ]; then
    echo "  ⚠️  Change instance_type to 't2.micro' for free tier"
fi

if [ $ASG_DESIRED -gt 1 ]; then
    echo "  ⚠️  Reduce asg_desired_capacity to 1 for free tier"
fi

if [ $TOTAL_STORAGE -gt 30 ]; then
    echo "  ⚠️  Reduce total storage to ≤30 GB (currently ${TOTAL_STORAGE} GB)"
    RECOMMENDED_DATA=$((30 - ROOT_SIZE))
    echo "      Suggestion: Set data_volume_size to $RECOMMENDED_DATA"
fi

if [ "$CREATE_LB" = "true" ]; then
    echo "  ⚠️  Disable load balancer (set create_load_balancer = false)"
fi

echo
echo "🏷️  Free Tier Limits (12 months for new AWS accounts):"
echo "======================================================"
echo "  • 750 hours/month of t2.micro EC2 instances"
echo "  • 30 GB/month of EBS General Purpose (gp2) storage"
echo "  • 1 GB/month of outbound data transfer"
echo "  • Basic CloudWatch monitoring (5-minute metrics)"
echo
echo "📚 To optimize for free tier:"
echo "  cp terraform.tfvars.example terraform.tfvars"
echo "  # Edit terraform.tfvars with the recommendations above"
echo
echo "💡 Monitor your usage: https://console.aws.amazon.com/billing/home#/freetier"

# Check if bc is installed for calculations
if ! command -v bc &> /dev/null; then
    echo
    echo "📝 Note: Install 'bc' for precise cost calculations: brew install bc"
fi