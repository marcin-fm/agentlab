# rust-hayro-jpeg2000

This Fedora-derived crate package exists only for Kreuzberg's Fedora 43 target,
where the distribution does not provide `hayro-jpeg2000 0.3`. Fedora 44 and
Rawhide already provide a compatible branch and are intentionally omitted.

Release `1.1` preserves Fedora's `0.3.5-1` base release and metadata patch from
commit `34ef88922dc4d3218fe3c9caebcb33282ccfaf5a`. The patch accounts for the
CC0-licensed assets and removes only an unused development dependency. The
canonical crates.io archive is pinned by SHA-256 and target builds remain
offline.
