{ config, lib, pkgs, inputs, ... }:

let
  imap-readonly-mcp = pkgs.python3Packages.buildPythonApplication {
    pname = "imap-readonly-mcp";
    version = "0.4.0";
    pyproject = true;

    src = inputs.imap-readonly-mcp-src;

    build-system = [ pkgs.python3Packages.hatchling ];

    dependencies = with pkgs.python3Packages; [
      anyio
      charset-normalizer
      dateparser
      mcp
      pydantic
      pydantic-settings
      pyyaml
      python-dateutil
      rich
      tenacity
      tqdm
      uvicorn
    ];

    doCheck = false;
    pythonImportsCheck = [ "imap_readonly_mcp" ];

    meta = {
      description = "MCP server for read-only IMAP email access";
      homepage = "https://github.com/AzizMarashly/imap-readonly-mcp";
      license = lib.licenses.gpl3Only;
    };
  };

  imap-readonly-mcp-wrapper = pkgs.writeShellScriptBin "imap-readonly-mcp-wrapper" ''
    set -euo pipefail
    PASSWORD="$(${pkgs.pass}/bin/pass hrhr.dev/hr | head -n1)"
    exec ${imap-readonly-mcp}/bin/imap-readonly-mcp \
      --config <(${pkgs.coreutils}/bin/cat <<EOF
    account:
      protocol: imap
      host: hrhr.dev
      port: 993
      username: hr
      password: "$PASSWORD"
    EOF
    ) "$@"
  '';

in
{
  home.packages = [ imap-readonly-mcp-wrapper ];

  home.activation.registerClaudeMcpServers = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    set +e
    CLAUDE="${inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/claude"
    if [ -x "$CLAUDE" ]; then
      "$CLAUDE" mcp add-json --scope user imap-readonly \
        '${builtins.toJSON {
          type = "stdio";
          command = "${imap-readonly-mcp-wrapper}/bin/imap-readonly-mcp-wrapper";
          args = [];
          env = {};
        }}' 2>/dev/null || true

      "$CLAUDE" mcp remove openrouter 2>/dev/null || true
    fi
  '';
}
