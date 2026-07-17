# python-oslex

Fedora source package for `oslex 2.0.0`, an OS-independent wrapper around
POSIX and Windows command-line parsing used by Serena.

The immutable PyPI sdist is MIT-licensed and declares the strict runtime
dependency `mslex>=1.3.0,<2`. Fedora 43 and Fedora 44, and RPM Fusion, were
checked for an existing `mslex` provider before packaging; no duplicate was
found.

Clean Fedora 43 and Fedora 44 Mock builds passed 9 upstream tests with 3
platform skips. Final source and binary RPM artifacts pass `rpmlint` with zero
errors and zero warnings. The package is enabled for both configured chroots.
