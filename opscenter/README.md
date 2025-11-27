# Cassandra Web - Monitoring UI

Cassandra Web provides a simple web-based UI for monitoring and managing your Cassandra cluster.

## Features

- **Keyspace Browser**: Explore keyspaces and tables
- **CQL Query Interface**: Execute queries directly from the browser
- **Cluster Information**: View cluster topology and node details
- **Data Explorer**: Browse table data with pagination
- **Schema Viewer**: Inspect table schemas and indexes

## Deployment

### Prerequisites
- Cassandra cluster must be running (from `cassandra/` directory)
- Docker daemon accessible

### Deploy Cassandra Web

```bash
cd opscenter
terraform init
terraform plan
terraform apply -auto-approve
```

### Access Web UI

Open your browser to: **http://localhost:3000**

The UI will automatically connect to `cassandra-node1:9042`.

## Usage

### Browse Data
1. Navigate to http://localhost:3000
2. Select a keyspace from the dropdown
3. Click on a table to view its data
4. Use pagination controls to browse records

### Execute Queries
1. Go to the Query tab
2. Enter your CQL query
3. Click Execute
4. View results in the table below

### View Cluster Info
- Check the Cluster tab for node information
- View replication settings
- Monitor keyspace configurations

## Port Mapping

| Port | Purpose          |
|------|------------------|
| 3000 | Web UI           |

## Alternative Monitoring

### Using nodetool
```bash
# Check cluster status
docker exec cassandra-node1 nodetool status

# View cluster info
docker exec cassandra-node1 nodetool info

# Check data distribution
docker exec cassandra-node1 nodetool ring
```

### Using cqlsh
```bash
# Connect to cluster
docker exec -it cassandra-node1 cqlsh

# List keyspaces
DESCRIBE KEYSPACES;

# Use a keyspace
USE system;

# Show tables
DESCRIBE TABLES;

# Query data
SELECT * FROM system.local;
```

## Cleanup

```bash
terraform destroy -auto-approve
```

This will remove Cassandra Web but preserve the Cassandra cluster.

## Troubleshooting

### Can't Connect to Cassandra
```bash
# Check if Cassandra nodes are up
docker ps | grep cassandra

# Verify network connectivity
docker exec cassandra-web ping cassandra-node1

# Check Cassandra Web logs
docker logs cassandra-web
```

### Web UI Not Loading
```bash
# Check if container is running
docker ps | grep cassandra-web

# Restart container
docker restart cassandra-web

# Check port binding
docker port cassandra-web
```

## Features Overview

### Keyspace Management
- View all keyspaces
- See replication strategies
- Check durable writes settings

### Table Operations
- Browse table schemas
- View column definitions
- Check primary keys and indexes
- Explore partition keys

### Query Interface
- Execute SELECT queries
- Run INSERT/UPDATE/DELETE
- View query results
- Export data (copy from browser)

## Additional Resources

- [Cassandra Web GitHub](https://github.com/markusgulden/cassandra-web)
- [CQL Reference](https://cassandra.apache.org/doc/latest/cql/)
