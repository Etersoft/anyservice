Name: anyservice
Version: 0.4
Release: alt2

Summary: Anyservice - scripts for making systemd like service from any programs

License: MIT
Group: System/Base
Url: http://wiki.etersoft.ru/Anyservice

# Source-git: https://github.com/Etersoft/anyservice.git
Source: %name-%version.tar

Packager: Danil Mikhailov <danil@altlinux.org>

BuildArch: noarch
BuildPreReq: rpm-build-compat

#Requires: eepm >= 1.9.0

%description
Anyservice - scripts for making systemd like service from any programs

%prep
%setup

%build

%install
mkdir -p %buildroot/%_bindir/
mkdir -p %buildroot/etc/%name/
mkdir -p %buildroot/var/run/%name/
mkdir -p %buildroot/var/log/%name/

cp example.service %buildroot/etc/%name/example.service.off
cp %name.sh %buildroot/%_bindir/%name

%check
#check that port listening

%pre
%files
%dir /etc/%name/
%config(noreplace) /etc/%name/*.service.off
%attr(755,root,root) %_bindir/%name

%dir /var/run/%name/
%dir /var/log/%name/

%changelog
* Tue Aug 23 2016 Vitaly Lipatov <lav@altlinux.ru> 0.4-alt2
- fix EnvironmentFile using

* Tue Aug 23 2016 Vitaly Lipatov <lav@altlinux.ru> 0.4-alt1
- fix logdir and drop obsoleted DEFAULTLOGDIR
- fix Environment, set TMPDIR and HOME

* Tue Aug 16 2016 Vitaly Lipatov <lav@altlinux.ru> 0.3-alt1
- big refactoring
- realize checkd and isautostarted
- add prefix for monit
- put example.service disabled by default
- improve monit status checking
- Caution: use /etc/anyservice as anyservice dir

* Mon Aug 15 2016 Vitaly Lipatov <lav@altlinux.ru> 0.2-alt1
- anyservice.sh: some refactoring
- anyservice.sh: use .off file if exists
- anyservice.sh: add support for EnviromentFile and Environment fields

* Fri Aug 12 2016 Vitaly Lipatov <lav@altlinux.ru> 0.1-alt4
- build for ALT Linux Sisyphus

* Thu May 12 2016 Danil Mikhailov <danil@altlinux.org> 0.1-alt3
- added example, put into right folder

* Mon Apr 25 2016 Danil Mikhailov <danil@altlinux.org> 0.1-alt2
- building version

* Mon Apr 25 2016 Danil Mikhailov <danil@altlinux.org> 0.1-alt1
- initial package version

