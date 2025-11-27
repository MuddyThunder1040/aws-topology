# DataStax OpsCenter for Cassandra Monitoring

DataStax OpsCenter provides comprehensive monitoring and management for your Cassandra cluster.

## Features

- **Real-time Monitoring**: Live cluster metrics and performance data
- **Node Health**: Track the status of all Cassandra nodes
- **Query Analysis**: Performance tracking and optimization
- **Alerts**: Configurable alerts for cluster issues
- **Repair Management**: Schedule and track repair operations
- **Backup Management**: Configure and monitor backups

## Deployment

### Prerequisites
- Cassandra cluster must be running (from `cassandra/` directory)
- Docker daemon accessible

### Deploy OpsCenter

```bash
cd opscenter
terraform init
terraform plan
terraform apply -auto-approve
```

### Access Web UI

Open your browser to: **http://localhost:8888**

## Initial Setup

1. Navigate to http://localhost:8888
2. Click **"Add a Cluster"** or **"Manage Existing Cluster"**
3. Enter connection details:
   - **Cluster Name**: `cassandra-cluster`
   - **Host**: `cassandra-node1`
   - **Port**: `9042`
4. Click **"Save Cluster"**

OpsCenter will automatically discover all 4 nodes in your cluster.

## Port Mapping

| Port  | Purpose                    |
|-------|----------------------------|
| 8888  | Web UI                     |
| 61620 | Agent communication        |
| 61621 | Stomp protocol for agents  |

## Monitoring Capabilities

### Dashboard Views
- Cluster overview
- Individual node metrics
- Keyspace statistics
- Table performance
- Query latency tracking

### Metrics Tracked
- CPU usage
- Memory utilization
- Disk I/O
- Network throughput
- Read/Write latency
- Compaction progress
- GC activity

## Management Operations

From OpsCenter you can:
- Run repairs
- Take snapshots
- Restore from backups
- Add/remove nodes
- Configure alerts
- View logs
- Execute CQL queries

## Alternative Monitoring

### Using nodetool
```bash
# Check cluster status
docker exec cassandra-node1 nodetool status

# View cluster info
docker exec cassandra-node1 nodetool info

# Check gossip
docker exec cassandra-node1 nodetool gossipinfo
```

### Using cqlsh
```bash
# Connect to cluster
docker exec -it cassandra-node1 cqlsh

# Check system tables
SELECT * FROM system.peers;
SELECT * FROM system.local;
```

## Cleanup

```bash
terraform destroy -auto-approve
```

This will remove OpsCenter but preserve the Cassandra cluster.

## Integration with CI/CD

Use the OpsCenter Terraform operations pipeline to automate deployment:
- Add OpsCenter to your infrastructure as code
- Monitor cluster health in Jenkins
- Automate alerting and reporting

## Troubleshooting

### OpsCenter Can't Connect
```bash
# Check if Cassandra nodes are up
docker ps | grep cassandra

# Verify network connectivity
docker exec opscenter ping cassandra-node1

# Check OpsCenter logs
docker logs opscenter
```

### Performance Issues
- Ensure adequate resources for Docker
- Check node health: `docker exec cassandra-node1 nodetool status`
- Review OpsCenter logs for errors

## Additional Resources

- [OpsCenter Documentation](https://docs.datastax.com/en/opscenter/6.8/)
- [Cassandra Monitoring Best Practices](https://cassandra.apache.org/doc/latest/operating/metrics.html)
