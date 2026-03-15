# CrunchTools Autonomous Agent Code Review Standards

## Trust Boundary
- P-Agent (privileged) and Q-Agent (quarantined) MUST be separated
- P-Agent MUST NOT process raw untrusted content directly
- Q-Agent MUST NOT hold credentials or make tool calls
- Trust boundary enforced by deterministic software, NEVER by another LLM

## MCP Server Governance
- Only allowlisted MCP servers — no runtime discovery
- Every server scored on the 8-dimension scorecard (minimum B/15 for production)
- All tools classified by risk tier: read-only, write, system, network

## Runtime Security
- Circuit breakers required: max tool calls, token budget, repeated invocations, conversation depth
- Rate limiting per-tool, per-server, and global
- Audit logging as structured JSON — no credentials in logs
- Dead man's switch: pause if no human input within configured window

## Container Security
- Rootless execution, read-only root filesystem
- SELinux enforcing (`:Z` mounts)
- No host network, dropped capabilities
- All dependencies pinned to exact versions

## Versioning
- Semantic Versioning 2.0.0
- AI-assisted commits MUST include `Co-Authored-By` trailer
