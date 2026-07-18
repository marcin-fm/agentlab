# rust-simba0.10

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256 and includes
the declared Apache-2.0 license file.

No exact `simba 0.10.0` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. Fedora supplies `approx 0.5`, `num-complex
0.4`, and `num-traits 0.2`; Agentlab supplies `wide 1` in all six selected
chroots. The Fedora-only patch retains the stable default/`std` surface required
by `nalgebra` and omits unselected optional branches.
