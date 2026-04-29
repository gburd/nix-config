{ writeShellScriptBin
, nodejs
}:

# Wrapper for memelord MCP server (persistent memory for coding agents)
# Uses @glommer/memelord-mcp-server from npm
writeShellScriptBin "memelord" ''
  exec ${nodejs}/bin/npx -y @glommer/memelord-mcp-server "$@"
''
