output "cassandra_node1_port" {
  description = "CQL port for Cassandra Node 1"
  value       = 9042
}

output "cassandra_node2_port" {
  description = "CQL port for Cassandra Node 2"
  value       = 9043
}

output "cassandra_node3_port" {
  description = "CQL port for Cassandra Node 3"
  value       = 9044
}

output "cassandra_node4_port" {
  description = "CQL port for Cassandra Node 4"
  value       = 9045
}

output "connection_string" {
  description = "How to connect to the cluster"
  value       = "Connect using: cqlsh localhost 9042"
}

output "cluster_status" {
  description = "Command to check cluster status"
  value       = "docker exec -it cassandra-node1 nodetool status"
}
