{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  ruby,
  bundlerEnv,
  testers,
  python3,
}:

let
  env = bundlerEnv {
    inherit ruby;
    name = "metasploit-bundler-env";
    gemdir = ./.;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "metasploit-framework";
  version = "6.4.53";

  src = fetchFromGitHub {
    owner = "rapid7";
    repo = "metasploit-framework";
    tag = finalAttrs.version;
    hash = "sha256-yHat9U8EZbUWo4j9ut6K9IPtPFm130pfSmIuhtQhFoQ=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    (python3.withPackages (ps: [ ps.requests ]))
  ];

  dontPatchELF = true; # stay away from exploit executables

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/msf}

    cp -r * $out/share/msf

    grep -rl "^#\!.*python2$" $out/share/msf | xargs -d '\n' rm

    (
      cd $out/share/msf/
      for i in msf*; do
        makeWrapper ${env}/bin/bundle $out/bin/$i \
          --add-flags "exec ${ruby}/bin/ruby $out/share/msf/$i"
      done
    )

    makeWrapper ${env}/bin/bundle $out/bin/msf-pattern_create \
      --add-flags "exec ${ruby}/bin/ruby $out/share/msf/tools/exploit/pattern_create.rb"

    makeWrapper ${env}/bin/bundle $out/bin/msf-pattern_offset \
      --add-flags "exec ${ruby}/bin/ruby $out/share/msf/tools/exploit/pattern_offset.rb"

    runHook postInstall
  '';

  passthru.tests = {
    msfconsole-version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "HOME=/tmp msfconsole -q -x 'version;exit'";
    };
  };

  # run with: nix-shell maintainers/scripts/update.nix --argstr path metasploit
  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Metasploit Framework - a collection of exploits";
    homepage = "https://docs.metasploit.com/";
    platforms = platforms.unix;
    license = licenses.bsd3;
    maintainers = with maintainers; [
      fab
      makefu
    ];
    mainProgram = "msfconsole";
  };
})
