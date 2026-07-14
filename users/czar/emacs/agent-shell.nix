{ config, pkgs, inputs, outputs, sharedConfig, ... }:

{
  # agent-shell (xenodium) gives a comint-style shell to ACP agents.
  #   - Codex via the `codex-acp` adapter (zed-industries), in nixpkgs.
  #   - Claude via `claude-agent-acp` (the modern Claude Agent SDK shim,
  #     agentclientprotocol/claude-agent-acp), from nixpkgs-unstable.
  # Both authenticate from existing CLI logins (~/.codex, ~/.claude) — no API
  # keys. NOTE: as of 2026-06-15 Claude Agent SDK / programmatic usage draws
  # from a separate metered "Agent SDK" credit pool (one-time claim required in
  # Claude billing settings), distinct from interactive claude-code-ide usage.
  home.packages = [
    pkgs.codex-acp
    pkgs.unstable.claude-agent-acp
  ];

  programs.emacs = {
    extraPackages = epkgs: with epkgs; [
      agent-shell
      acp
      shell-maker
    ];

    extraConfig = ''
      (use-package agent-shell
        :config
        ;; Point each agent at its ACP adapter on PATH.
        (setq agent-shell-openai-codex-acp-command '("codex-acp")
              agent-shell-anthropic-claude-acp-command '("claude-agent-acp")))
    '';
  };
}
