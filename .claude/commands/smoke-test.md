# /smoke-test — Run kctl-env Smoke Tests

Run the integration smoke test suite and report results.

## Before starting — confidence gate

Ask questions until >98% confident about:
- Which branch/ref to test (default: current branch)
- Whether to skip the kubectl binary download (offline mode)
- Whether KCTL_ENV_ROOT should be isolated (always yes for safety)

## Steps

### 1. Show current branch
```bash
git branch --show-current
```

### 2. Run smoke test

**Standard run (downloads kubectl):**
```bash
SMOKE_REF=$(git branch --show-current) ./scripts/smoke-wsl.sh
```

**Offline run (skip binary download, useful in CI or slow networks):**
```bash
SKIP_KUBECTL_INSTALL=1 SMOKE_REF=$(git branch --show-current) ./scripts/smoke-wsl.sh
```

**Debug mode (verbose output):**
```bash
KCTL_ENV_DEBUG=1 SMOKE_REF=$(git branch --show-current) ./scripts/smoke-wsl.sh
```

### 3. Interpret results

The smoke test uses `set -euo pipefail` — any failure exits immediately.

**On success**: All assertions pass, test isolates to a temp KCTL_ENV_ROOT and cleans up.

**On failure**: 
- Read the last error line carefully
- Check whether it was a network issue (`curl` timeout) or a logic failure
- Network failures: re-run with `SKIP_KUBECTL_INSTALL=1` to isolate
- Logic failures: read the failing assertion in `scripts/smoke-wsl.sh` and investigate

### 4. Report

Summarise:
- Pass / Fail
- Any failures with file:line reference
- Whether failure is network-related or logic-related
- Suggested fix if obvious

## Coverage the smoke test checks

1. CLI wiring (`kctl-env help`)
2. Shim on PATH (`command -v kubectl`)
3. Install stable version
4. Global version pin (`kctl-env use`)
5. Shim resolution with `kubectl version --client`
6. `.kubectl-version` file overrides global pin
7. PATH auto-config idempotency (marker block not duplicated)
