# rust-dbase0.8

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
MIT license file.

No exact `dbase 0.8.0` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. Its default library requires `bufrw 0.2`,
`byteorder 1`, and `time 0.3`; Fedora provides the latter two, and Agentlab
publishes the exact `bufrw` provider. Publication is serialized after
`rust-bufrw0.2` succeeds in all six configured chroots.
