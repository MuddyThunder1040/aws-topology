output "opscenter_url" {
  description = "OpsCenter Web UI URL"
  value       = "http://localhost:8888"
}

output "opscenter_container_id" {
  description = "OpsCenter container ID"
  value       = docker_container.opscenter.id
}

output "opscenter_container_name" {
  description = "OpsCenter container name"
  value       = docker_container.opscenter.name
}

output "connection_instructions" {
  description = "Instructions to connect OpsCenter to Cassandra cluster"
  value       = <<-EOT
    
    🔍 DataStax OpsCenter Monitoring
    ================================
    
    Web UI:     http://localhost:8888
    
    📊 Setup Instructions:
    1. Open http://localhost:8888 in your browser
    2. Click "Manage Existing Cluster"
    3. Enter cluster details:
       - Host: cassandra-node1
       - Port: 9042
    4. OpsCenter will discover all 4 nodes
    
    📈 Monitoring Features:
    - Real-time cluster metrics
    - Node health status
    - Query performance tracking
    - Repair scheduling
    - Backup management
    
    🔧 Alternative: Using nodetool
    docker exec cassandra-node1 nodetool status
    
  EOT
}
