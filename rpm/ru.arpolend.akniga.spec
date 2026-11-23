Name:       ru.arpolend.akniga
Summary:    Akniga audiobook browser for Aurora OS
Version:    0.1.0
Release:    1
License:    WTFPL
Source0:    %{name}-%{version}.tar.bz2

BuildRequires: cmake
BuildRequires: pkgconfig(auroraapp)
BuildRequires: pkgconfig(aurorawebview)
BuildRequires: pkgconfig(Qt5Quick)
Requires: aurora-controls

%description
A lightweight Aurora OS application for browsing akniga.org and controlling
its audiobook player.

%prep
%autosetup

%build
%cmake
if [ -f build.ninja ]; then
    %{__ninja}
else
    %{__make} %{?_smp_mflags}
fi

%install
DESTDIR=%{buildroot} cmake --build . --target install

%files
%{_bindir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/scalable/apps/%{name}.svg
%{_datadir}/icons/hicolor/86x86/apps/%{name}.png
%{_datadir}/icons/hicolor/108x108/apps/%{name}.png
%{_datadir}/icons/hicolor/128x128/apps/%{name}.png
%{_datadir}/icons/hicolor/172x172/apps/%{name}.png
