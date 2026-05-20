{ lib, rustPlatform, fetchFromGitHub, pkg-config, openssl }:
rustPlatform.buildRustPackage rec {
  pname = "lean-ctx";
  version = "0.3.0";
  src = fetchFromGitHub {
    owner = "yvgude";
    repo = "lean-ctx";
    rev = "main";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
  meta = with lib; {
    description = "Context compression OS for AI development — 51+ MCP tools, AST-aware";
    homepage = "https://github.com/yvgude/lean-ctx";
    license = licenses.mit;
    mainProgram = "lean-ctx";
  };
}
