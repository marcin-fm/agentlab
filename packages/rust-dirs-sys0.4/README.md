# dirs-sys 0.4 Compatibility Packaging

Fedora 44 ships `dirs-sys` 0.5, while RTK `0.43.0` is locked to the published `dirs-sys` `0.4.1` release. This compatibility package follows Fedora Rust packaging conventions and removes only target dependencies that cannot apply to Fedora Linux.

The spec was generated with `rust2rpm 28` and then reviewed and adapted by Marcin FM. Its source and noarch development RPMs pass a clean Fedora 44 mock build. It is enabled only for `fedora-44-x86_64`; Fedora 43 already provides this crate branch and must not receive a duplicate build.
