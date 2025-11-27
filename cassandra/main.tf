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

# Create a network for Cassandra nodes
resource "docker_network" "cassandra_network" {
  name = "cassandra-network"
  driver = "bridge"
}

# Cassandra Node 1 (Seed Node)
resource "docker_container" "cassandra_node1" {
  name  = "cassandra-node1"
  image = docker_image.cassandra.image_id
  
  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  ports {
    internal = 9042
    external = 9042
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
    volume_name    = docker_volume.cassandra_data1.name
  }

  restart = "unless-stopped"
}

# Cassandra Node 2
resource "docker_container" "cassandra_node2" {
  name  = "cassandra-node2"
  image = docker_image.cassandra.image_id
  
  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  ports {
    internal = 9042
    external = 9043
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
    volume_name    = docker_volume.cassandra_data2.name
  }

  restart = "unless-stopped"
  
  depends_on = [docker_container.cassandra_node1]
}

# Cassandra Node 3
resource "docker_container" "cassandra_node3" {
  name  = "cassandra-node3"
  image = docker_image.cassandra.image_id
  
  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  ports {
    internal = 9042
    external = 9044
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
    volume_name    = docker_volume.cassandra_data3.name
  }

  restart = "unless-stopped"
  
  depends_on = [docker_container.cassandra_node1]
}

# Cassandra Node 4
resource "docker_container" "cassandra_node4" {
  name  = "cassandra-node4"
  image = docker_image.cassandra.image_id
  
  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  ports {
    internal = 9042
    external = 9045
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
    volume_name    = docker_volume.cassandra_data4.name
  }

  restart = "unless-stopped"
  
  depends_on = [docker_container.cassandra_node1]
}

# Docker image
resource "docker_image" "cassandra" {
  name = "cassandra:latest"
}

# Volumes for persistent storage
resource "docker_volume" "cassandra_data1" {
  name = "cassandra-data1"
}

resource "docker_volume" "cassandra_data2" {
  name = "cassandra-data2"
}

resource "docker_volume" "cassandra_data3" {
  name = "cassandra-data3"
}

resource "docker_volume" "cassandra_data4" {
  name = "cassandra-data4"
}
