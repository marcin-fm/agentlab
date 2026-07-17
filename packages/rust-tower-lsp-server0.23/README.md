# rust-tower-lsp-server0.23

Compatibility package for the published `tower-lsp-server 0.23.0` crate
required by ast-grep. Release `0.2` omits only the explicit WebSocket example
target and its `async-tungstenite` development dependency, pins the `ls-types
0.0.6` API required by ast-grep, and makes the retained examples' Tokio and LSP
requirements explicit. Clean Fedora 43 and Fedora 44 x86_64 mock builds pass 39
unit tests and 3 doctests; downstream ast-grep builds pass their full test suites
and CLI smokes without selecting the WebSocket dependency chain. Generated with
rust2rpm 28, and the package is enabled.
