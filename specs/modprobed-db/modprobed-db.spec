Name:           modprobed-db
Version:        2.48
Release:        %autorelease
Summary:        Keeps track of EVERY kernel module ever used - useful for make localmodconfig
BuildArch:      noarch

License:        MIT
URL:            https://wiki.archlinux.org/index.php/Modprobed-db
Source:         https://github.com/graysky2/%{name}/archive/v%{version}.tar.gz

BuildRequires:  make
BuildRequires:  systemd-rpm-macros

Requires:       coreutils
Requires:       gawk
Requires:       grep
Requires:       kmod
Requires:       sed

%description
modprobed-db is a utility that populates a list of all the kernel modules that
have been loaded on a system while running. This list can then be used to
disable all the unused modules when building your own kernel and significantly
reduce the compilation time.

%prep
%autosetup

%build
%make_build

%install
%make_install

%files
%{bash_completions_dir}/modprobed-db
%{_bindir}/modprobed-db
%{_datadir}/modprobed-db/modprobed-db.skel
%{_mandir}/man8/modprobed-db.8.*
%{_userunitdir}/modprobed-db.service
%{_userunitdir}/modprobed-db.timer
%{zsh_completions_dir}/_modprobed-db
%license MIT

%changelog
%autochangelog
