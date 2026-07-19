# rust-comrak0.54

## Publication status

The package is independently enabled for Fedora 43, Fedora 44, and Rawhide on
`x86_64` and `aarch64`. Its blocked Kreuzberg parent is dependency context, not
a package-local publication hold.

Fedora retains the selected CLI feature but removes the unavailable `bon 3`
dependency and generated builder APIs. The build script records upstream's
dormant `bon` source guards as an expected disabled cfg so the build is clean.
The default feature set is therefore the accepted reduced Fedora interface
rather than the complete upstream default. Live build and artifact results are
retained in the project playbook.
