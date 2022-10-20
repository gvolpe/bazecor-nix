{ lib, appimageTools, fetchurl }:

let
  pname = "Bazecor";
  version = "1.0.0-Beta15";
  udevRules = builtins.readFile ./10-dygma.rules;
in
appimageTools.wrapAppImage rec {
  name = "${pname}-${version}-binary";

  #let filename = "/etc/udev/rules.d/10-dygma.rules";
  src = appimageTools.extract {
    inherit name;
    src = fetchurl {
      url = "https://github.com/Dygmalab/${pname}/releases/download/bazecor-${version}/${pname}-${version}.AppImage";
      sha256 = "sha256-ymAJemk4x5ETPIqwWOJDXfqt8uSF+hcRfYDU11yr0yM=";
    };
  };

  multiPkgs = null;
  extraPkgs = p: (appimageTools.defaultFhsEnvArgs.multiPkgs p) ++ [
    p.glib
  ];

  # Also expose the udev rules here, so it can be used as:
  #   services.udev.packages = [ pkgs.bazecor ];
  # to allow non-root modifications to the keyboards.

  extraInstallCommands = ''
    mv $out/bin/${name} $out/bin/${pname}
    mkdir -p $out/lib/udev/rules.d
    echo '${udevRules}' > $out/lib/udev/rules.d/10-dygma.rules
  '';

  meta = with lib; {
    description = "A graphical configurator for Dygma Raise and Defy keyboards";
    homepage = "https://github.com/Dygmalab/Bazecor";
    license = licenses.gpl3;
    maintainers = with maintainers; [ gvolpe ];
    platforms = [ "x86_64-linux" ];
  };
}
