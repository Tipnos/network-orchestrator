---
id: constitution
version: 0.1.0
status: draft
owner: shared
depends_on: []
---

# Constitution

Project-wide rules that every service and shared crate must follow. A service's own specs may add rules, never relax these.

## Configuration

- **CONSTITUTION-001**: A service's environment variables MUST start with the service's name in uppercase, with `-` replaced by `_`, followed by `_`: for example `API_MAX_SERVERS`, or `HARDWARE_CONTROLLER_` for the hardware-controller service. In production each service runs in its own container, but locally and in agent sandboxes several services share one environment, and unprefixed names would collide.
