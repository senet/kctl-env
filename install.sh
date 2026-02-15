#!/usr/bin/env bash
# kctl-env bootstrap installer
# - Requires standard Unix tools: bash, curl, tar, coreutils (incl. install, mktemp, head, basename), find, awk
# - SHA256 verification uses sha256sum (Linux), shasum (macOS), or openssl (fallback)
# - Installs into $KCTL_ENV_ROOT (default: ~/.kctl-env)
# - Preserves existing runtime dirs (versions/, cache/)

set -euo pipefail

REPO_OWNER="senet"
REPO_NAME="kctl-env"

KCTL_ENV_ROOT="${KCTL_ENV_ROOT:-$HOME/.kctl-env}"
KCTL_ENV_REF="${KCTL_ENV_REF:-}"
KCTL_ENV_SKIP_VERIFY="${KCTL_ENV_SKIP_VERIFY:-}"
KCTL_ENV_AUTO_PATH="${KCTL_ENV_AUTO_PATH:-}"
KCTL_ENV_RC_FILE="${KCTL_ENV_RC_FILE:-}"

usage() {
  cat <<EOF
kctl-env installer

Usage:
  ./install.sh <ref>

Arguments:
  ref            Git ref to install (required; tag like v0.1.1, or branch like main)

Environment:
  KCTL_ENV_ROOT  Install root (default: ~/.kctl-env)
  KCTL_ENV_REF   Alternative to passing ref as argument (required if ref not provided)
  KCTL_ENV_AUTO_PATH
                Auto-configure PATH in your shell rc.
                - unset: prompt on WSL (if /dev/tty is available), otherwise disabled
                - 1:     yes (non-interactive)
                - 0:     no
  KCTL_ENV_RC_FILE
                Shell rc file to edit when KCTL_ENV_AUTO_PATH enables it.
                Default: ~/.bashrc (or ~/.zshrc if SHELL ends with zsh)

Examples:
  ./install.sh v0.1.1
  KCTL_ENV_ROOT="$HOME/.kctl-env" ./install.sh main
  KCTL_ENV_REF=v0.1.1 ./install.sh
EOF
}

ref_from_input="${1:-}"
if [[ "${ref_from_input:-}" == "-h" || "${ref_from_input:-}" == "--help" ]]; then
  usage
  exit 0
fi

ref="${ref_from_input:-$KCTL_ENV_REF}"
if [[ -z "$ref" ]]; then
  echo "Error: No ref specified. For supply-chain security, you must explicitly specify a version tag or branch." >&2
  echo "Usage: $0 <ref>  (e.g., v0.1.1 or main)" >&2
  echo "See: curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/install.sh | bash -s -- <ref>" >&2
  exit 1
fi

archive_url=""
case "$ref" in
  v*) archive_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/tags/${ref}.tar.gz" ;;
  *)  archive_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${ref}.tar.gz" ;;
esac

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

# Compute SHA256 hash using available tools
# Returns hash on stdout, exits non-zero on error
compute_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $NF}'
  else
    echo "Error: No SHA256 tool found (tried: sha256sum, shasum, openssl)" >&2
    exit 1
  fi
}

require_cmd install
require_cmd mktemp
require_cmd curl
require_cmd find
require_cmd head
require_cmd tar
require_cmd awk
require_cmd basename
require_cmd tr

is_wsl() {
  # WSL detection: environment variables are the most reliable; /proc/version is a fallback.
  [[ -n "${WSL_INTEROP:-}" || -n "${WSL_DISTRO_NAME:-}" ]] && return 0
  [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version && return 0
  return 1
}

default_rc_file() {
  if [[ -n "${KCTL_ENV_RC_FILE:-}" ]]; then
    echo "$KCTL_ENV_RC_FILE"
    return 0
  fi

  case "${SHELL:-}" in
    */zsh) echo "$HOME/.zshrc" ;;
    *)     echo "$HOME/.bashrc" ;;
  esac
}

prompt_yes_no_tty() {
  # Usage: prompt_yes_no_tty "Question" "default"  (default: y|n)
  # Reads from /dev/tty to work even when installer is piped via curl.
  local question="$1"
  local def="${2:-y}"
  local prompt ans

  if [[ ! -r /dev/tty ]]; then
    return 1
  fi

  if [[ "$def" == "y" ]]; then
    prompt="[Y/n]"
  else
    prompt="[y/N]"
  fi

  printf "%s %s " "$question" "$prompt" > /dev/tty
  IFS= read -r ans < /dev/tty || true
  ans="${ans:-}"
  if [[ -z "$ans" ]]; then
    [[ "$def" == "y" ]]
    return
  fi
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_path_in_rc() {
  local rc_file="$1"
  local bin_path="$2"
  local marker_begin="# >>> kctl-env >>>"
  local marker_end="# <<< kctl-env <<<"
  local stamp
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"

  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"

  # Idempotency and path updates:
  # - If our marker block exists and already uses this bin_path, do nothing.
  # - If our marker block exists but points to a different bin_path, update it in-place.
  # - If no marker block exists but the exact bin_path is already referenced, do nothing.
  cp "$rc_file" "$rc_file.bak.$(date +%s)" 2>/dev/null || true

  if grep -Fq "$marker_begin" "$rc_file" 2>/dev/null; then
    # Marker block exists: ensure PATH line inside the block uses the current bin_path.
    tmp_rc="${rc_file}.kctl-env-tmp.$$"
    awk -v mb="$marker_begin" -v me="$marker_end" -v bp="$bin_path" '
      BEGIN { inblock = 0 }
      {
        if ($0 == mb) {
          inblock = 1
          print
          next
        }
        if ($0 == me) {
          inblock = 0
          print
          next
        }
        if (inblock && $0 ~ /^[[:space:]]*export[[:space:]]+PATH=/) {
          print "export PATH=\"" bp ":\$PATH\""
          next
        }
        print
      }
    ' "$rc_file" > "$tmp_rc" && mv "$tmp_rc" "$rc_file"
    return 0
  fi

  if grep -Fq "$bin_path" "$rc_file" 2>/dev/null; then
    return 0
  fi

  {
    echo
    echo "$marker_begin"
    echo "# Added by kctl-env installer${stamp:+ on $stamp}"
    echo "export PATH=\"$bin_path:\$PATH\""
    echo "$marker_end"
  } >> "$rc_file"
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/kctl-env.XXXXXX")"
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
      expected_hash="$(awk 'NR==1{print $1; exit}' "$tmpdir/checksum.sha256" | tr '[:upper:]' '[:lower:]')"
      actual_hash="$(compute_sha256 "$archive" | tr '[:upper:]' '[:lower:]')"
      
      # Validate that hashes were extracted successfully
      if [[ -z "$expected_hash" || -z "$actual_hash" ]]; then
        echo "Error: Failed to extract checksum values" >&2
        echo "The checksum file may be empty or malformed" >&2
        exit 1
      fi

      if [[ ! "$expected_hash" =~ ^[0-9a-f]{64}$ ]]; then
        echo "Error: Checksum file is malformed (expected SHA256 hex)." >&2
        echo "Got: $expected_hash" >&2
        exit 1
      fi
      
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
      echo "If you still want to install this older release without checksums, you can re-run with:" >&2
      echo "  Local file:  KCTL_ENV_SKIP_VERIFY=1 ./install.sh $ref" >&2
      echo "  Via curl:    KCTL_ENV_SKIP_VERIFY=1 bash -s -- $ref" >&2
      exit 1
    fi
  fi
else
  echo "Note: Checksum verification skipped for branch '$ref' (not available for auto-generated archives)"
fi

# Extract
mkdir -p "$tmpdir/src"
tar -xzf "$archive" -C "$tmpdir/src"

# Determine extracted directory (choose first top-level subdirectory deterministically)
src_root=""
for d in "$tmpdir/src"/*; do
  if [[ -d "$d" ]]; then
    src_root="$d"
    break
  fi
done
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

if [[ "$KCTL_ENV_ROOT" == /mnt/* ]]; then
  echo "Warning: You are installing under /mnt/... (Windows filesystem)." >&2
  echo "WSL may not preserve executable bits and symlinks there unless mounted with metadata." >&2
  echo "Consider using the default Linux home directory path instead (e.g., ~/.kctl-env)." >&2
  echo >&2
fi

# Optional PATH auto-config (WSL-friendly). Works even when piped via curl by reading from /dev/tty.
bin_path="$KCTL_ENV_ROOT/bin"
rc_file="$(default_rc_file)"

do_auto_path=""
case "${KCTL_ENV_AUTO_PATH:-}" in
  1|yes|YES|true|TRUE) do_auto_path=1 ;;
  0|no|NO|false|FALSE) do_auto_path=0 ;;
  *) do_auto_path="" ;;
esac

if [[ -z "$do_auto_path" ]]; then
  if is_wsl; then
    if prompt_yes_no_tty "Add kctl-env to PATH by updating $rc_file?" y; then
      do_auto_path=1
    else
      do_auto_path=0
    fi
  fi
fi

if [[ "${do_auto_path:-0}" -eq 1 ]]; then
  ensure_path_in_rc "$rc_file" "$bin_path"
  echo "Updated PATH in: $rc_file"
  echo "Open a new terminal, or run: export PATH=\"$bin_path:\$PATH\""
fi
