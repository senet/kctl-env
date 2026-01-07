# Changelog

All notable changes to this project will be documented in this file. This project adheres to Semantic Versioning.

## [v0.1.0] - 2026-01-07
### Added
- Initial scaffold: bin/kubectl shim with env/.kubectl-version/global/auto resolution and TTL cache
- Dispatcher: bin/kctl-env with install/use/list-remote commands
- Installer: OS/arch detection, SHA256 verification, Apple Silicon amd64 fallback via KCTL_ARCH
- Packaging scaffolds: Debian, RPM, Makefile install/uninstall/dist
- README with setup, usage, auto mode notes
- CONTRIBUTING, release script, PR template

### Changed
- Git repository initialized, branch protections configured (squash/rebase, linear history, delete branch on merge)

[v0.1.0]: https://github.com/senet/kctl-env/releases/tag/v0.1.0
