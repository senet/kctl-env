#!/usr/bin/env bash
set -euo pipefail

# WSL-focused smoke test for kctl-env.
# - Does NOT edit your shell rc files.
# - Uses a temporary KCTL_ENV_ROOT.
# - Requires network access unless SKIP_KUBECTL_INSTALL=1.

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

SMOKE_REF="${SMOKE_REF:-main}"
SKIP_KUBECTL_INSTALL="${SKIP_KUBECTL_INSTALL:-}"

workdir="$(mktemp -d "${TMPDIR:-/tmp}/kctl-env-smoke.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

export KCTL_ENV_ROOT="$workdir/root"
export KCTL_ENV_AUTO_PATH=0

printf "==> Using KCTL_ENV_ROOT=%s\n" "$KCTL_ENV_ROOT"

printf "==> Running installer (ref=%s)\n" "$SMOKE_REF"
# Use the repo's installer, but install the specified ref from GitHub.
"$repo_root/install.sh" "$SMOKE_REF"

export PATH="$KCTL_ENV_ROOT/bin:$PATH"

printf "==> Validate CLI wiring\n"
kctl-env help >/dev/null

printf "==> Validate shim present\n"
command -v kubectl >/dev/null

if [[ -z "$SKIP_KUBECTL_INSTALL" ]]; then
  printf "==> Install kubectl (stable)\n"
  kctl-env install stable

  printf "==> Set global default and run kubectl client version\n"
  kctl-env use stable
  kubectl version --client >/dev/null

  printf "==> Validate .kubectl-version precedence\n"
  proj="$workdir/project"
  mkdir -p "$proj/subdir"
  # Use the actual installed version directory under versions/ (exclude latest symlink)
  installed_ver="$(ls -1 "$KCTL_ENV_ROOT/versions" | grep -E '^v' | head -n 1 || true)"
  if [[ -z "$installed_ver" ]]; then
    echo "No installed v* versions found under $KCTL_ENV_ROOT/versions" >&2
    exit 1
  fi
  echo "$installed_ver" > "$proj/.kubectl-version"
  version_output="$(cd "$proj/subdir" && kubectl version --client 2>/dev/null)"
  if ! grep -q "$installed_ver" <<<"$version_output"; then
    echo "kubectl version output did not contain expected version: $installed_ver" >&2
    echo "kubectl version --client output was:" >&2
    echo "$version_output" >&2
    exit 1
  fi
else
  printf "==> SKIP_KUBECTL_INSTALL=1 set; skipping download-based tests\n"
fi

# ── PATH auto-config (rc file modification) ──────────────────────────────
printf "==> Validate PATH auto-config writes rc file\n"
test_rc="$workdir/test_bashrc"
touch "$test_rc"

KCTL_ENV_AUTO_PATH=1 KCTL_ENV_RC_FILE="$test_rc" "$repo_root/install.sh" "$SMOKE_REF"

if ! grep -Fq '# >>> kctl-env >>>' "$test_rc"; then
  echo "FAIL: marker block not found in $test_rc after KCTL_ENV_AUTO_PATH=1" >&2
  exit 1
fi
if ! grep -Fq "$KCTL_ENV_ROOT/bin" "$test_rc"; then
  echo "FAIL: bin path not found in $test_rc" >&2
  exit 1
fi

# Idempotency: run again and verify no duplicate blocks
KCTL_ENV_AUTO_PATH=1 KCTL_ENV_RC_FILE="$test_rc" "$repo_root/install.sh" "$SMOKE_REF"
marker_count="$(grep -c '# >>> kctl-env >>>' "$test_rc")"
if [[ "$marker_count" -ne 1 ]]; then
  echo "FAIL: expected 1 marker block, found $marker_count (idempotency broken)" >&2
  exit 1
fi
printf "==> PATH auto-config OK\n"

printf "==> OK\n"
