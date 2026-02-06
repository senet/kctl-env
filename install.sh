#!/usr/bin/env bash
# kctl-env bootstrap installer
# - Zero deps beyond: bash, curl, tar, coreutils
# - Installs into $KCTL_ENV_ROOT (default: ~/.kctl-env)
# - Preserves existing runtime dirs (versions/, cache/)

set -euo pipefail

REPO_OWNER="senet"
REPO_NAME="kctl-env"

KCTL_ENV_ROOT="${KCTL_ENV_ROOT:-$HOME/.kctl-env}"
KCTL_ENV_REF="${KCTL_ENV_REF:-}"

usage() {
  cat <<EOF
kctl-env installer

Usage:
  ./install.sh [ref]

Arguments:
  ref            Git ref to install (tag like v0.1.1, or branch like main)

Environment:
  KCTL_ENV_ROOT  Install root (default: ~/.kctl-env)
  KCTL_ENV_REF   Same as [ref]

Examples:
  ./install.sh v0.1.1
  KCTL_ENV_ROOT="$HOME/.kctl-env" ./install.sh main
EOF
}

ref_from_input="${1:-}"
if [[ "${ref_from_input:-}" == "-h" || "${ref_from_input:-}" == "--help" ]]; then
  usage
  exit 0
fi

ref="${ref_from_input:-$KCTL_ENV_REF}"
if [[ -z "$ref" ]]; then
  # Default to main for safety (predictable). Users can pin a tag.
  ref="main"
fi

archive_url=""
case "$ref" in
  v*) archive_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/tags/${ref}.tar.gz" ;;
  *)  archive_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${ref}.tar.gz" ;;
esac

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

require_cmd install
require_cmd mktemp
require_cmd curl
require_cmd find
require_cmd head
require_cmd tar

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

archive="$tmpdir/src.tar.gz"

echo "Downloading $archive_url"
curl -fsSL "$archive_url" -o "$archive"

# Extract
mkdir -p "$tmpdir/src"
tar -xzf "$archive" -C "$tmpdir/src"

# Determine extracted directory
src_root="$(find "$tmpdir/src" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "${src_root:-}" || ! -d "$src_root" ]]; then
  echo "Failed to locate extracted source directory" >&2
  exit 1
fi

# Create target directories (preserve versions/cache if already exist)
mkdir -p "$KCTL_ENV_ROOT" \
  "$KCTL_ENV_ROOT/bin" \
  "$KCTL_ENV_ROOT/libexec" \
  "$KCTL_ENV_ROOT/etc" \
  "$KCTL_ENV_ROOT/packaging" \
  "$KCTL_ENV_ROOT/scripts" \
  "$KCTL_ENV_ROOT/versions" \
  "$KCTL_ENV_ROOT/cache"

# Install core scripts
install -m 0755 "$src_root/bin/kctl-env" "$KCTL_ENV_ROOT/bin/kctl-env"
install -m 0755 "$src_root/bin/kubectl" "$KCTL_ENV_ROOT/bin/kubectl"

# libexec scripts
for f in "$src_root"/libexec/*; do
  [[ -f "$f" ]] || continue
  install -m 0755 "$f" "$KCTL_ENV_ROOT/libexec/$(basename "$f")"
done

# Completion scripts (optional)
if [[ -f "$src_root/etc/kctl-env-completion.bash" ]]; then
  install -m 0644 "$src_root/etc/kctl-env-completion.bash" "$KCTL_ENV_ROOT/etc/kctl-env-completion.bash"
fi
if [[ -f "$src_root/etc/kctl-env-completion.zsh" ]]; then
  install -m 0644 "$src_root/etc/kctl-env-completion.zsh" "$KCTL_ENV_ROOT/etc/kctl-env-completion.zsh"
fi

# Scripts (optional)
if [[ -f "$src_root/scripts/release.sh" ]]; then
  install -m 0755 "$src_root/scripts/release.sh" "$KCTL_ENV_ROOT/scripts/release.sh"
fi

# Docs + metadata (best-effort)
for f in README.md CHANGELOG.md VERSION; do
  if [[ -f "$src_root/$f" ]]; then
    install -m 0644 "$src_root/$f" "$KCTL_ENV_ROOT/$f"
  fi
done

echo
echo "Installed kctl-env into: $KCTL_ENV_ROOT"
echo
echo "Next steps:"
echo "  1) Add to PATH:"
echo "     export PATH=\"$KCTL_ENV_ROOT/bin:\$PATH\""
echo "  2) Install kubectl:"
echo "     kctl-env install latest"
echo "  3) Select version:"
echo "     kctl-env use latest"
echo
