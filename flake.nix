{
  description = "Bazecor (Graphical configurator for Dygma Raise and Defy) Nix flake";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixpkgs-unstable;
    bazecor-src = {
      url = github:Dygmalab/Bazecor;
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, bazecor-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    rec {
      packages.${system} = rec {
        default = desktop;

        desktop = pkgs.callPackage ./appimage.nix { };

        bazecor = pkgs.mkYarnPackage rec {
          name = "Bazecor";
          version = "1.0.0-beta-dev";
          src = bazecor-src;

          dontFixup = true;

          extraBuildInputs = [ pkgs.electron ];
          #extraBuildInputs = [ pkgs.nodePackages.cordova pkgs.stdenv.cc.cc.lib pkgs.p7zip pkgs.autoPatchelfHook pkgs.zlib ];
          configurePhase = ''
            runHook preConfigure
            export HOME=$(mktemp -d)
            yarn config --offline set yarn-offline-mirror $offlineCache
            fixup_yarn_lock yarn.lock
            yarn install --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive
            patchShebangs node_modules/
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            yarn --offline compile
            yarn --offline run electron-builder -l
            runHook postBuild
          '';

          distPhase = "true";
          #USE_SYSTEM_7ZA = "true";
          NODE_OPTIONS = "--openssl-legacy-provider";
          ELECTRON_BUILDER_OFFLINE = "true";
          ELECTRON_SKIP_BINARY_DOWNLOAD = "true";
          DEBUG = "electron-builder";
          #packageJSON = ./package.json;
          #yarnLock = ./yarn.lock;
          #yarnNix = ./yarn.nix;

          #postInstall = ''
          #substituteInPlace $out/${outDir}/tyrianapp.js \
          #--replace "./target/scala-3.2.1-RC4/webapp-fastopt/main.js" "./main.js"
          #'';

          #distPhase = "true";
        };
      };
    };
}
