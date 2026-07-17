# python-overrides

Fedora source package for the reusable `overrides 7.7.0` Python distribution
used by Serena.

The package builds only from the immutable PyPI sdist and verifies its SHA-256
before `%prep`. The upstream package declares no runtime dependency for the
supported Fedora Python versions and includes its Apache-2.0 license.

Fedora 43 and Fedora 44, plus RPM Fusion repositories, were checked for an
existing `python3dist(overrides)` provider before packaging. No duplicate was
found.

Clean Fedora 43 and Fedora 44 Mock builds passed all 67 published tests.
Source and binary RPM artifacts passed `rpmlint` with zero errors and zero
warnings. The package is enabled for the complete configured COPR target
matrix.
