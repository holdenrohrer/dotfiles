# Imported via flake input `claude-code-dbus`.
# This file just re-exports the home-manager module from the flake.
# The actual logic lives in github:czar/claude-code-dbus.
{ inputs, ... }:

{
  imports = [ inputs.claude-code-dbus.homeManagerModules.default ];
}
