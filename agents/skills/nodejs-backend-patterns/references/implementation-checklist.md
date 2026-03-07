# Node.js Service Checklist

Use this checklist when creating or reviewing a Node.js backend service.

## Request Boundary

- Validate request params, body, and headers at the boundary.
- Return structured errors with stable status codes.
- Enforce auth and authorization before business logic.

## Service Structure

- Keep transport handlers thin.
- Move domain logic into services or use-case modules.
- Keep persistence access behind repositories or focused data modules when the codebase is large enough to justify the split.

## Operations

- Use explicit config loading and fail fast on missing critical settings.
- Emit structured logs.
- Handle startup and shutdown predictably.
- Add health or readiness endpoints when the deployment model expects them.

## Data and Side Effects

- Keep transactional boundaries explicit.
- Make retries, idempotency, and rate limiting deliberate for webhooks, jobs, or external calls.
- Use background work only when the response path should not wait on side effects.

## Testing

- Add focused tests at the boundary where behavior changes.
- Prefer integration tests for request validation and error shape.
- Mock external systems only at the edge of the service.
