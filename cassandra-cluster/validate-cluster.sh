#!/bin/bash

# Cassandra Cluster Validation Script
# This script validates that the Cassandra cluster is properly deployed and configured

set -e

echo "🔍 Cassandra Cluster Validation Script"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if terraform outputs are available
if ! terraform output > /dev/null 2>&1; then
    echo -e "${RED}❌ Terraform outputs not available. Run 'terraform apply' first.${NC}"
    exit 1
fi

echo "📊 Getting cluster information..."
CLUSTER_NAME=$(terraform output -json cluster_summary | jq -r '.cluster_name')
NODE_COUNT=$(terraform output -json cluster_summary | jq -r '.node_count')
REGION=$(terraform output -json cluster_summary | jq -r '.region')

echo "🏷️  Cluster Name: $CLUSTER_NAME"
echo "🔢 Node Count: $NODE_COUNT"
echo "🌍 Region: $REGION"
echo ""

# Get IP addresses
ELASTIC_IPS=$(terraform output -json cassandra_elastic_ips 2>/dev/null || echo '[]')
PUBLIC_IPS=$(terraform output -json cassandra_public_ips)
PRIVATE_IPS=$(terraform output -json cassandra_private_ips)

# Determine which IPs to use for external connection
if [ "$ELASTIC_IPS" != "[]" ] && [ "$ELASTIC_IPS" != "null" ]; then
    EXTERNAL_IPS="$ELASTIC_IPS"
    echo "🌐 Using Elastic IPs for external connections"
else
    EXTERNAL_IPS="$PUBLIC_IPS"
    echo "🌐 Using Public IPs for external connections"
fi

echo ""
echo "🔍 Testing Connectivity..."
echo "=========================="

# Function to test SSH connectivity
test_ssh() {
    local ip=$1
    local node_name=$2
    
    echo -n "🔌 Testing SSH to $node_name ($ip)... "
    
    if timeout 10 ssh -i ~/.ssh/cassandra-cluster-key -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@$ip "echo 'SSH OK'" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Function to test Cassandra service
test_cassandra_service() {
    local ip=$1
    local node_name=$2
    
    echo -n "🗄️  Testing Cassandra service on $node_name ($ip)... "
    
    if timeout 10 ssh -i ~/.ssh/cassandra-cluster-key -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@$ip "sudo systemctl is-active cassandra" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ ACTIVE${NC}"
        return 0
    else
        echo -e "${RED}❌ NOT ACTIVE${NC}"
        return 1
    fi
}

# Function to test Cassandra CQL connectivity
test_cql_connectivity() {
    local external_ip=$1
    local private_ip=$2
    local node_name=$3
    
    echo -n "🔗 Testing CQL connectivity to $node_name... "
    
    if timeout 15 ssh -i ~/.ssh/cassandra-cluster-key -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@$external_ip "/opt/cassandra/bin/cqlsh $private_ip -e 'SELECT cluster_name FROM system.local;'" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Test each node
ssh_success=0
service_success=0
cql_success=0
total_nodes=0

for i in $(seq 0 $((NODE_COUNT-1))); do
    external_ip=$(echo $EXTERNAL_IPS | jq -r ".[$i]")
    private_ip=$(echo $PRIVATE_IPS | jq -r ".[$i]")
    node_name="node-$((i+1))"
    
    echo ""
    echo "🖥️  Testing $node_name:"
    echo "   External IP: $external_ip"
    echo "   Private IP: $private_ip"
    
    # Test SSH
    if test_ssh "$external_ip" "$node_name"; then
        ((ssh_success++))
        
        # Test Cassandra service
        if test_cassandra_service "$external_ip" "$node_name"; then
            ((service_success++))
            
            # Test CQL connectivity
            if test_cql_connectivity "$external_ip" "$private_ip" "$node_name"; then
                ((cql_success++))
            fi
        fi
    fi
    
    ((total_nodes++))
done

echo ""
echo "📋 Test Results Summary:"
echo "========================"
echo "🔌 SSH Connectivity: $ssh_success/$total_nodes"
echo "🗄️  Cassandra Service: $service_success/$total_nodes"
echo "🔗 CQL Connectivity: $cql_success/$total_nodes"

# Overall health check
if [ $ssh_success -eq $total_nodes ] && [ $service_success -eq $total_nodes ] && [ $cql_success -eq $total_nodes ]; then
    echo ""
    echo -e "${GREEN}🎉 ALL TESTS PASSED! Cluster is healthy.${NC}"
    
    # Get cluster status from seed node
    echo ""
    echo "🏥 Cluster Status:"
    echo "=================="
    seed_ip=$(echo $EXTERNAL_IPS | jq -r '.[0]')
    ssh -i ~/.ssh/cassandra-cluster-key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@$seed_ip '/opt/cassandra/bin/nodetool status' 2>/dev/null || echo "Could not retrieve cluster status"
    
    echo ""
    echo "🚀 Quick Start Commands:"
    echo "======================="
    echo "# Connect to seed node:"
    echo "ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$seed_ip"
    echo ""
    echo "# Connect to CQL shell:"
    seed_private_ip=$(echo $PRIVATE_IPS | jq -r '.[0]')
    echo "ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$seed_ip '/opt/cassandra/bin/cqlsh $seed_private_ip'"
    echo ""
    echo "# Check cluster status:"
    echo "ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$seed_ip '/opt/cassandra/bin/nodetool status'"
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ SOME TESTS FAILED! Please check the nodes.${NC}"
    
    if [ $ssh_success -ne $total_nodes ]; then
        echo -e "${YELLOW}⚠️  SSH issues may be due to security group configuration or key permissions.${NC}"
    fi
    
    if [ $service_success -ne $total_nodes ]; then
        echo -e "${YELLOW}⚠️  Cassandra service issues may require checking logs: /var/log/cassandra/system.log${NC}"
    fi
    
    if [ $cql_success -ne $total_nodes ]; then
        echo -e "${YELLOW}⚠️  CQL connectivity issues may require waiting longer for Cassandra to fully start.${NC}"
    fi
    
    echo ""
    echo "🔍 Troubleshooting:"
    echo "==================="
    echo "1. Check security groups allow SSH (port 22) from your IP"
    echo "2. Verify SSH key permissions: chmod 600 ~/.ssh/cassandra-cluster-key"
    echo "3. Wait a few minutes for Cassandra to fully initialize"
    echo "4. Check CloudWatch logs for detailed error information"
    
    exit 1
fi