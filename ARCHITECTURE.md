# Architecture

> For installation and usage, see [README.md](README.md).

This document describes the internal design of kctl-env for contributors and anyone interested in how the tool works under the hood.

## System Diagram

![kctl-env system architecture](kctl_env_architecture.svg)

## Components

### Entry Points

kctl-env exposes two binaries in `bin/` that sit on the user's `PATH`:

| Binary | Role | Invoked by |
|--------|------|------------|
| `bin/kctl-env` | CLI dispatcher — routes subcommands to `libexec/` modules | User running `kctl-env install`, `kctl-env use`, etc. |
| `bin/kubectl` | Shim — resolves the correct kubectl version and `exec`s it | User running any `kubectl` command |

### Shared Library

`libexec/kctl-env-common` is sourced (not executed) by every other script. It provides:

- **Environment setup** — `KCTL_ENV_ROOT`, `KCTL_VERSIONS`, `KCTL_CACHE`, etc.
- **Logging** — `kctl_info()`, `kctl_warn()`, `kctl_error()`, `kctl_debug()` (debug gated by `KCTL_ENV_DEBUG=1`)
- **Validation** — `is_valid_version()` rejects path traversal and malformed inputs
- **Version resolution helpers** — `find_kubectl_version_file()`, `get_current_context()`, `get_cached_version_for_context()`, `update_cluster_map_cache()`
- **Server queries** — `find_resolver_kubectl()`, `query_server_version()`
- **Portable sorting** — `sort_versions_desc()` (GNU `sort -V` with awk-based POSIX fallback)

### libexec/ Modules

Each module is a standalone script sourcing `kctl-env-common`:

| Module | Command | Purpose |
|--------|---------|---------|
| `kctl-env-install` | `kctl-env install <version>` | Downloads kubectl from dl.k8s.io, verifies SHA256, installs to `versions/` |
| `kctl-env-use` | `kctl-env use <version>` | Writes the global version pin to `$KCTL_ENV_ROOT/version` |
| `kctl-env-list` | `kctl-env list` | Lists locally installed versions, marks active with `*` |
| `kctl-env-list-remote` | `kctl-env list-remote` | Queries GitHub tags API for available kubectl releases |

### Shell Completions

Located in `etc/` (not `libexec/`):

- `etc/kctl-env-completion.bash` — Bash tab completion
- `etc/kctl-env-completion.zsh` — Zsh tab completion

## Version Resolution (Shim)

When the user runs `kubectl <anything>`, the shim resolves which kubectl binary to execute using a 4-tier priority chain:

```
Priority 1: $KCTL_VERSION environment variable     (process scope)
     │ not set
     ▼
Priority 2: .kubectl-version file                   (project scope)
     │  walks from $PWD up to /
     │ not found
     ▼
Priority 3: Global version file                     (machine scope)
     │  reads $KCTL_ENV_ROOT/version
     │  if "auto" → query cluster via cache
     │ not found
     ▼
Priority 4: Fallback to "latest"
```

### Auto Mode Detail

When the global version is set to `auto`:

1. Read current kube context from `~/.kube/config`
2. Check `cache/cluster-map` for a cached version (if within TTL)
3. If cache miss: use an installed kubectl to query the cluster's server version
4. Cache the result with a timestamp
5. Return the matched version

The cache file (`cache/cluster-map`) stores one line per context:

```
<context-name> <version> <unix-timestamp>
```

Entries older than `KCTL_CLUSTER_TTL` (default: 300s) are ignored on read and pruned (entries older than 10x TTL) on write.

## Data Flow

### Install Flow

```
kctl-env install v1.33.0
  │
  ├─ Already installed? → exit early with message
  │
  ├─ Resolve version (latest/stable → curl dl.k8s.io/release/stable.txt)
  ├─ Detect OS (Linux/Darwin) and ARCH (amd64/arm64)
  ├─ Download kubectl.sha256 from dl.k8s.io
  ├─ Download kubectl binary
  ├─ Verify SHA256 checksum
  ├─ Install to versions/<version>/kubectl
  └─ If latest/stable: create versions/latest symlink
```

### kubectl Invocation Flow

```
kubectl get pods
  │
  ├─ bin/kubectl shim intercepts
  ├─ source libexec/kctl-env-common
  ├─ resolve_version() → 4-tier chain
  ├─ Validate resolved version string
  ├─ exec versions/<version>/kubectl get pods
  └─ (shim process is replaced by real kubectl)
```

## Directory Layout

```
~/.kctl-env/                    # KCTL_ENV_ROOT
├── bin/
│   ├── kctl-env                # CLI dispatcher
│   └── kubectl                 # Shim (on PATH)
├── libexec/
│   ├── kctl-env-common         # Shared library (sourced)
│   ├── kctl-env-install        # Install module
│   ├── kctl-env-use            # Use module
│   ├── kctl-env-list           # List module
│   └── kctl-env-list-remote    # List-remote module
├── etc/
│   ├── kctl-env-completion.bash
│   └── kctl-env-completion.zsh
├── versions/
│   ├── v1.33.0/kubectl         # Installed binary
│   ├── v1.32.0/kubectl
│   └── latest -> v1.33.0/     # Symlink
├── cache/
│   └── cluster-map             # Context → version cache
└── version                     # Global version pin (auto/latest/vX.Y.Z)
```

## Security Model

| Concern | Mitigation |
|---------|-----------|
| Supply chain (compromised binary) | SHA256 checksum verification on every install |
| Path traversal via `.kubectl-version` | `is_valid_version()` rejects non-semver strings |
| Path traversal via `kctl-env use` | Input validation before writing version file |
| Cache injection (regex metacharacters in context name) | `awk` string comparison instead of `grep -E` |
| Stale cache growth | Automatic pruning of entries older than 10x TTL |
| Curl-pipe install | Tagged releases require checksum; `KCTL_ENV_SKIP_VERIFY=1` to opt out |

## Design Principles

- **Pure Bash, zero external runtime dependencies** — only standard POSIX tools (curl, grep, sed, awk, sha256sum)
- **Fast shim** — minimize subshells in the hot path; `exec` replaces the shim process
- **DRY** — shared functions in `kctl-env-common`, sourced by all scripts
- **Portable** — GNU `sort -V` preferred, with awk-based POSIX fallback for macOS/BSD
- **Relocatable** — `KCTL_ENV_ROOT` makes the entire install movable
- **tfenv/rbenv conventions** — familiar UX for developers using similar version managers
