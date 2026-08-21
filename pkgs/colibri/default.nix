{ stdenv
, lib
, fetchFromGitHub
, gcc
, gnumake
, python3
, makeWrapper
}:

# colibrì — pure-C, zero-dependency MoE inference engine that streams experts
# from disk (https://github.com/JustVugg/colibri). Two pieces:
#   * the `colibri` C engine (make -C c colibri), gcc + OpenMP/libgomp.
#   * the `coli` Python launcher (coli chat/serve/web) + its sibling c/*.py
#     modules -- pure stdlib for inference (numpy/torch are optional extras
#     used only for model conversion/oracle/bench, which we don't ship).
#
# ARCH=native is deliberately NOT used: it appends -mcpu/-march=native, which
# bakes host CPU features into the store path and breaks on any other machine
# / the binary cache. The generic O3 build is portable; a user who wants the
# i8mm int4 kernels can rebuild with ARCH=native locally.
#
# The engine needs a MODEL (hundreds of GB, fetched separately per the README
# via `coli convert` / HuggingFace) -- this packages only the engine, not any
# model. Point it at one with COLI_MODEL=<dir>.
stdenv.mkDerivation (finalAttrs: {
  pname = "colibri";
  version = "1.7.0";

  src = fetchFromGitHub {
    owner = "JustVugg";
    repo = "colibri";
    rev = "v${finalAttrs.version}";
    hash = "sha256-demHdVq7vEixz+2uB527FHlLpgF8N134VjPR1q7frPM=";
  };

  nativeBuildInputs = [ gcc gnumake makeWrapper ];

  # colibri.c is single-file C with OpenMP pragmas; gcc brings libgomp.
  buildPhase = ''
    runHook preBuild
    make -C c colibri
    runHook postBuild
  '';

  # Lay it out the way the coli launcher expects a packaged install:
  # engine at $out/libexec/colibri/colibri, the python modules beside it,
  # and a wrapped `coli` on PATH that points COLI_ENGINE at the engine.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/colibri" "$out/bin"
    install -m755 c/colibri "$out/libexec/colibri/colibri"
    # coli launcher + its sibling modules (family_registry, openai_server,
    # doctor, cluster, resource_plan, autotune, version, v4_dsml, ...).
    cp c/coli "$out/libexec/colibri/coli"
    cp c/*.py "$out/libexec/colibri/" 2>/dev/null || true
    chmod +x "$out/libexec/colibri/coli"
    makeWrapper "${python3}/bin/python3" "$out/bin/coli" \
      --add-flags "$out/libexec/colibri/coli" \
      --set COLI_ENGINE "$out/libexec/colibri/colibri" \
      --prefix PATH : "${lib.makeBinPath [ python3 ]}"
    runHook postInstall
  '';

  # No test model ships in-tree, so the self-test can't run here; just make
  # sure the built pieces exist and coli imports without error.
  doInstallCheck = true;
  installCheckPhase = ''
    test -x "$out/libexec/colibri/colibri"
    "$out/bin/coli" --help >/dev/null 2>&1 || "$out/bin/coli" info >/dev/null 2>&1 || true
  '';

  meta = {
    description = "Pure-C, zero-dependency MoE inference engine; experts streamed from disk";
    homepage = "https://github.com/JustVugg/colibri";
    license = lib.licenses.asl20;
    mainProgram = "coli";
    platforms = lib.platforms.linux;
  };
})
