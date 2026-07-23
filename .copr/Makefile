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
		kreuzberg.spec) \
			set -eu; \
			. /etc/os-release; \
			case "$$VERSION_ID" in \
				rawhide) fedora_release=rawhide ;; \
				*) fedora_release="$$VERSION_ID" ;; \
			esac; \
			arch="$$(uname -m)"; \
			install -d -m0755 /etc/yum.repos.d; \
			printf '%s\n' \
				'[agentlab-copr]' \
				'name=Agentlab COPR source-builder dependencies' \
				"baseurl=https://download.copr.fedorainfracloud.org/results/marcin/agentlab/fedora-$$fedora_release-$$arch/" \
				'enabled=1' \
				'gpgcheck=0' \
				'repo_gpgcheck=0' \
				'skip_if_unavailable=0' \
				> /etc/yum.repos.d/agentlab-copr.repo; \
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
			install -pm0755 "$(repo_root)/scripts/prepare-rust-v8-srpm-sources" "$$(dirname "$(spec)")/prepare-rust-v8-srpm-sources"; \
			ruby-mri "$$(dirname "$(spec)")/prepare-rust-v8-srpm-sources" --spec "$(spec)"; \
			;; \
	esac
	rpmbuild -bs \
		--define "_sourcedir $$(dirname "$(spec)")" \
		--define "_srcrpmdir $(outdir)" \
		"$(spec)"
