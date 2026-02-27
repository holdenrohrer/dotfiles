{ config, lib, pkgs, ... }:

{
  imports = [
    ./ralph-loop.nix
    ./playwright.nix
    ./claude-md.nix
    ./imap-readonly-mcp.nix
  ];

  # Composable Claude Code settings -- modules contribute via these options
  options.claude = {
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Claude Code settings.json key-value pairs.";
    };

    hooks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
      default = {};
      description = "Claude Code hooks by event name. Lists auto-merge across modules.";
    };
  };

  config = {
    # Base settings
    claude.settings = {
      cleanupPeriodDays = 99999;
      alwaysThinkingEnabled = true;
      skipDangerousModePermissionPrompt = true;
      enabledPlugins."feature-dev@claude-plugins-official" = true;
    };

    # Serialize settings + hooks into settings.json
    home.file.".claude/settings.json".text = builtins.toJSON (
      config.claude.settings
      // lib.optionalAttrs (config.claude.hooks != {}) {
        hooks = config.claude.hooks;
      }
    );

    # On-demand MCP server framework for Emacs
    programs.emacs.extraConfig = lib.mkBefore ''
      (with-eval-after-load 'claude-code-ide
        (defvar claude-code-ide-on-demand-mcp-servers '())
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

        (defun claude-code-ide-select-mcp-servers ()
          "Select on-demand MCP servers to enable."
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

        (put 'claude-code-ide-select-mcp-servers 'transient--suffix
             (transient-suffix
              :command 'claude-code-ide-select-mcp-servers
              :description (lambda ()
                             (format "MCP servers [%s]"
                                     (if claude-code-ide-on-demand-mcp-enabled
                                         (string-join claude-code-ide-on-demand-mcp-enabled ", ")
                                       "none")))))

        (transient-append-suffix 'claude-code-ide-menu "d"
          '("m" claude-code-ide-select-mcp-servers)))
    '';
  };
}
