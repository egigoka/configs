# Builds the egigoka/plasma-keyboard fork (a Qt Virtual Keyboard based on-screen
# keyboard that integrates with Plasma via the input-method-v1 Wayland protocol).
# Not in nixpkgs, and SteamOS's root is read-only, so we package it here and let
# home-manager install it into the user profile. KWin launches it as the input
# method (see kwinrc [Wayland] InputMethod), so the cross-toolkit Wayland protocol
# keeps the nix-built binary working against the system Plasma session.
{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, pkg-config
, gettext
, extra-cmake-modules
, wrapQtAppsHook
, qtbase
, qtdeclarative
, qtsvg
, qtvirtualkeyboard
, qtwayland
, wayland
, wayland-protocols
, plasma-wayland-protocols
, kcoreaddons
, ki18n
, kcmutils
, kconfig
, kirigami
, libplasma
, mesa
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "plasma-keyboard";
  version = "6.6.80-unstable-0fb3ce9";

  src = fetchFromGitHub {
    owner = "egigoka";
    repo = "plasma-keyboard";
    rev = "0fb3ce95c53e2e5e45dfa9d44c7fffcadb82ed68";
    hash = "sha256-tmn04C/9Yp3BSFqiZa3ml85XVDhVS21p3IX+pqket/c=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    gettext
    extra-cmake-modules
    wrapQtAppsHook
    qtwayland # qtwaylandscanner build tool
  ];

  buildInputs = [
    qtbase
    qtdeclarative
    qtsvg
    qtvirtualkeyboard
    qtwayland
    wayland
    wayland-protocols
    plasma-wayland-protocols
    kcoreaddons
    ki18n
    kcmutils
    kconfig
    kirigami
    libplasma # provides PlasmaQuick
  ];

  # The PlasmaQuick version floor (PROJECT_DEP_VERSION) is just KDE's automated
  # per-release bump (GIT_SILENT "Update version for new release"). nixpkgs ships
  # libplasma 6.6.5, which provides the same PlasmaQuick API this links against
  # (no PlasmaQuick headers are used). Drop the pin so it configures against the
  # available libplasma.
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail 'find_package(PlasmaQuick ''${PROJECT_DEP_VERSION} REQUIRED)' 'find_package(PlasmaQuick REQUIRED)'
  '';

  # The shipped .desktop has a bare `Exec=plasma-keyboard`; KWin won't have the
  # nix profile on PATH, so point it at the absolute (wrapped) binary path.
  postInstall = ''
    substituteInPlace $out/share/applications/org.kde.plasma.keyboard.desktop \
      --replace-fail 'Exec=plasma-keyboard' "Exec=$out/bin/plasma-keyboard"
  '';

  # Point libglvnd at Nix Mesa's absolute-path EGL ICD. SteamOS's ICD JSON uses
  # a relative libEGL_mesa.so.0 that Nix's dynamic linker cannot resolve.
  qtWrapperArgs = [
    "--set-default"
    "__EGL_VENDOR_LIBRARY_DIRS"
    "${mesa}/share/glvnd/egl_vendor.d"
    "--set-default"
    "__EGL_VENDOR_LIBRARY_FILENAMES"
    "${mesa}/share/glvnd/egl_vendor.d/50_mesa.json"
  ];

  meta = {
    description = "Qt Virtual Keyboard based on-screen keyboard for Plasma (egigoka fork)";
    homepage = "https://github.com/egigoka/plasma-keyboard";
    license = with lib.licenses; [ gpl2Only gpl3Only bsd2 lgpl21Only ];
    mainProgram = "plasma-keyboard";
    platforms = lib.platforms.linux;
  };
})
