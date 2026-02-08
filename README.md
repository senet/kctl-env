# kctl-env: Kubectl Version Manager

Pure Bash, zero-deps kubectl version manager with fast shims and tfenv-style UX.

## Directory Structure

- `bin/kctl-env`         — Main CLI entry point (dispatcher)
- `bin/kubectl`          — Shim executable (fast version resolver)
- `libexec/`             — Internal logic (install, list, use, etc.)
- `versions/`            — Downloaded kubectl binaries (by version)
- `cache/`               — Version lists, cluster map, remote metadata

## Installation

### Quick install (recommended)

Pin a specific version (recommended for reproducibility and supply-chain security):

```sh
curl -fsSL https://raw.githubusercontent.com/senet/kctl-env/v0.1.0/install.sh | bash -s -- v0.1.0
```

Install from the main branch (for development/testing):

```sh
curl -fsSL https://raw.githubusercontent.com/senet/kctl-env/main/install.sh | bash -s -- main
```

If you're testing from a feature branch, replace `main` in the URL (URL-encoding the branch name if it contains `/`) and pass the branch name as the ref:

```sh
curl -fsSL https://raw.githubusercontent.com/senet/kctl-env/feat%2Feasy-install/install.sh | bash -s -- feat/easy-install
```


**Security note**: Tagged releases (v*) require SHA256 checksum verification by default and will fail if the checksum asset is missing, unless you explicitly set `KCTL_ENV_SKIP_VERIFY=1` to skip verification. Branch installations skip verification as GitHub does not provide checksums for auto-generated archives.

1. Clone or extract kctl-env to a directory (e.g., `~/.kctl-env`).
2. Add the `bin/` directory to your `PATH`:

   ```sh
   export PATH="$HOME/.kctl-env/bin:$PATH"
   # Or, if using a custom root:
   export KCTL_ENV_ROOT=/your/path/to/kctl-env
   export PATH="$KCTL_ENV_ROOT/bin:$PATH"
   ```

3. Install a kubectl version:

   ```sh
   kctl-env install latest
   kctl-env use latest
   ```

4. Use kubectl as normal:

   ```sh
   kubectl version --client
   ```

## How It Works

- The `kubectl` shim resolves the correct version using:
  1. `$KCTL_VERSION` environment variable
  2. `.kubectl-version` file (traverses up directories)
  3. Context-aware auto mode (if enabled)
  4. Global default (`~/.kctl-env/version`)
- The resolved binary is executed directly for zero overhead.

## Usage

- Install latest kubectl and set as default:

   ```sh
   kctl-env install latest
   kctl-env use latest
   ```

- Pin a specific version globally:

   ```sh
   kctl-env install v1.27.0
   kctl-env use v1.27.0
   ```

- Per-project version via `.kubectl-version`:

   ```sh
   echo v1.27.0 > .kubectl-version
   kubectl version --client
   ```

- Auto mode (context-aware):

   ```sh
   kctl-env use auto
   # First run against a context queries the server and caches the version
   kubectl version --client
   ```

- List available remote versions:

   ```sh
   kctl-env list-remote | head
   ```

## Implementation Notes

- Pure Bash, zero dependencies beyond standard POSIX tools: curl, grep, sed, awk, sha256sum.
- Apple Silicon: set `KCTL_ARCH=amd64` when installing older versions lacking arm64 builds to use Rosetta emulation.
- Auto mode cache TTL can be tuned with `KCTL_CLUSTER_TTL` (default: 300 seconds).

## Roadmap & TODO

Next 6 months: Month 1—CI across Ubuntu/macOS/WSL, release automation, and security hardening.
Months 2–3—shell completions, offline/mirror mode, and post-switch hooks.
Months 4–6—distribution (Homebrew, Debian/RPM), performance profiling (<10ms shim), optional plugin system.
Progress tracked via GitHub Issues/Projects.

## Changelog

All notable changes are recorded in `CHANGELOG.md`. For any PR that changes behavior or introduces features, please update `CHANGELOG.md` accordingly.

## Roadmap

- Improve remote version discovery and filtering for pre-releases.
- Add uninstall and prune commands.
