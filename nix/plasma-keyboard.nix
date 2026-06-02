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
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "plasma-keyboard";
  version = "6.6.80-unstable-4f32f02";

  src = fetchFromGitHub {
    owner = "egigoka";
    repo = "plasma-keyboard";
    rev = "4f32f02735c54ec7367cf8772667d89c5fcf0dd9";
    hash = "sha256-CYiv5BBhfxehfHjL9KceiqsEXUCWrMgn9L93ZQlHgP0=";
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
  ];

  # The shipped .desktop has a bare `Exec=plasma-keyboard`; KWin won't have the
  # nix profile on PATH, so point it at the absolute (wrapped) binary path.
  postInstall = ''
    substituteInPlace $out/share/applications/org.kde.plasma.keyboard.desktop \
      --replace-fail 'Exec=plasma-keyboard' "Exec=$out/bin/plasma-keyboard"
  '';

  meta = {
    description = "Qt Virtual Keyboard based on-screen keyboard for Plasma (egigoka fork)";
    homepage = "https://github.com/egigoka/plasma-keyboard";
    license = with lib.licenses; [ gpl2Only gpl3Only bsd2 lgpl21Only ];
    mainProgram = "plasma-keyboard";
    platforms = lib.platforms.linux;
  };
})
