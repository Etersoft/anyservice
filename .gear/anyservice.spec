Name: anyservice
Version: 0.1
Release: alt2

Summary: Anyservice - scripts for making systemd like service from any programs

License: Mit
Group: System/Base
Url: http://wiki.etersoft.ru/Anyservice

Source: %name-%version.tar

Packager: Danil Mikhailov <danil@altlinux.org>

BuildArch: noarch
BuildPreReq: rpm-build-compat

%define anyservicedir /var/lib/anyservice

%description
Anyservice - scripts for making systemd like service from any programs

%prep
%setup

%build

%install
mkdir -p %buildroot/%anyservicedir/
mkdir -p %buildroot/%_bindir/

cp -a * %buildroot/%anyservicedir/

%check
#check that port listening

%pre
%files
%attr(755,root,root) %dir %anyservicedir/
%anyservicedir/*

%changelog
* Mon Apr 25 2016 Danil Mikhailov <danil@altlinux.org> 0.1-alt2
- building version

* Mon Apr 25 2016 Danil Mikhailov <danil@altlinux.org> 0.1-alt1
- initial package version

