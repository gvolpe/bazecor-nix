{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, makeWrapper
  #, makeDesktopItem
, fixup_yarn_lock
, yarn
, nodejs
, fetchYarnDeps
, electron
, nodePackages
, mkYarnModules
, mkYarnPackage
, pcre
, p7zip
, squashfsTools
, unzip
  #, element-web
  #, sqlcipher
, callPackage
  #, Security
  #, AppKit
  #, CoreServices
  #, desktopToDarwinBundle
  #, useKeytar ? true
}:

let
  pinData = lib.importJSON ./pin.json;
  executableName = "Bazecor";
  #keytar = callPackage ./keytar { inherit Security AppKit; };
  #seshat = callPackage ./seshat { inherit CoreServices; };
in
stdenv.mkDerivation rec {
  pname = "Bazecor";
  version = "development-${pinData.version}";
  name = "${pname}-${version}";
  src = fetchFromGitHub {
    owner = "Dygmalab";
    repo = "Bazecor";
    rev = pinData.version;
    sha256 = pinData.srcHash;
  };

  offlineCache = fetchYarnDeps {
    packageJSON = src + "/package.json";
    yarnLock = src + "/yarn.lock";
    sha256 = pinData.yarnHash;
  };

  src-modules = mkYarnModules {
    inherit offlineCache version;
    pname = "Bazecor-modules";
    yarnLock = src + "/yarn.lock";
    packageJSON = src + "/package.json";
    #workspaceDependencies = [ acorn ];
  };

  nativeBuildInputs = [ yarn fixup_yarn_lock nodejs makeWrapper ];
  #++ lib.optionals stdenv.isDarwin [ desktopToDarwinBundle ];

  #inherit seshat;

  #acorn = mkYarnPackage {
    #name = "acorn___acorn_7.4.1.tgz";
    #src = fetchurl {
      #name = "acorn_stage3___acorn_stage3_3.1.0.tgz";
      #url = "https://registry.yarnpkg.com/acorn-stage3/-/acorn-stage3-3.1.0.tgz";
      #sha512 = "iKDUmzlsw5Rs3lOTCuq3lcOddHTn3xX9gpCfoXSXAr5E9IxqJWkECKBVcSYJZRCaiNGCGNops87AdB8I1fIl2A==";
    #};
  #};

  configurePhase = ''
    runHook preConfigure
    export HOME=$(mktemp -d)
    yarn config --offline set yarn-offline-mirror ${offlineCache}
    fixup_yarn_lock yarn.lock
    ${nodePackages.json}/bin/json -I -f package.json -e 'this.build.acorn = this.build.acorn-with-stage3'

    yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
    patchShebangs node_modules/
    runHook postConfigure
  '';

  electronPackage = stdenv.mkDerivation {
    name = "electron-linux-x64";
    version = electron.version;
    dontStrip = true;
    dontPatch = true;
    dontUnpack = true;
    dontInstall = true;
    dontFixup = true;
    dontConfigure = true;
    buildPhase = ''
      mkdir -p $out
      ${unzip}/bin/unzip -q ${electron.src} -d $out
    '';
  };

  #buildPhase = ''
  #runHook preBuild
  #yarn --offline run build:ts
  #yarn --offline run i18n
  #yarn --offline run build:res
  #rm -rf node_modules/matrix-seshat node_modules/keytar
  #${lib.optionalString useKeytar "ln -s ${keytar} node_modules/keytar"}
  #ln -s $seshat node_modules/matrix-seshat
  #runHook postBuild
  #'';

  #yarn --offline run build:linux
  buildPhase = ''
    runHook preBuild
    export ELECTRON_BUILDER_CACHE="$(mktemp -d)"
    NODE_OPTIONS=--openssl-legacy-provider yarn --offline compile
    ${nodePackages.json}/bin/json -I -f package.json -e 'this.build.electronVersion = "${electron.version}"'
    ${nodePackages.json}/bin/json -I -f package.json -e 'this.build.electronDist = "${electronPackage}"'

    mkdir -p $ELECTRON_BUILDER_CACHE/appimage
    cp -rs ${appimage} $ELECTRON_BUILDER_CACHE/appimage/appimage-${appimage.version}
    chmod -R +rw $ELECTRON_BUILDER_CACHE/appimage/appimage-${appimage.version}
    find $ELECTRON_BUILDER_CACHE/appimage -name "*mksquashfs*" -exec ln -fs ${squashfsTools}/bin/mksquashfs {} \;

    var1="windows" var2="mac"
    ${nodePackages.json}/bin/json -I -f build.json -e "delete this.electron.$var1; delete this.electron.$var2"
    ${nodePackages.json}/bin/json -I -f build.json -e 'this.electron.linux.arch = ["x64"]'

    ELECTRON_BUILDER_OFFLINE=true ELECTRON_SKIP_BINARY_DOWNLOAD=true yarn --offline run electron-builder -l
    runHook postBuild
  '';


  appImageVersion = stdenv.mkDerivation {
    name = "electron-appimage-version";
    version = "0.0.0";
    dontStrip = true;
    dontPatch = true;
    dontUnpack = true;
    dontInstall = true;
    dontConfigure = true;
    buildPhase = ''
      mkdir -p $out
      strings ${src-modules}/node_modules/app-builder-bin/linux/x64/app-builder | ${pcre}/bin/pcregrep -o1 'appimage-([\d\.]+)' | xargs echo -n > $out/version
      strings ${src-modules}/node_modules/app-builder-bin/linux/x64/app-builder | ${pcre}/bin/pcregrep -o1 'electron-build-service\)([A-Za-z0-9\/=\+]+?==)' | xargs echo -n > $out/sha512
    '';
  };

  appimage = stdenv.mkDerivation rec {
    name = "electron-appimage";
    dontUnpack = true;
    dontInstall = true;
    version = (builtins.readFile "${appImageVersion}/version");
    archive = fetchurl {
      url = "https://github.com/electron-userland/electron-builder-binaries/releases/download/appimage-${version}/appimage-${version}.7z";
      sha512 = (builtins.readFile "${appImageVersion}/sha512");
    };
    buildPhase = ''mkdir -p $out; ${p7zip}/bin/7z x ${archive} -o $out'';
  };

  distPhase = "true";

  #installPhase = ''
  #runHook preInstall
  ## resources
  #mkdir -p "$out/share/element"
  #ln -s '${element-web}' "$out/share/element/webapp"
  #cp -r '.' "$out/share/element/electron"
  #cp -r './res/img' "$out/share/element"
  #rm -rf "$out/share/element/electron/node_modules"
  #cp -r './node_modules' "$out/share/element/electron"
  #cp $out/share/element/electron/lib/i18n/strings/en_EN.json $out/share/element/electron/lib/i18n/strings/en-us.json
  #ln -s $out/share/element/electron/lib/i18n/strings/en{-us,}.json
  ## icons
  #for icon in $out/share/element/electron/build/icons/*.png; do
  #mkdir -p "$out/share/icons/hicolor/$(basename $icon .png)/apps"
  #ln -s "$icon" "$out/share/icons/hicolor/$(basename $icon .png)/apps/element.png"
  #done
  ## desktop item
  #mkdir -p "$out/share"
  #ln -s "${desktopItem}/share/applications" "$out/share/applications"
  ## executable wrapper
  ## LD_PRELOAD workaround for sqlcipher not found: https://github.com/matrix-org/seshat/issues/102
  #makeWrapper '${electron}/bin/electron' "$out/bin/${executableName}" \
  #--set LD_PRELOAD ${sqlcipher}/lib/libsqlcipher.so \
  #--add-flags "$out/share/element/electron" \
  #--add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
  #runHook postInstall
  #'';

  # The desktop item properties should be kept in sync with data from upstream:
  # https://github.com/vector-im/element-desktop/blob/develop/package.json
  #desktopItem = makeDesktopItem {
  #name = "element-desktop";
  #exec = "${executableName} %u";
  #icon = "element";
  #desktopName = "Element";
  #genericName = "Matrix Client";
  #comment = meta.description;
  #categories = [ "Network" "InstantMessaging" "Chat" ];
  #startupWMClass = "element";
  #mimeTypes = [ "x-scheme-handler/element" ];
  #};

  passthru = {
    updateScript = ./update.sh;

    # TL;DR: keytar is optional while seshat isn't.
    #
    # This prevents building keytar when `useKeytar` is set to `false`, because
    # if libsecret is unavailable (e.g. set to `null` or fails to build), then
    # this package wouldn't even considered for building because
    # "one of the dependencies failed to build",
    # although the dependency wouldn't even be used.
    #
    # It needs to be `passthru` anyways because other packages do depend on it.
    #inherit keytar;
  };

  meta = with lib; {
    description = "Graphical configurator for Dygma Raise and Defy";
    homepage = "https://github.com/Dygmalab/Bazecor";
    license = licenses.gpl3;
    maintainers = [ maintainers.gvolpe ];
  };
}
