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
    ${pkgs.coreutils}/bin/cat > "$CFG" <<EOF
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
      (defvar claude-code-ide-on-demand-mcp-servers
        '(("imap-readonly"
           . ((type . "stdio")
              (command . "${imap-readonly-mcp-wrapper}/bin/imap-readonly-mcp-wrapper")
              (args . [])))))

      (defvar claude-code-ide-on-demand-mcp-enabled nil)

      (defun claude-code-ide--on-demand-mcp-advice (orig-fn &rest args)
        (let ((cmd (apply orig-fn args)))
          (dolist (name claude-code-ide-on-demand-mcp-enabled)
            (when-let ((config (alist-get name claude-code-ide-on-demand-mcp-servers
                                          nil nil #'string=)))
              (let* ((wrapper (list (cons 'mcpServers
                                         (list (cons (intern name) config)))))
                     (json-str (json-encode wrapper)))
                (setq cmd (concat cmd " --mcp-config "
                                  (shell-quote-argument json-str))))))
          cmd))

      (advice-add 'claude-code-ide--build-claude-command
                  :around #'claude-code-ide--on-demand-mcp-advice)

      (transient-define-suffix claude-code-ide-select-mcp-servers ()
        "Select on-demand MCP servers to enable."
        :description (lambda ()
                       (format "MCP servers [%s]"
                               (if claude-code-ide-on-demand-mcp-enabled
                                   (string-join claude-code-ide-on-demand-mcp-enabled ", ")
                                 "none")))
        (interactive)
        (setq claude-code-ide-on-demand-mcp-enabled
              (completing-read-multiple
               "Enable MCP servers: "
               (mapcar #'car claude-code-ide-on-demand-mcp-servers)
               nil t))
        (message "MCP servers: %s"
                 (if claude-code-ide-on-demand-mcp-enabled
                     (string-join claude-code-ide-on-demand-mcp-enabled ", ")
                   "none")))

      (transient-append-suffix 'claude-code-ide-menu "d"
        '("m" claude-code-ide-select-mcp-servers)))
  '';
}
