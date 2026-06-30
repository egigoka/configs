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
  version = "6.7.80-unstable-f1e7537.e4";

  src = fetchFromGitHub {
    owner = "egigoka";
    repo = "plasma-keyboard";
    rev = "f1e753764261fae2482d562d440c4dcccbf6336e";
    hash = "sha256-cbmm/sm+qbSSQzuQxVP3PFUVgjAOccrScU7w0omhTpE=";
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
    cp $out/share/applications/org.kde.plasma.keyboard.desktop \
      $out/share/applications/org.kde.plasma.keyboard.${finalAttrs.version}.desktop
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
