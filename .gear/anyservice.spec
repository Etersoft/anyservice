Name: anyservice
Version: 0.1
Release: alt3

Summary: Anyservice - scripts for making systemd like service from any programs

License: Mit
Group: System/Base
Url: http://wiki.etersoft.ru/Anyservice

Source: %name-%version.tar

Packager: Danil Mikhailov <danil@altlinux.org>

BuildArch: noarch
BuildPreReq: rpm-build-compat

%description
Anyservice - scripts for making systemd like service from any programs

%prep
%setup

%build

%install
mkdir -p %buildroot/%_bindir/
mkdir -p %buildroot/etc/systemd-lite/
mkdir -p %buildroot/var/run/anyservice
mkdir -p %buildroot/var/log/anyservice

cp example.service %buildroot/etc/systemd-lite/
cp %name.sh %buildroot/%_bindir/%name

%check
#check that port listening

%pre
%files
%dir /etc/systemd-lite/
%config(noreplace) /etc/systemd-lite/*.service
%attr(755,root,root) %_bindir/%name

%dir /var/run/anyservice
%dir /var/log/anyservice

%changelog
* Thu May 12 2016 Danil Mikhailov <danil@altlinux.org> 0.1-alt3
- added example, put into right folder

* Mon Apr 25 2016 Danil Mikhailov <danil@altlinux.org> 0.1-alt2
- building version

* Mon Apr 25 2016 Danil Mikhailov <danil@altlinux.org> 0.1-alt1
- initial package version

