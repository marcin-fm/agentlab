# rust-html-to-markdown-rs3

## Finalization status

The package is enabled for the Fedora 43, Fedora 44, and Rawhide x86_64/aarch64 matrix as an independently selected Kreuzberg dependency.

The package uses the exact crates.io `3.8.3` release, installs the MIT text from the exact release commit, and builds upstream's default `metadata` feature plus the dependency-free `testkit` feature required by the published integration tests. Fedora carries a narrow regex minimum adjustment and omits only the 11 tests whose repository-level fixture corpora are absent from the published crate; all other published tests remain enabled.
