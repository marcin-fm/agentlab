# rust-tokenizers0.22

This Rawhide-only compatibility package provides released crate
`tokenizers 0.22.2`, the version selected by Headroom `0.33.0`. Fedora 43 and
Fedora 44 already provide `0.22.2`; Rawhide has advanced to `0.23.1`, which is
outside Headroom's `< 0.23` requirement.

The 0.22.2 crates.io archive has SHA-256
`b238e22d44a15349529690fb07bd645cf58149a1b1e44d6cb5bd1641ff1a6223`
and declares Apache-2.0. The package is adapted from Fedora's
`rust-tokenizers 0.22.2-5` spec. Its Fedora-specific metadata patch widens only
compatible dependency branches, selects Fedora's onig branch, and removes the
benchmark-only Criterion dependency; it applies to the released source with
zero fuzz.

The package retains Fedora's complete feature-subpackage surface. Headroom's
default edge selects `progressbar`, `onig`, and `esaxx_fast`; the remaining
features preserve the reviewed Fedora compatibility baseline. Configured-SCM
publication is intentionally limited to Rawhide x86_64 and aarch64.
