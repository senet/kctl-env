# Contributing to kctl-env

## Branching strategy

- `main` is protected and only updated via Pull Requests.
- Use short-lived topic branches:
  - `feat/<brief-name>` for features
  - `fix/<brief-name>` for bug fixes
  - `chore/<brief-name>` for maintenance
  - `release/vX.Y.Z` for release preparation
- Open PRs from your branch into `main`. Squash merge or rebase merge preferred.

## Versioning

- Semantic Versioning: `MAJOR.MINOR.PATCH` (e.g., `v0.1.0`).
- The canonical version lives in `VERSION` at the repo root.
- Packaging files derive their version from `VERSION` during release.
- Tags: annotated git tags named `vX.Y.Z`.

## Release workflow

1. Create a release branch:
   ```sh
   git checkout -b release/v0.1.1
   ```
2. Bump version and update packaging metadata:
   ```sh
   make release V=0.1.1
   ```
   This updates:
   - `VERSION`
   - `packaging/debian/changelog` (prepends an entry)
   - `packaging/rpm/kctl-env.spec` (Version field)
   Commits to the release branch.
3. Open a PR to `main` and get approvals.
4. After merge, create and push the tag:
   ```sh
   git tag -a v0.1.1 -m "v0.1.1 release"
   git push origin v0.1.1
   ```
5. Create a GitHub release for the tag and attach checksums:
   ```sh
   # Generate SHA256 checksum for the source tarball
   curl -fsSL https://github.com/senet/kctl-env/archive/refs/tags/v0.1.1.tar.gz | sha256sum > v0.1.1.tar.gz.sha256
   
   # Upload as a release asset via GitHub UI or CLI
   gh release create v0.1.1 --title "v0.1.1" --notes "Release v0.1.1" v0.1.1.tar.gz.sha256
   ```
   This enables secure installation with SHA256 verification.

## Branch protections (recommended)

- Require PR reviews for `main`.
- Disallow direct pushes.
- Require status checks (CI) if/when added.

## Coding guidelines

- Pure Bash scripts; zero dependencies beyond POSIX tools.
- Keep shims fast; avoid subshell-heavy patterns.
- Validate downloads with SHA256.
