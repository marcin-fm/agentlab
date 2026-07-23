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
			dnf -y install ruby ruby-default-gems rubygem-json nodejs22-npm tar unzip zstd; \
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
