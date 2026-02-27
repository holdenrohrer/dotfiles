{ config, lib, pkgs, inputs, ... }:

let
  playwright-mcp = pkgs.buildNpmPackage {
    pname = "playwright-mcp";
    version = "0-unstable";

    src = inputs.playwright-mcp-src;

    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    npmDepsHash = "sha256-ekJR38hnohiSrYxHTMmiquuCCS5h/H/T/jCe66mJ6PQ=";
    dontNpmBuild = true;

    # Replace workspace symlinks with actual copies of workspace packages
    preFixup = ''
      local pkg="$out/lib/node_modules/playwright-mcp-internal"
      rm -rf "$pkg/node_modules/@playwright/mcp"
      cp -r "$pkg/packages/playwright-mcp" "$pkg/node_modules/@playwright/mcp"
      rm -rf "$pkg/node_modules/@playwright/mcp-extension"
      cp -r "$pkg/packages/extension" "$pkg/node_modules/@playwright/mcp-extension"
      rm -rf "$pkg/node_modules/playwright-cli"
      cp -r "$pkg/packages/playwright-cli-stub" "$pkg/node_modules/playwright-cli"
    '';

    # The binary is at packages/playwright-mcp/cli.js
    postInstall = ''
      mkdir -p $out/bin
      ln -s "$out/lib/node_modules/playwright-mcp-internal/packages/playwright-mcp/cli.js" \
            "$out/bin/playwright-mcp"
    '';

    meta = {
      description = "Playwright Model Context Protocol server";
      homepage = "https://github.com/microsoft/playwright-mcp";
      license = lib.licenses.asl20;
    };
  };

  playwright-mcp-wrapper = pkgs.writeShellScriptBin "playwright-mcp-wrapper" ''
    export PLAYWRIGHT_FIREFOX_EXECUTABLE_PATH="${lib.getExe pkgs.firefox}"
    exec ${playwright-mcp}/bin/playwright-mcp "$@"
  '';

in
{
  programs.emacs.extraConfig = ''
    (with-eval-after-load 'claude-code-ide
      (add-to-list 'claude-code-ide-on-demand-mcp-servers
        '("playwright"
          . ((type . "stdio")
             (command . "${playwright-mcp-wrapper}/bin/playwright-mcp-wrapper")
             (args . ["--browser" "firefox"])))))
  '';
}
