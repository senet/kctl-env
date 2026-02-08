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
KCTL_ENV_SKIP_VERIFY="${KCTL_ENV_SKIP_VERIFY:-}"

usage() {
  cat <<EOF
kctl-env installer

Usage:
  ./install.sh [ref]

Arguments:
  ref            Git ref to install (tag like v0.1.1, or branch like main)

Environment:
  KCTL_ENV_ROOT         Install root (default: ~/.kctl-env)
  KCTL_ENV_REF          Same as [ref]
  KCTL_ENV_SKIP_VERIFY  Skip checksum verification (use with caution)

Examples:
  ./install.sh v0.1.1
  KCTL_ENV_ROOT="$HOME/.kctl-env" ./install.sh main
  KCTL_ENV_SKIP_VERIFY=1 ./install.sh v0.1.0  # For releases without checksums
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
require_cmd sha256sum

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

archive="$tmpdir/src.tar.gz"

echo "Downloading $archive_url"
curl -fsSL "$archive_url" -o "$archive"

# Verify integrity for tagged releases
# For tags (v*), try to fetch and verify SHA256 checksum from GitHub releases
# For branches, skip checksum (GitHub doesn't provide checksums for auto-generated tarballs)
if [[ "$ref" == v* ]]; then
  if [[ -n "${KCTL_ENV_SKIP_VERIFY:-}" ]]; then
    echo "Warning: Checksum verification explicitly skipped via KCTL_ENV_SKIP_VERIFY" >&2
  else
    checksum_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${ref}/${ref}.tar.gz.sha256"
    echo "Verifying checksum..."
    if curl -fsSL "$checksum_url" -o "$tmpdir/checksum.sha256" 2>/dev/null; then
      # Extract just the hash (first field) and verify manually
      expected_hash="$(awk '{print $1}' "$tmpdir/checksum.sha256")"
      actual_hash="$(sha256sum "$archive" | awk '{print $1}')"
      if [[ "$expected_hash" != "$actual_hash" ]]; then
        echo "Checksum verification failed for $ref" >&2
        echo "Expected: $expected_hash" >&2
        echo "Actual:   $actual_hash" >&2
        echo "This may indicate a compromised download or release." >&2
        exit 1
      fi
      echo "Checksum verified successfully"
    else
      echo "Error: No checksum found for $ref at $checksum_url" >&2
      echo "For security, this installer requires SHA256 verification for tagged releases." >&2
      echo "To install an older release without checksums, use: KCTL_ENV_SKIP_VERIFY=1 $0 $ref" >&2
      exit 1
    fi
  fi
else
  echo "Note: Checksum verification skipped for branch '$ref' (not available for auto-generated archives)"
fi

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
