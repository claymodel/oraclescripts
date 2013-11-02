Name:           dbseekl
Version:        0.1
Release:        1
Summary:        dbseek, the Oracle DBA shell

Group:          Applications/Databases
License:        BSD
Source:		%{expand:%%(pwd)}
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	x86_64

# no automatic requirements discovery: libclntsh should not become a rpm
# dependency
AutoReq: 0

Requires: libc.so.6()(64bit)  
Requires: libreadline.so.5()(64bit)  
Requires: libtermcap.so.2()(64bit)  

%description
dbseek is an Oracle command-line interface alternative to the stock sqlplus shell.

%install
mkdir -p $RPM_BUILD_ROOT/usr/bin
mkdir -p $RPM_BUILD_ROOT/usr/share/man/man1
cp %{SOURCEURL0}/osql $RPM_BUILD_ROOT/usr/bin/
cp %{SOURCEURL0}/osql.bin $RPM_BUILD_ROOT/usr/bin/
cp %{SOURCEURL0}/osql.1 $RPM_BUILD_ROOT/usr/share/man/man1

# to keep rpmbuild from failing (?!)
test -e %{_topdir}/SOURCES/osql || touch %{_topdir}/SOURCES/osql

%clean
rm -rf $RPM_BUILD_ROOT
rm -f %{_topdir}/SOURCES/osql

%files
%defattr(-,root,root,-)
/usr/bin/osql
/usr/bin/osql.bin
/usr/share/man/man1/osql.1.gz

%changelog
- initial spec file

