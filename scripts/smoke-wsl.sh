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
  (cd "$proj/subdir" && kubectl version --client >/dev/null)
else
  printf "==> SKIP_KUBECTL_INSTALL=1 set; skipping download-based tests\n"
fi

printf "==> OK\n"
