# Money Transfer Monitoring Stack

Complete observability stack for the Money Transfer application.

## Quick Start
```bash
# Start monitoring
./start.sh

# Stop monitoring
./stop.sh

# View logs
./logs.sh [service]

# Check status
./status.sh

# Restart services
./restart.sh
```

## Access

- **Grafana**: http://localhost:3000
  - Username: `admin`
  - Password: `admin123`
  
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

## Services

- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **AlertManager** - Alert routing and notification
- **Node Exporter** - System metrics

## Key Metrics

### Application
- `http_server_requests_seconds_count` - Request count
- `http_server_requests_seconds_bucket` - Response times
- `jvm_memory_used_bytes` - Memory usage
- `money_transfer_count_total` - Transfer count

### System
- `node_cpu_seconds_total` - CPU usage
- `node_memory_MemAvailable_bytes` - Available memory
- `node_filesystem_avail_bytes` - Disk space

## Deployment to EC2

See `../deploy-monitoring.sh` for deployment instructions.
