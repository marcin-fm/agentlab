# Bun Packaging Status

Bun `1.3.14` is a required OpenCode build dependency but is not enabled for COPR.

The pinned `oven-sh/zig` source is now proven to bootstrap on Fedora 44 from its in-tree stage-one WASM using Fedora LLVM, Clang, and LLD 20. The package compiles that subordinate source privately and materializes the `zig` plus `lib` root expected by Bun; it does not publish a misleading `zig-bun` package or consume an external Zig executable.

The draft spec deliberately stops after this verified stage. The pinned WebKit commit has no submodules, so a deterministic `git archive` contains the complete repository source tree; GitHub codeload returns HTTP 422 for this repository, so the archive still needs to be generated, hosted immutably, and checksummed. The Arch correctness patch, source build, and LGPL relink materials also remain unresolved. The exact Bun `1.3.14` x86_64 seed archive is checked and recorded as bootstrap-only, but it has not yet driven the first build. Complete offline dependency inputs and an immediate offline self-rebuild whose final RPM contains no seed artifact or runtime dependency are still required.

Run the reusable Zig proof outside RPM builds with:

```bash
scripts/prove-bun-zig-bootstrap
```

The proof writes only below `/srv/tmp`, does not install its output, and verifies the Bun-compatible tool layout. It is a source-bootstrap-stage proof, not an offline Bun build, seed-isolation proof, complete RPM build, or Fedora approval. A machine-readable receipt records the checked source, patch, toolchain, and output digest.
