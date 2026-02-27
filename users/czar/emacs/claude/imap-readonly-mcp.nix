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
    CFG="$(${pkgs.coreutils}/bin/mktemp -p "''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}")"
    trap "${pkgs.coreutils}/bin/rm -f '$CFG'" EXIT
    PASSWORD="$(${pkgs.pass}/bin/pass hrhr.dev/hr | head -n1)"
    CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/imap-readonly-mcp"
    ${pkgs.coreutils}/bin/mkdir -p "$CACHE_DIR"
    ${pkgs.coreutils}/bin/cat > "$CFG" <<EOF
    cache_path: $CACHE_DIR/email_cache.sqlite
    account:
      protocol: imap
      host: hrhr.dev
      port: 993
      username: hr
      password: "$PASSWORD"
    EOF
    ${pkgs.coreutils}/bin/chmod 600 "$CFG"
    ${imap-readonly-mcp}/bin/imap-readonly-mcp --config "$CFG" "$@"
  '';

in
{
  programs.emacs.extraConfig = ''
    (with-eval-after-load 'claude-code-ide
      (add-to-list 'claude-code-ide-on-demand-mcp-servers
        '("imap-readonly"
          . ((type . "stdio")
             (command . "${imap-readonly-mcp-wrapper}/bin/imap-readonly-mcp-wrapper")
             (args . [])))))
  '';
}
