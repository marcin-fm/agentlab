# rust-imageproc0.27

## Publication status

The package is independently enabled for Fedora 43, Fedora 44, and Rawhide on
`x86_64` and `aarch64`. Its blocked Kreuzberg parent is dependency context, not
a package-local publication hold.

The published crate excludes upstream tests and examples. Fedora omits the one
property-test module that references the excluded DejaVuSans fixture rather than
redistributing the font as a supplemental source; all other native tests remain
selected. Live build and artifact results are retained in the project playbook.
