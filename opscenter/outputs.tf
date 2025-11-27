output "opscenter_url" {
  description = "OpsCenter Web UI URL"
  value       = "http://localhost:8888"
}

output "opscenter_container_id" {
  description = "OpsCenter container ID"
  value       = docker_container.opscenter.id
}

output "opscenter_status" {
  description = "OpsCenter container status"
  value       = docker_container.opscenter.status
}

output "connection_instructions" {
  description = "Instructions to connect OpsCenter to Cassandra cluster"
  value       = <<-EOT
    
    🔍 DataStax OpsCenter Monitoring
    ================================
    
    Web UI:     http://localhost:8888
    
    📊 Setup Instructions:
    1. Open http://localhost:8888 in your browser
    2. Click "Add a Cluster"
    3. Enter cluster details:
       - Cluster Name: cassandra-cluster
       - Host IP: cassandra-node1
       - Port: 9042
    4. Click "Save Cluster"
    
    📈 Monitoring Features:
    - Real-time cluster metrics
    - Node health status
    - Query performance tracking
    - Alert configuration
    - Repair scheduling
    
    🔧 Alternative: Using nodetool
    docker exec cassandra-node1 nodetool status
    
  EOT
}
