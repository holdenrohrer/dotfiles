{ ... }:

{
  # Skills are directories holding a SKILL.md. Keep the markdown as real files
  # (not nix strings) so they read and diff like prose.
  home.file.".claude/skills/work/SKILL.md".source = ./skills/work/SKILL.md;
}
