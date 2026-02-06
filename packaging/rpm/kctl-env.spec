Name:           kctl-env
* Sat Feb 07 2026 kctl-env Maintainers <kctl-env@example.com> - 0.1.1-1
- Release 0.1.1
Version:        0.1.1
Release:        1%{?dist}
Summary:        Pure Bash kubectl version manager with fast shims and tfenv-style UX
License:        MIT
URL:            https://github.com/senet/kctl-env
Source0:        kctl-env-%{version}.tar.gz
BuildArch:      noarch
Requires:       bash, curl, grep, sed, gawk, coreutils

%description
kctl-env manages kubectl versions per-project or globally, with context-aware
auto-switching and strict SHA256 verification of downloaded binaries.

%prep
%setup -q

%build
# nothing to build

%install
mkdir -p %{buildroot}/usr/lib/kctl-env/bin
mkdir -p %{buildroot}/usr/lib/kctl-env/libexec
install -m 0755 bin/kctl-env %{buildroot}/usr/lib/kctl-env/bin/kctl-env
install -m 0755 bin/kubectl %{buildroot}/usr/lib/kctl-env/bin/kubectl
install -m 0755 libexec/* %{buildroot}/usr/lib/kctl-env/libexec/
mkdir -p %{buildroot}/usr/bin
ln -sf /usr/lib/kctl-env/bin/kctl-env %{buildroot}/usr/bin/kctl-env
ln -sf /usr/lib/kctl-env/bin/kubectl %{buildroot}/usr/bin/kubectl

%files
/usr/lib/kctl-env/bin/kctl-env
/usr/lib/kctl-env/bin/kubectl
/usr/lib/kctl-env/libexec/*
/usr/bin/kctl-env
/usr/bin/kubectl

%changelog
* Wed Jan 07 2026 kctl-env Maintainers <kctl-env@example.com> - 0.1.0-1
- Initial release
