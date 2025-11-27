# Cassandra Multi-Node Cluster with Terraform + Docker

This Terraform configuration deploys a configurable multi-node Cassandra cluster using Docker on your local Ubuntu laptop.

## Features

- **Dynamic node count**: Create 1 to 10 Cassandra nodes
- **Persistent storage**: Each node has its own Docker volume
- **Automatic networking**: All nodes connected via Docker bridge network
- **Seed node**: First node acts as the cluster seed
- **Port mapping**: Sequential ports (9042, 9043, 9044, ...)

## Prerequisites

1. **Docker** must be installed and running
   ```bash
   sudo apt update
   sudo apt install docker.io
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   ```

2. **Terraform** must be installed
   ```bash
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

## Configuration

### Set Number of Nodes

Edit `terraform.tfvars` to configure the cluster size:

```hcl
# Number of Cassandra nodes to create (1-10)
node_count = 4
```

Or pass it as a variable during apply:
```bash
terraform apply -var="node_count=6"
```

## Deployment

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Plan the deployment**
   ```bash
   terraform plan
   ```

3. **Deploy the cluster**
   ```bash
   terraform apply
   ```
   Type `yes` when prompted.

4. **Wait for cluster to stabilize** (takes 2-3 minutes)
   ```bash
   sleep 120
   ```

## Verify Cluster

Check cluster status:
```bash
docker exec -it cassandra-node1 nodetool status
```

You should see all nodes in UN (Up/Normal) state:
```
Datacenter: dc1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens  Owns (effective)  Host ID                               Rack
UN  172.x.x.x   xxx KB     256     xx.x%             ...                                   rack1
UN  172.x.x.x   xxx KB     256     xx.x%             ...                                   rack1
UN  172.x.x.x   xxx KB     256     xx.x%             ...                                   rack1
UN  172.x.x.x   xxx KB     256     xx.x%             ...                                   rack1
```

## Connect to Cassandra

Connect using cqlsh:
```bash
docker exec -it cassandra-node1 cqlsh
```

Or from host (if cqlsh is installed):
```bash
cqlsh localhost 9042
```

## Test the Cluster

Create a keyspace with replication:
```sql
CREATE KEYSPACE test_keyspace 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};

USE test_keyspace;

CREATE TABLE users (
    user_id UUID PRIMARY KEY,
    username TEXT,
    email TEXT
);

INSERT INTO users (user_id, username, email) 
VALUES (uuid(), 'john_doe', 'john@example.com');

SELECT * FROM users;
```

## Cluster Ports

The ports are dynamically assigned based on node count:
- **Node 1**: localhost:9042
- **Node 2**: localhost:9043
- **Node 3**: localhost:9044
- **Node N**: localhost:9042+(N-1)

Check all ports with:
```bash
terraform output node_ports
```

## Scaling the Cluster

### Increase Nodes

1. Update `terraform.tfvars`:
   ```hcl
   node_count = 6  # Increase from 4 to 6
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

### Decrease Nodes

⚠️ **Warning**: Reducing nodes will remove data. Back up first!

1. Update `terraform.tfvars`:
   ```hcl
   node_count = 2  # Decrease from 4 to 2
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

## Destroy Cluster

To remove all containers and volumes:
```bash
terraform destroy
```

## Troubleshooting

**Check logs for any node:**
```bash
docker logs cassandra-node1
docker logs cassandra-node2
# ... etc
```

**Check container status:**
```bash
docker ps -a | grep cassandra
```

**Restart a node:**
```bash
docker restart cassandra-node1
```

**Check which nodes are running:**
```bash
terraform output all_nodes
```

**Access a node shell:**
```bash
docker exec -it cassandra-node1 bash
```

## Architecture

- **Cluster Name**: cassandra-cluster
- **Datacenter**: dc1
- **Rack**: rack1
- **Seed Node**: cassandra-node1
- **Replication Strategy**: GossipingPropertyFileSnitch
- **Network**: cassandra-network (bridge)
- **Persistent Storage**: Docker volumes for each node

## Notes

- Node 1 is the seed node
- All nodes use the same cluster name for proper gossip protocol
- Data persists in Docker volumes even if containers are stopped
- Cluster takes 1-2 minutes to fully bootstrap
- Each node has isolated persistent storage
