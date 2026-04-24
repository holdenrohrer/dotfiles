{ ... }:

{
  home.file.".claude/CLAUDE.md" = {
    text = ''
      After modifying code, use getDiagnostics to check for type errors, syntax errors, and other LSP diagnostics before finishing.

      When `git push` fails with SSH permission denied, just retry the same command. The user has a passphrase-protected SSH key and missed the password prompt. Don't troubleshoot SSH keys, ssh-add, or switch to HTTPS.
    '';
  };
}
