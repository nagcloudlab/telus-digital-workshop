# Monitoring Stack

Local monitoring for Money Transfer application using Docker Compose.

## Quick Start
```bash
# Start monitoring stack
./start.sh

# Stop monitoring stack
./stop.sh

# View logs
./logs.sh [service]  # service: prometheus, grafana, alertmanager

# Check status
./status.sh
```

## Access

- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

## Architecture
```
Local Docker Compose
├── Prometheus (metrics database)
├── Grafana (dashboards)
├── AlertManager (alerting)
└── Node Exporter (system metrics)
     ↓
     Scrapes metrics from
     ↓
AWS EC2 (Money Transfer App)
```

## Key Metrics

- `up` - Service availability
- `http_server_requests_seconds_count` - Request rate
- `http_server_requests_seconds_bucket` - Response times
- `jvm_memory_used_bytes` - Memory usage
- `process_cpu_seconds_total` - CPU usage

## Alerts

- ApplicationDown - App unreachable for 1 min
- HighErrorRate - >5% errors for 2 min
- HighResponseTime - p95 >1s for 5 min
- HighMemoryUsage - >90% heap for 5 min
- HighCPU - >80% CPU for 5 min

## Dashboards

1. **Money Transfer - Overview**
   - Custom dashboard with key metrics
   
2. **JVM Micrometer** (ID: 4701)
   - Detailed JVM metrics
   
3. **Spring Boot** (ID: 12900)
   - Spring Boot specific metrics

## Troubleshooting
```bash
# Check container logs
docker-compose logs [service]

# Restart specific service
docker-compose restart [service]

# Rebuild after config change
docker-compose down
docker-compose up -d

# Update target IP
./update-targets.sh NEW_IP
```

## Configuration Files

- `docker-compose.yml` - Service definitions
- `prometheus/prometheus.yml` - Prometheus config
- `prometheus/alert_rules.yml` - Alert rules
- `grafana/provisioning/` - Grafana auto-config
- `alertmanager/alertmanager.yml` - Alert routing

## Update Target IP

If EC2 IP changes:
```bash
./update-targets.sh NEW_IP
```

## Backup Dashboards

Export from Grafana:
1. Dashboard → Settings → JSON Model
2. Copy JSON
3. Save to `grafana/dashboards/`
