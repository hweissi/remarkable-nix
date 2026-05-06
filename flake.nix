{
  description = "reMarkable Desktop (Windows) wrapped with Wine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      version = "3.27.0.1446";
      installer = pkgs.fetchurl {
        url = "https://downloads.remarkable.com/desktop/production/win/reMarkable-${version}-win64.exe";
        sha256 = "sha256-LOfQpwRB5tZZfPopDsw1jTasdUuqMXedj3Gi2vsA+HM=";
      };

      remarkableApp = pkgs.stdenvNoCC.mkDerivation {
        pname = "remarkable-desktop-app";
        inherit version;
        dontUnpack = true;
        nativeBuildInputs = [
          pkgs.p7zip
          pkgs.python3
          pkgs.icoutils
        ];

        installPhase = ''
          runHook preInstall

          install -d "$out/share/remarkable/app"

          tmpdir="$(mktemp -d)"
          trap 'rm -rf "$tmpdir"' EXIT
          export INSTALLER="${installer}"
          export PAYLOAD_OUT="$tmpdir/payloads"
          mkdir -p "$PAYLOAD_OUT"

          python3 ${./scripts/extract_payloads.py} "$INSTALLER" "$PAYLOAD_OUT"

          for f in "$PAYLOAD_OUT"/payload-*.7z; do
            7z x -y "$f" -o"$out/share/remarkable/app" >/dev/null || true
          done

          if [ ! -f "$out/share/remarkable/app/reMarkable.exe" ]; then
            echo "reMarkable.exe not found after extraction" >&2
            find "$out/share/remarkable/app" -maxdepth 3 -type f -name "reMarkable.exe" -print >&2 || true
            exit 1
          fi

          if [ -f "$out/share/remarkable/app/remarkable.ico" ]; then
            icon_tmp="$tmpdir/icons"
            mkdir -p "$icon_tmp"
            ${pkgs.icoutils}/bin/icotool -x "$out/share/remarkable/app/remarkable.ico" -o "$icon_tmp/" || true
            shopt -s nullglob
            found_icon=false
            for p in "$icon_tmp"/*.png; do
              base="$(basename "$p" .png)"
              size="''${base##*_}"
              size="''${size%x*}"
              if [ -n "$size" ]; then
                mkdir -p "$out/share/icons/hicolor/$size/apps"
                install -m644 "$p" "$out/share/icons/hicolor/$size/apps/remarkable.png"
                found_icon=true
              fi
            done
            shopt -u nullglob
            if [ "$found_icon" = false ]; then
              echo "No usable PNG icons extracted from remarkable.ico" >&2
            fi
          fi

          runHook postInstall
        '';

        meta = {
          description = "reMarkable Desktop app payload (extracted)";
          homepage = "https://remarkable.com";
          platforms = ["x86_64-linux"];
        };
      };

      mkWrapper = {
        pname,
        binName,
        desktopName,
        wrapperScript,
        comment ? "reMarkable desktop application (runs via Wine)",
      }:
        pkgs.stdenvNoCC.mkDerivation {
          inherit pname version;
          dontUnpack = true;
          nativeBuildInputs = [pkgs.copyDesktopItems];
          propagatedBuildInputs = [remarkableApp];

          desktopItems = [
            (pkgs.makeDesktopItem {
              name = binName;
              desktopName = desktopName;
              comment = comment;
              exec = binName;
              icon = "remarkable";
              categories = ["Office" "Utility"];
              startupNotify = true;
            })
          ];

          installPhase = ''
            runHook preInstall

            install -d "$out/bin"
            install -m755 ${wrapperScript} "$out/bin/${binName}"
            substituteInPlace "$out/bin/${binName}" \
              --replace "@app@" "${remarkableApp}" \
              --replace "@wine@" "${pkgs.wineWow64Packages.stable}" \
              --replace "@notify@" "${pkgs.libnotify}"

            if [ -d "${remarkableApp}/share/icons/hicolor" ]; then
              install -d "$out/share/icons"
              cp -R "${remarkableApp}/share/icons/hicolor" "$out/share/icons/"
              icon_src=""
              if [ -f "${remarkableApp}/share/icons/hicolor/256x256/apps/remarkable.png" ]; then
                icon_src="${remarkableApp}/share/icons/hicolor/256x256/apps/remarkable.png"
              else
                icon_src="$(ls -1 ${remarkableApp}/share/icons/hicolor/*/apps/remarkable.png 2>/dev/null | head -n 1)"
              fi
              if [ -n "$icon_src" ]; then
                install -d "$out/share/pixmaps"
                install -m644 "$icon_src" "$out/share/pixmaps/remarkable.png"
              fi
            fi

            runHook postInstall
          '';

          meta = {
            description = "reMarkable Desktop (Windows) wrapped with Wine";
            homepage = "https://remarkable.com";
            platforms = ["x86_64-linux"];
          };
        };
    in {
      remarkable = mkWrapper {
        pname = "remarkable-desktop";
        binName = "remarkable";
        desktopName = "reMarkable Desktop";
        wrapperScript = ./scripts/remarkable-wrapper.sh;
      };

      remarkable-app = remarkableApp;
      default = self.packages.${system}.remarkable;
    });

    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = "${self.packages.${system}.remarkable}/bin/remarkable";
      };
    });
  };
}
