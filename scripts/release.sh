#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/release.sh <new-version>
# Updates VERSION, Debian changelog, RPM spec, commits changes on current branch.

new_version="${1:-}"
if [[ -z "$new_version" ]]; then
  echo "Usage: scripts/release.sh <new-version>" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

# Ensure working tree clean
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree not clean. Commit or stash changes before releasing." >&2
  exit 1
fi

# Write VERSION
printf "%s" "$new_version" > VERSION

# Update Debian changelog (prepend entry)
change_date="$(date -Ru | sed 's/UTC/+0000/')"
changelog_file="packaging/debian/changelog"
if [[ -f "$changelog_file" ]]; then
  tmp="$(mktemp)"
  {
    echo "kctl-env ($new_version) unstable; urgency=medium"
    echo
    echo "  * Release $new_version"
    echo
    echo " -- kctl-env Maintainers <kctl-env@example.com>  $change_date"
    echo
    cat "$changelog_file"
  } > "$tmp"
  mv "$tmp" "$changelog_file"
fi

# Update RPM spec Version field
spec_file="packaging/rpm/kctl-env.spec"
if [[ -f "$spec_file" ]]; then
  sed -i "s/^Version:\s*.*/Version:        $new_version/" "$spec_file"
  # Update changelog
  sed -i "1 a\\* $(date +"%a %b %d %Y") kctl-env Maintainers <kctl-env@example.com> - $new_version-1\\n- Release $new_version" "$spec_file"
fi

# Commit changes
git add VERSION "$changelog_file" "$spec_file"
git commit -m "release: bump to v$new_version"

echo "Release files updated and committed. Open a PR if on a release branch."
echo
echo "After merging and creating the tag, remember to:"
echo "  1. Create a GitHub release for v$new_version"
echo "  2. Generate and attach checksum for the source tarball:"
echo "     curl -fsSL https://github.com/senet/kctl-env/archive/refs/tags/v$new_version.tar.gz | sha256sum > v$new_version.tar.gz.sha256"
echo "  3. Upload the checksum file as a release asset"
echo "     This enables secure installation with: curl -fsSL https://raw.githubusercontent.com/senet/kctl-env/main/install.sh | bash -s -- v$new_version"

