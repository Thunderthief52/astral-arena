# Eddard coordinator deployment boundary

## Confirmed infrastructure

Eddard already runs `cloudflared` as a system service with its live configuration at `/etc/cloudflared/config.yml`. A candidate configuration and an installation helper demonstrate a backup, validation, restart, health-check, and rollback workflow.

The proposed Astral Arena allocation is:

```text
public hostname: arena.ozlabs.dev
local listener: 127.0.0.1:8095
```

The hostname appeared unassigned and the port was free when inspected on 2026-07-26. This is a reservation in the design only: no DNS route, tunnel ingress, service, or public endpoint has been created.

## Architecture

```text
BG3 Script Extender mod
        │ local JSON outbox/inbox
        ▼
Windows companion application
        │ authenticated HTTPS
        ▼
arena.ozlabs.dev (Cloudflare Tunnel)
        │ localhost forwarding
        ▼
Eddard coordinator on 127.0.0.1:8095
        │
        ├── snapshot validation and quarantine
        ├── level/ruleset opponent pools
        ├── friend-code and tournament state
        └── SQLite persistence and audit metadata
```

Script Extender remains responsible for game state and local file exchange. The companion application is responsible for all external networking. The coordinator never accepts raw save files or executable mod code.

## Minimum public-service safeguards

Before adding the Cloudflare ingress rule, the coordinator must have:

- a versioned health endpoint and a local systemd service;
- strict request-size and JSON-schema limits;
- snapshot UUID allowlists and progression validation;
- anonymous installation credentials or short-lived friend codes;
- upload rate limits and replay protection;
- no public player names or other personal information;
- SQLite backups and a quarantine table for rejected snapshots;
- structured logs that omit secrets and full snapshot bodies.

Cloudflare Access can protect an early private test, but application-level authentication is still required before community matchmaking.

## Safe activation sequence

1. Build and test the coordinator on `127.0.0.1:8095`.
2. Install it as an unprivileged systemd service and verify its local health endpoint.
3. Back up the live Cloudflare configuration.
4. Add `arena.ozlabs.dev` before the catch-all ingress rule and validate the candidate configuration.
5. Restart `cloudflared`, verify the public health endpoint, and roll back automatically on failure.
6. Initially restrict access to the developers and a small invited test group.

The existing Eddard helper is project-specific, so Astral Arena should get its own deployment script with the same rollback pattern rather than editing the live configuration ad hoc.
