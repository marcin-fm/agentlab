.PHONY: srpm

repo_root := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

srpm:
	test -n "$(spec)"
	test -n "$(outdir)"
	set -eu; \
		specdir="$$(dirname "$(spec)")"; \
		rpmspec -P "$(spec)" | while IFS= read -r line; do \
			case "$$line" in \
				Source:*) source="$${line#*:}" ;; \
				Source[0-9]*:*) source="$${line#*:}" ;; \
				*) continue ;; \
			esac; \
			set -- $$source; source="$$1"; \
			case "$$source" in \
				http://*|https://*) \
					url="$${source%%#*}"; \
					fragment="$${source#*#}"; \
					if [ "$$fragment" != "$$source" ] && [ "$${fragment#/}" != "$$fragment" ]; then \
						filename="$${fragment#/}"; \
					else \
						filename="$${url##*/}"; \
					fi; \
					test -f "$$specdir/$$filename" || curl --fail --location --retry 3 --output "$$specdir/$$filename" "$$url"; \
					;; \
			esac; \
		done
	case "$$(basename "$(spec)")" in \
		bun.spec) \
			command -v ruby >/dev/null 2>&1 || dnf -y install ruby ruby-bundled-gems; \
			install -pm0755 "$(repo_root)/scripts/audit-bun-source-licenses" "$$(dirname "$(spec)")/audit-bun-source-licenses"; \
			install -pm0755 "$(repo_root)/scripts/audit-bun-final-linked-licenses" "$$(dirname "$(spec)")/audit-bun-final-linked-licenses"; \
			install -pm0755 "$(repo_root)/scripts/audit-bun-npm-code-generation" "$$(dirname "$(spec)")/audit-bun-npm-code-generation"; \
			ruby "$(repo_root)/scripts/prepare-bun-srpm-sources" --spec "$(spec)"; \
			;; \
		pdfium.spec) \
			install -pm0755 "$(repo_root)/scripts/prepare-pdfium-srpm-sources" "$$(dirname "$(spec)")/prepare-pdfium-srpm-sources"; \
			;; \
		codex-cli.spec) \
			command -v ruby >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1 || dnf -y install ruby ruby-default-gems rubygem-json cargo git; \
			install -d -m0755 /srv/tmp; \
			install -pm0755 "$(repo_root)/scripts/audit-codex-cargo-closure" "$$(dirname "$(spec)")/audit-codex-cargo-closure"; \
			install -pm0755 "$(repo_root)/scripts/prepare-codex-cargo-srpm-sources" "$$(dirname "$(spec)")/prepare-codex-cargo-srpm-sources"; \
			install -pm0755 "$(repo_root)/scripts/prepare-codex-cargo-license-sources" "$$(dirname "$(spec)")/prepare-codex-cargo-license-sources"; \
			install -pm0644 "$(repo_root)/scripts/lib/codex_cargo_vendor.rb" "$$(dirname "$(spec)")/codex_cargo_vendor.rb"; \
			ruby "$(repo_root)/scripts/prepare-codex-cargo-srpm-sources" --spec "$(spec)"; \
			ruby "$(repo_root)/scripts/prepare-codex-cargo-license-sources" --spec "$(spec)"; \
			;; \
		python-headroom-ai.spec) \
			set -eu; \
			specdir="$$(dirname "$(spec)")"; \
			command -v ruby >/dev/null 2>&1 && command -v tar >/dev/null 2>&1 || dnf -y install ruby ruby-default-gems rubygem-json tar; \
			install -d -m0755 /srv/tmp; \
			tempdir="$$(mktemp -d /srv/tmp/agentlab-headroom-fixtures.XXXXXX)"; \
			trap 'rm -rf "$$tempdir"' EXIT HUP INT TERM; \
			version="$$(rpmspec -q --srpm --qf '%{VERSION}' "$(spec)")"; \
			commit="$$(ruby -e 'File.foreach(ARGV.fetch(0)) { |line| if (match = line.match(/^%global\s+upstream_source_commit\s+(\S+)/)); puts match[1]; exit; end }; abort("missing upstream_source_commit")' "$(spec)")"; \
			curl --fail --location --retry 3 --output "$$tempdir/headroom-source.tar.gz" "https://codeload.github.com/chopratejas/headroom/tar.gz/$$commit"; \
			ruby "$(repo_root)/scripts/prepare-headroom-fixture-source" --spec "$(spec)" --source "$$tempdir/headroom-source.tar.gz" --output "$$specdir/headroom-$$version-code-compressor-fixtures.tar.gz"; \
			;; \
		agent-browser.spec) \
			set -eu; \
			specdir="$$(dirname "$(spec)")"; \
			dnf -y install cargo cargo-rpm-macros ruby ruby-default-gems rubygem-json tar zstd; \
			install -d -m0755 /srv/tmp; \
			tempdir="$$(mktemp -d /srv/tmp/agentlab-agent-browser-srpm.XXXXXX)"; \
			trap 'rm -rf "$$tempdir"' EXIT HUP INT TERM; \
			version="$$(rpmspec -q --srpm --qf '%{VERSION}' "$(spec)")"; \
			source_file="$$(rpmspec -P "$(spec)" | ruby -e 'matches = ARGF.each_line.filter_map { |line| line[/^Source0:\s+(\S+)/, 1] }; abort("expected exactly one Source0: record, found #{matches.length}") unless matches.one?; puts File.basename(matches.first.split("#", 2).first)')"; \
			install -pm0755 "$(repo_root)/scripts/audit-agent-browser-cargo-closure" "$$specdir/audit-agent-browser-cargo-closure"; \
			ruby "$$specdir/audit-agent-browser-cargo-closure" \
				--source "$$specdir/$$source_file" \
				--workdir "$$tempdir/materialization" \
				--output-dir "$$tempdir/output"; \
			for suffix in cargo-closure.json cargo-vendor-receipt.json license-audit.json cargo-vendor.txt; do \
				cmp "$$tempdir/output/agent-browser-$$version-$$suffix" "$$specdir/agent-browser-$$version-$$suffix"; \
			done; \
			install -pm0644 "$$tempdir/output/agent-browser-$$version-cargo-vendor.tar.zst" "$$specdir/agent-browser-$$version-cargo-vendor.tar.zst"; \
			;; \
		xberg.spec) \
			set -eu; \
			specdir="$$(dirname "$(spec)")"; \
			dnf -y install cargo cargo-rpm-macros curl ruby rubypick ruby-default-gems rubygem-json tar zstd patch; \
			install -d -m0755 /srv/tmp; \
			tempdir="$$(mktemp -d /srv/tmp/agentlab-xberg-srpm.XXXXXX)"; \
			trap 'rm -rf "$$tempdir"' EXIT HUP INT TERM; \
			version="$$(rpmspec -q --srpm --qf '%{VERSION}' "$(spec)")"; \
			source_file="$$(rpmspec -P "$(spec)" | ruby -e 'matches = ARGF.each_line.filter_map { |line| line[/^Source0:\s+(\S+)/, 1] }; abort("expected exactly one Source0: record, found #{matches.length}") unless matches.one?; puts File.basename(matches.first.split("#", 2).first)')"; \
			lock_file="xberg-$$version-fedora-Cargo.lock"; \
			install -pm0755 "$(repo_root)/scripts/audit-xberg-cargo-closure" "$$specdir/audit-xberg-cargo-closure"; \
			install -pm0755 "$(repo_root)/scripts/audit-xberg-proof-receipts" "$$specdir/audit-xberg-proof-receipts"; \
			install -pm0755 "$(repo_root)/scripts/write-xberg-cargo-license-receipts" "$$specdir/write-xberg-cargo-license-receipts"; \
			ruby "$$specdir/audit-xberg-cargo-closure" --source "$$specdir/$$source_file" --filter "$$specdir/xberg-$$version-source-filter.json" --closure "$$specdir/xberg-$$version-cargo-closure.json" --lock "$$specdir/$$lock_file" --patch-dir "$$specdir" --workdir "$$tempdir/materialization" --output-dir "$$tempdir/output"; \
			for suffix in cargo-closure.json cargo-vendor-receipt.json license-text-presence.json cargo-vendor.txt; do \
				cmp "$$tempdir/output/xberg-$$version-$$suffix" "$$specdir/xberg-$$version-$$suffix"; \
			done; \
			ruby "$$specdir/audit-xberg-proof-receipts" --prepared-source "$$tempdir/materialization/source/xberg-$$version" --vendor-dir "$$tempdir/materialization/cargo-vendor" --patch-dir "$$specdir" --closure "$$specdir/xberg-$$version-cargo-closure.json" --presence "$$specdir/xberg-$$version-license-text-presence.json" --allowlist "$$specdir/xberg-$$version-fedora-license-allowlist.json" --provider "$$specdir/xberg-$$version-provider-proof.json" --output-dir "$$tempdir/proof-output" --workdir "$$tempdir/proof-work"; \
			for suffix in source-license-receipt.json provider-proof.json; do \
				cmp "$$tempdir/proof-output/xberg-$$version-$$suffix" "$$specdir/xberg-$$version-$$suffix"; \
			done; \
			install -pm0644 "$$tempdir/output/xberg-$$version-cargo-vendor.tar.zst" "$$specdir/xberg-$$version-cargo-vendor.tar.zst"; \
			;; \
		mermaid-cli.spec) \
			set -eu; \
			specdir="$$(dirname "$(spec)")"; \
			dnf -y install ruby ruby-default-gems ruby-bundled-gems rubygem-json nodejs22-npm tar unzip zstd; \
			install -d -m0755 /srv/tmp; \
			version="$$(rpmspec -q --qf '%{VERSION}' "$(spec)")"; \
			tempdir="$$(mktemp -d /srv/tmp/agentlab-mermaid-cli-srpm.XXXXXX)"; \
			trap 'rm -rf "$$tempdir"' EXIT HUP INT TERM; \
			ruby "$(repo_root)/scripts/build-mermaid-cli-closure" \
				--source "$$specdir/$$version.tar.gz" \
				--workdir "$$tempdir/work" \
				--output-dir "$$tempdir/output"; \
			for suffix in node-closure.tar.zst closure.json bundled-licenses.txt native.json third-party-notices.txt closure-receipt.json; do \
				filename="mermaid-cli-$$version-$$suffix"; \
				install -pm0644 "$$tempdir/output/$$filename" "$$specdir/$$filename"; \
				done; \
			;; \
		opencode.spec) \
			set -eu; \
			specdir="$$(dirname "$(spec)")"; \
			dnf -y install cargo ruby ruby-default-gems rubygem-json tar zstd; \
			install -d -m0755 /srv/tmp; \
			version="$$(rpmspec -q --srpm --qf '%{VERSION}' "$(spec)")"; \
			tempdir="$$(mktemp -d /srv/tmp/agentlab-opencode-srpm.XXXXXX)"; \
			trap 'rm -rf "$$tempdir"' EXIT HUP INT TERM; \
			ruby "$(repo_root)/scripts/acquire-opencode-sources" \
				--workdir "$$tempdir/acquisition" \
				--output "$$tempdir/source-audit.json" \
				--jobs 4; \
			cmp "$$tempdir/source-audit.json" "$$specdir/opencode-$$version-source-audit.json"; \
			ruby "$(repo_root)/scripts/materialize-opencode-sources" \
				--cache-dir "$$tempdir/acquisition/archives" \
				--output-dir "$$tempdir/output" \
				--receipt "$$tempdir/source-materialization.json" \
				--workdir "$$tempdir/materialization"; \
			cmp "$$tempdir/source-materialization.json" "$$specdir/opencode-$$version-source-materialization.json"; \
			ruby "$(repo_root)/scripts/prepare-opencode-bun-pty-sources" \
				--spec "$(spec)" \
				--workdir "$$tempdir/bun-pty" \
				--output "$$tempdir/output/opencode-$$version-bun-pty-cargo-vendor.tar.zst"; \
			ruby "$(repo_root)/scripts/prepare-opencode-photon-sources" \
				--spec "$(spec)" \
				--workdir "$$tempdir/photon" \
				--output-dir "$$tempdir/output"; \
			ruby "$(repo_root)/scripts/prepare-opencode-closure-evidence" \
				--package-dir "$$specdir" \
				--output-dir "$$tempdir/output"; \
			ruby "$(repo_root)/scripts/audit-opencode-final-licenses" \
				--binary-embedding "$$specdir/opencode-$$version-binary-embedding.json" \
				--source-license-set "$$specdir/source-license-set-proof.json" \
				--license-review "$$specdir/license-review.yml" \
				--native-review "$$specdir/native-review.yml" \
				--bun-final-license "$(repo_root)/packages/bun/bun-1.3.14-final-linked-license-closure.json" \
				--date 2026-07-28 \
				--check \
				--receipt "$$specdir/opencode-$$version-final-license-closure.json"; \
			install -pm0755 "$(repo_root)/scripts/materialize-opencode-node-modules" \
				"$$specdir/materialize-opencode-node-modules"; \
			install -pm0755 "$(repo_root)/scripts/audit-opencode-binary-embedding" \
				"$$specdir/audit-opencode-binary-embedding"; \
			install -pm0755 "$(repo_root)/scripts/audit-opencode-final-licenses" \
				"$$specdir/audit-opencode-final-licenses"; \
			for suffix in closure.json bundled-licenses.txt native.json; do \
				install -pm0644 "$$tempdir/output/opencode-$$version-$$suffix" \
					"$$specdir/opencode-$$version-$$suffix"; \
			done; \
			install -pm0644 "$$tempdir/output/opencode-$$version-nm-prod-build.tar.zst" \
				"$$specdir/opencode-$$version-nm-prod-build.tar.zst"; \
			install -pm0644 "$$tempdir/output/opencode-$$version-nm-dev-test.tar.zst" \
				"$$specdir/opencode-$$version-nm-dev-test.tar.zst"; \
			install -pm0644 "$$tempdir/output/opencode-$$version-bun-pty-cargo-vendor.tar.zst" \
				"$$specdir/opencode-$$version-bun-pty-cargo-vendor.tar.zst"; \
			for suffix in photon-cargo-vendor.tar.zst wasm-bindgen-cli-cargo-vendor.tar.zst; do \
				install -pm0644 "$$tempdir/output/opencode-$$version-$$suffix" \
					"$$specdir/opencode-$$version-$$suffix"; \
			done; \
			;; \
		rust-tree-sitter-language-pack1.spec) \
			set -eu; \
			specdir="$$(dirname "$(spec)")"; \
			dnf -y install python3 tar zstd; \
			install -d -m0755 /srv/tmp; \
			version="$$(rpmspec -q --srpm --qf '%{VERSION}' "$(spec)")"; \
			tempdir="$$(mktemp -d /srv/tmp/agentlab-tree-sitter-language-pack-srpm.XXXXXX)"; \
			trap 'rm -rf "$$tempdir"' EXIT HUP INT TERM; \
			install -d -m0755 "$$tempdir/source" "$$tempdir/evidence" "$$tempdir/output"; \
			install -pm0644 "$$specdir/sources/parser-source-license-evidence-$$version.tar.zst" \
				"$$specdir/parser-source-license-evidence-$$version.tar.zst"; \
			tar --zstd -xf "$$specdir/parser-sources-$$version.tar.zst" -C "$$tempdir/source"; \
			tar --zstd -xf "$$specdir/parser-source-license-evidence-$$version.tar.zst" -C "$$tempdir/evidence"; \
			python3 "$(repo_root)/packages/rust-tree-sitter-language-pack1/prepare_subset.py" \
				--source-root "$$tempdir/source" \
				--evidence-root "$$tempdir/evidence/parser-source-license-evidence" \
				--output-dir "$$tempdir/output" \
				--archive "$$tempdir/parser-sources-$$version-licensed-subset.tar.zst" \
				--verify-tracked-contract; \
			install -pm0644 "$$tempdir/parser-sources-$$version-licensed-subset.tar.zst" \
				"$$specdir/parser-sources-$$version-licensed-subset.tar.zst"; \
			;; \
		rust-v8.spec) \
			ruby-mri -rjson -roptparse -rpathname -rrubygems/package -rtempfile -rtmpdir -rzlib -e '' >/dev/null 2>&1 || dnf -y install ruby ruby-default-gems rubygem-json; \
			install -d -m0755 /srv/tmp; \
			install -pm0755 "$(repo_root)/scripts/audit-rust-v8-consumer-rlibs" "$$(dirname "$(spec)")/audit-rust-v8-consumer-rlibs"; \
			install -pm0755 "$(repo_root)/scripts/prepare-rust-v8-srpm-sources" "$$(dirname "$(spec)")/prepare-rust-v8-srpm-sources"; \
			ruby-mri "$$(dirname "$(spec)")/prepare-rust-v8-srpm-sources" --spec "$(spec)"; \
			;; \
	esac
	rpmbuild -bs \
		--define "_sourcedir $$(dirname "$(spec)")" \
		--define "_srcrpmdir $(outdir)" \
		"$(spec)"
