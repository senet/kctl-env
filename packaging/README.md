# Packaging kctl-env

This project is pure Bash and ships as scripts. You can distribute it as:

- A tarball and Makefile for `make install`
- A Debian package (.deb) with an apt repository
- An RPM package (.rpm) with a yum/dnf repository
- Homebrew (macOS), AUR (Arch), Snap, Nix, etc.

## Quick install (tarball)

Build a tarball and install:

```sh
make dist
sudo make install PREFIX=/usr/local
```

This installs the scripts to `/usr/local/lib/kctl-env` and symlinks `/usr/local/bin/{kctl-env,kubectl}`.

## Debian (.deb) and apt repo

Options:
- Use Launchpad PPA or Open Build Service (OBS) to build and host
- Self-host apt with `reprepro` + GPG
- Use a hosted service like Cloudsmith/Packagecloud

Skeleton files (see `packaging/debian/`):
- `control` — package metadata
- `rules` — debhelper build rules (dh)
- `changelog` — version history

Build locally (if you move `packaging/debian` to `debian/`):

```sh
sudo apt-get install debhelper devscripts
# Ensure debian/ is at repo root
debuild -us -uc
# Produce ../kctl-env_<version>_all.deb
```

Publish apt repo (self-hosted, brief):
- Create a GPG key and sign the Release file
- Use `reprepro` to add packages for distributions (e.g., focal, jammy)
- Host via static site (S3/GitHub Pages)
- Add apt source line in users' `/etc/apt/sources.list.d/kctl-env.list`

## RPM (.rpm) and yum/dnf repo

Options:
- Use Fedora COPR or OBS to build and host
- Self-host via `createrepo` with signed metadata
- Hosted services (Cloudsmith/Packagecloud) also support RPM

Spec file skeleton in `packaging/rpm/kctl-env.spec`.
Build locally:

```sh
sudo dnf install rpm-build
rpmbuild -ba packaging/rpm/kctl-env.spec
# Artifacts under ~/rpmbuild/RPMS/noarch/
```

Publish YUM/DNF repo (brief):
- `createrepo` on a directory of RPMs
- Sign the repo metadata (optional)
- Host over HTTPS
- Provide `/etc/yum.repos.d/kctl-env.repo` with baseurl

## Other ecosystems

- Homebrew: create a tap repo with a Formula that pulls the tarball and installs to `libexec`, symlink `bin`.
- Arch AUR: PKGBUILD that installs the scripts to `/usr/share/kctl-env` and symlinks.
- Snap/Nix: wrap scripts; keep confinement and PATH behavior in mind.

## Notes

- Runtime data lives under `~/.kctl-env` (per-user). Packaging installs only the program scripts.
- SHA256 verification is done during `kctl-env install` and not at package time.
- Apple Silicon fallback for older versions: users set `KCTL_ARCH=amd64` when installing.
