output "cassandra_web_url" {
  description = "Cassandra Web UI URL"
  value       = "http://localhost:3000"
}

output "cassandra_web_container_id" {
  description = "Cassandra Web container ID"
  value       = docker_container.cassandra_web.id
}

output "cassandra_web_container_name" {
  description = "Cassandra Web container name"
  value       = docker_container.cassandra_web.name
}

output "connection_instructions" {
  description = "Instructions to access Cassandra monitoring"
  value       = <<-EOT
    
    🔍 Cassandra Web Monitoring UI
    ================================
    
    Web UI:     http://localhost:3000
    
    📊 Features:
    - Browse keyspaces and tables
    - Execute CQL queries
    - View cluster information
    - Monitor node status
    - Table data explorer
    
    🔧 Alternative: Using cqlsh
    docker exec -it cassandra-node1 cqlsh
    
    📈 Check Cluster Status:
    docker exec cassandra-node1 nodetool status
    
  EOT
}
