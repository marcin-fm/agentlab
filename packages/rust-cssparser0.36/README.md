# rust-cssparser0.36

Compatibility package for the released MPL-2.0 `cssparser 0.36.0` crate
required by `selectors 0.37.0` and the selected system-registry build of
`lol-html 3.0.0`.

Fedora 43, Fedora 44, and Rawhide provide the incompatible `cssparser 0.35`
branch. The exact crates.io archive has SHA-256
`dae61cf9c0abb83bd659dab65b7e4e38d8236824c85f0f804f173567bda257d2`.
The selected consumer uses the empty default feature set. Fedora's historical
Rust documentation patch is unnecessary because release 0.36.0 already has the
correct code-block attributes.

A Fedora 44 x86_64 Mock build passes under the four-job cap with the required
Agentlab repository. The retained documentation suite passes two tests and
ignores four examples that are not executable tests. Configured publication
remains blocked only on safe integration with the shared target-applicability
registry and the six-cell COPR matrix.
