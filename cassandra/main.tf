terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Variable for number of Cassandra nodes
variable "node_count" {
  description = "Number of Cassandra nodes to create"
  type        = number
  default     = 4
  
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "Node count must be between 1 and 10."
  }
}

# Create a network for Cassandra nodes
resource "docker_network" "cassandra_network" {
  name = "cassandra-network"
  driver = "bridge"
}

# Docker image
resource "docker_image" "cassandra" {
  name = "cassandra:latest"
}

# Volumes for persistent storage (dynamic based on node_count)
resource "docker_volume" "cassandra_data" {
  count = var.node_count
  name  = "cassandra-data${count.index + 1}"
}

# Cassandra Nodes (dynamic based on node_count)
resource "docker_container" "cassandra_node" {
  count = var.node_count
  name  = "cassandra-node${count.index + 1}"
  image = docker_image.cassandra.image_id
  
  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  ports {
    internal = 9042
    external = 9042 + count.index
  }

  env = [
    "CASSANDRA_CLUSTER_NAME=cassandra-cluster",
    "CASSANDRA_DC=dc1",
    "CASSANDRA_RACK=rack1",
    "CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch",
    "CASSANDRA_SEEDS=cassandra-node1"
  ]

  volumes {
    container_path = "/var/lib/cassandra"
    volume_name    = docker_volume.cassandra_data[count.index].name
  }

  restart = "unless-stopped"
}
