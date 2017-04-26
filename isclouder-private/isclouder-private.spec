%global __os_install_post %{nil}

Name: isclouder-private
Version: %{client_version}
Release: 1
Summary: Desktop  

Group: GUL
License: Isclouder
URL: http:// 
Source: %{name}-%{version}.tar.gz
Autoprov: no
Autoreq: no

%description
desktop

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/usr/share/isclouder/
cp -rf * %{buildroot}/usr/share/isclouder/

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/share/isclouder/*
