# dirs 5 Compatibility Packaging

Fedora 44 ships `dirs` 6, while RTK `0.43.0` is locked to the published `dirs` `5.0.1` release. This compatibility package preserves the upstream RTK dependency graph instead of porting the application to a newer API.

The spec was generated with `rust2rpm 28` and then reviewed and adapted by Marcin FM. Its source and noarch development RPMs pass a clean Fedora 44 mock build using `rust-dirs-sys0.4` from the same package chain. It targets Fedora 44 and Rawhide on both `x86_64` and `aarch64`; Fedora 43 already provides this crate branch and must not receive a duplicate build.
