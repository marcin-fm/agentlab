# python-mslex

Fedora source package for `mslex 1.3.0`, the Apache-2.0 Windows command-line
quoting library required by `oslex 2.0.0`.

The package builds only from the immutable PyPI sdist and verifies its SHA-256
before `%prep`. The upstream release has no runtime dependencies and includes
its license. Fedora 43 and Fedora 44, plus RPM Fusion repositories, were
checked for an existing provider before packaging; no duplicate was found.

Clean Fedora 43 and Fedora 44 Mock builds passed 13 upstream tests with 4
platform skips. Final source and binary RPM artifacts pass `rpmlint` with zero
errors and one expected no-manual-page warning for `mslex-split` per chroot.
The package is enabled for both configured chroots.
