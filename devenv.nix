{ pkgs, config, ... }:

let
  qt = pkgs.qt6;
  root = config.devenv.root;

  # Pin Qt runtime lookups to the Qt this project builds against, so plugins
  # from the user's profile (possibly another Qt version) are never loaded.
  qtPluginPath = builtins.concatStringsSep ":" [
    "${qt.qtbase}/lib/qt-6/plugins"
    "${qt.qtdeclarative}/lib/qt-6/plugins"
    "${qt.qtsvg}/lib/qt-6/plugins"
    "${qt.qtwayland}/lib/qt-6/plugins"
  ];
  qmlImportPath = "${qt.qtdeclarative}/lib/qt-6/qml";
in
{
  packages = [
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.xz
    pkgs.xz.dev
    qt.qtbase
    qt.qtdeclarative
    qt.qtsvg
    qt.qtwayland
  ];

  env = {
    QT_PLUGIN_PATH = qtPluginPath;
    QML_IMPORT_PATH = qmlImportPath;
    QML2_IMPORT_PATH = "";
  };

  scripts = {
    configure.exec = ''
      cmake -S "${root}" -B "${root}/build" -G Ninja -DCMAKE_BUILD_TYPE=''${1:-Release}
    '';
    build.exec = ''
      [ -f "${root}/build/build.ninja" ] || configure
      cmake --build "${root}/build"
    '';
    run-tests.exec = ''
      build && QT_QPA_PLATFORM=offscreen ctest --test-dir "${root}/build" --output-on-failure "$@"
    '';
    run-editor.exec = ''
      exec "${root}/build/bin/OTEditor" "$@"
    '';
    install-desktop.exec = ''
      set -e
      bin="${root}/build/bin/OTEditor"
      [ -x "$bin" ] || { echo "Build first: $bin not found (run 'build')." >&2; exit 1; }
      dir="''${XDG_DATA_HOME:-$HOME/.local/share}/applications"
      mkdir -p "$dir"
      cat > "$dir/oteditor.desktop" <<EOF
      [Desktop Entry]
      Type=Application
      Name=OTEditor (dev)
      Comment=Tibia object editor (local build)
      Exec=env -u QML2_IMPORT_PATH QT_PLUGIN_PATH=${qtPluginPath} QML_IMPORT_PATH=${qmlImportPath} $bin %F
      Path=${root}
      Icon=${root}/assets/icons/oteditor.ico
      Terminal=false
      Categories=Development;Graphics;
      EOF
      echo "Installed $dir/oteditor.desktop"
    '';
  };

  enterShell = ''
    echo "OTEditor dev shell: configure | build | run-tests | run-editor | install-desktop"
  '';

  enterTest = ''
    run-tests
  '';
}
