# rubygem-ferrum

Ferrum is the Ruby Chrome DevTools Protocol client used by `cxt web`.
Fedora 43 and Fedora 44 provide its complete runtime dependency graph and the
`chromium-headless` browser used by cx, but do not provide Ferrum itself.

The package uses the published `0.17.2` RubyGem as source. Ferrum is pure Ruby,
so the resulting package is `noarch`. `%check` launches Fedora's headless
Chromium against a local `data:` URL and verifies DOM access without network
access.

Clean Fedora 43 and Fedora 44 mock builds passed with the local Chromium CDP
smoke test. The generated runtime requirements resolve to Fedora packages, the
payload and MIT license were verified, and final `rpmlint` reported zero errors
or warnings. The package is enabled for the complete configured COPR target
matrix. No produced RPM was installed on the host.
