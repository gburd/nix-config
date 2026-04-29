{ writeShellScriptBin
, nodejs
}:

# Wrapper for memelord MCP server (persistent memory for coding agents)
# Uses memelord from npm (https://github.com/glommer/memelord)
writeShellScriptBin "memelord" ''
  exec ${nodejs}/bin/npx -y memelord "$@"
''
