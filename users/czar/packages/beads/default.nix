{ lib, rustPlatform, fetchFromGitHub }:

# beads (`br`) — Jeffrey Emanuel's Rust port of Steve Yegge's beads:
# a local-first, dependency-aware issue tracker for agents, SQLite-backed
# with JSONL export for git collaboration.
#
# Upstream pins a nightly toolchain in rust-toolchain.toml. The crate itself
# gates no features, but its `fsqlite-pager` dependency uses
# `feature(core_intrinsics)`, so we let a stable rustc accept feature gates
# via RUSTC_BOOTSTRAP rather than dragging in a whole nightly toolchain.
# Needs a recent rustc: `vergen` 10 demands >= 1.96.
rustPlatform.buildRustPackage rec {
  pname = "beads";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "beads_rust";
    tag = "v${version}";
    hash = "sha256-dTYOCTji4sz1HlVayT08UhXRuA7Vg8bkCtc6Az9xrxY=";
  };

  cargoHash = "sha256-1qYfXWZwVNGLWAPUn2YSpyhUKzJP0HNf3oIjs07Cf3I=";

  env.RUSTC_BOOTSTRAP = 1;

  # Upstream's test suite spins up daemons and git repos; skip it.
  doCheck = false;

  meta = {
    description = "Agent-first, dependency-aware issue tracker (SQLite + JSONL)";
    homepage = "https://github.com/Dicklesworthstone/beads_rust";
    mainProgram = "br";
    platforms = lib.platforms.unix;
  };
}
