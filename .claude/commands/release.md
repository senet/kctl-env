# /release — kctl-env Release Workflow

Guide me through a complete, safe release of kctl-env.

## Before starting — confidence gate

Ask questions until you are >98% confident about:
- New version number (format: X.Y.Z — must be semver, greater than current `$(cat VERSION)`)
- Release type: patch / minor / major (affects CHANGELOG section heading)
- Whether there are unreleased changes in CHANGELOG.md that are ready to ship
- Whether the working tree is clean and main is up to date

Do not proceed until every ambiguity is resolved.

## Steps to execute (in order)

### 1. Pre-flight checks
- Confirm working tree is clean: `git status`
- Confirm we are on main (or a `release/vX.Y.Z` branch): `git branch --show-current`
- Show current version: `cat VERSION`
- Show unreleased CHANGELOG entries: read `CHANGELOG.md` and display the `## [Unreleased]` block

### 2. Create release branch
```bash
git checkout -b release/vX.Y.Z main
```

### 3. Bump version via Makefile
```bash
make release V=X.Y.Z
```
This updates `VERSION`, `packaging/debian/changelog`, and `packaging/rpm/kctl-env.spec`.

### 4. Update CHANGELOG.md
- Move everything under `## [Unreleased]` to a new section `## [X.Y.Z] — YYYY-MM-DD`
- Leave an empty `## [Unreleased]` section at the top for future work
- Show me a diff before writing

### 5. Update README.md
- Update the version badge (if present)
- Update the pinned version in the curl install one-liner to `vX.Y.Z`
- Show me a diff before writing

### 6. Commit
```bash
git add VERSION CHANGELOG.md README.md packaging/
git commit -m "release: vX.Y.Z"
```

### 7. Push and open PR
```bash
git push -u origin release/vX.Y.Z
gh pr create --title "release: vX.Y.Z" --body "..."
```
Include the CHANGELOG entries for this version in the PR body.

### 8. Post-merge — tag and publish (prompt me before executing)
After the PR merges to main:
```bash
git checkout main && git pull
git tag -a vX.Y.Z -m "release: vX.Y.Z"
git push origin vX.Y.Z
make dist
sha256sum dist/kctl-env-X.Y.Z.tar.gz > dist/kctl-env-X.Y.Z.tar.gz.sha256
gh release create vX.Y.Z \
  dist/kctl-env-X.Y.Z.tar.gz \
  dist/kctl-env-X.Y.Z.tar.gz.sha256 \
  --title "kctl-env vX.Y.Z" \
  --notes "..."
```

## Checklist (confirm all before declaring done)

- [ ] VERSION file updated
- [ ] CHANGELOG.md: Unreleased moved to versioned section
- [ ] README.md: badge and install URL updated
- [ ] packaging/debian/changelog updated
- [ ] packaging/rpm/kctl-env.spec updated
- [ ] Release branch PR opened
- [ ] Tag pushed after merge
- [ ] GitHub release created with tarball + sha256
