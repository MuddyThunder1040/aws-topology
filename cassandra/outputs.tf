output "node_count" {
  description = "Number of Cassandra nodes created"
  value       = var.node_count
}

output "node_ports" {
  description = "CQL ports for all Cassandra nodes"
  value = {
    for i in range(var.node_count) :
    "cassandra-node${i + 1}" => 9042 + i
  }
}

output "connection_string" {
  description = "How to connect to the cluster"
  value       = "Connect using: cqlsh localhost 9042"
}

output "cluster_status" {
  description = "Command to check cluster status"
  value       = "docker exec -it cassandra-node1 nodetool status"
}

output "all_nodes" {
  description = "List of all Cassandra node names"
  value       = [for i in range(var.node_count) : "cassandra-node${i + 1}"]
}
