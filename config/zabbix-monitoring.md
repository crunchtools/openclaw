# Zabbix Monitoring Configuration for OpenClaw

Host: lotor.dc3.crunchtools.com (hostid: 10698)

## Items to Create

### 1. TCP port check — OpenClaw Gateway

| Field | Value |
|-------|-------|
| Name | TCP port check - openclaw.crunchtools.com |
| Type | Zabbix agent (0) |
| Key | `net.tcp.service[tcp,127.0.0.1,18789]` |
| Value type | Unsigned integer (3) |
| Update interval | 1m |
| Description | OpenClaw gateway TCP port check (autonomous agent - RT #1406) |

### 2. TCP port check — Signal API Sidecar

| Field | Value |
|-------|-------|
| Name | TCP port check - signal-api.crunchtools.com |
| Type | Zabbix agent (0) |
| Key | `net.tcp.service[tcp,127.0.0.1,8093]` |
| Value type | Unsigned integer (3) |
| Update interval | 1m |
| Description | Signal CLI REST API sidecar for OpenClaw (RT #1406) |

## Triggers to Create

### 1. OpenClaw Gateway DOWN

| Field | Value |
|-------|-------|
| Name | openclaw.crunchtools.com container port 18789 is DOWN |
| Expression | `last(/lotor.dc3.crunchtools.com/net.tcp.service[tcp,127.0.0.1,18789])=0` |
| Priority | High (4) |

### 2. Signal API Sidecar DOWN

| Field | Value |
|-------|-------|
| Name | signal-api.crunchtools.com container port 8093 is DOWN |
| Expression | `last(/lotor.dc3.crunchtools.com/net.tcp.service[tcp,127.0.0.1,8093])=0` |
| Priority | High (4) |

## service-checker.py Integration

Add OpenClaw to the service-checker script at `/srv/zabbix-agent.crunchtools.com/scripts/service-checker.py`. The check should verify the `openclaw` process is running inside the container:

```python
# Add to service list:
{"name": "openclaw.crunchtools.com", "process": "node"}
{"name": "signal-api.crunchtools.com", "process": "java"}
```

## Notes

- Items will report DOWN until containers are deployed — that's expected
- OpenClaw uses port 18789 (non-standard), so `tcp` check instead of `http`
- Signal sidecar uses port 8093 (remapped from container's 8080 to avoid acquacotta conflict)
- Zabbix MCP server is read-only — create these items manually via Zabbix UI or API
