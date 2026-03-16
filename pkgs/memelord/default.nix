{ writeShellScriptBin
, nodejs
}:

# Simple wrapper that uses npx to run memelord from npm
# This avoids the complexity of building from source
writeShellScriptBin "memelord" ''
  exec ${nodejs}/bin/npx memelord@latest "$@"
''
