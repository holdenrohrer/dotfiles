{ config, lib, pkgs, inputs, ... }:

let
  pluginSrc = "${inputs.claude-plugins-public}/plugins/ralph-loop";

  runtimeDeps = with pkgs; [
    bash
    coreutils
    gnugrep
    gnused
    gawk
    jq
    perl
  ];

  runtimePath = lib.makeBinPath runtimeDeps;

  ralph-setup = pkgs.writeShellScriptBin "ralph-setup" ''
    export PATH="${runtimePath}:$PATH"
    ${builtins.readFile "${pluginSrc}/scripts/setup-ralph-loop.sh"}
  '';

  ralph-stop-hook = pkgs.writeShellScriptBin "ralph-stop-hook" ''
    export PATH="${runtimePath}:$PATH"
    ${builtins.readFile "${pluginSrc}/hooks/stop-hook.sh"}
  '';

in
{
  # Ralph-loop commands
  home.file.".claude/commands/ralph-loop.md".text = ''
    ---
    description: "Start Ralph Loop in current session"
    argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
    allowed-tools: ["Bash(${ralph-setup}/bin/ralph-setup:*)"]
    hide-from-slash-command-tool: "true"
    ---

    # Ralph Loop Command

    Execute the setup script to initialize the Ralph loop:

    ```!
    "${ralph-setup}/bin/ralph-setup" $ARGUMENTS
    ```

    Please work on the task. When you try to exit, the Ralph loop will feed the SAME PROMPT back to you for the next iteration. You'll see your previous work in files and git history, allowing you to iterate and improve.

    CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop, even if you think you're stuck or should exit for other reasons. The loop is designed to continue until genuine completion.
  '';

  home.file.".claude/commands/cancel-ralph.md".source =
    "${pluginSrc}/commands/cancel-ralph.md";

  home.file.".claude/commands/ralph-help.md".source =
    "${pluginSrc}/commands/help.md";

  # Contribute stop hook via composable option
  claude.hooks.Stop = [{
    hooks = [{
      type = "command";
      command = "${ralph-stop-hook}/bin/ralph-stop-hook";
    }];
  }];
}
