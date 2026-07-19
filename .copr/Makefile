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
					curl --fail --location --retry 3 --output "$$specdir/$$filename" "$$url"; \
					;; \
			esac; \
		done
	case "$$(basename "$(spec)")" in \
		bun.spec) \
			command -v ruby >/dev/null 2>&1 || dnf -y install ruby ruby-bundled-gems; \
			install -pm0755 "$(repo_root)/scripts/audit-bun-source-licenses" "$$(dirname "$(spec)")/audit-bun-source-licenses"; \
			ruby "$(repo_root)/scripts/prepare-bun-srpm-sources" --spec "$(spec)"; \
			;; \
		lol-html.spec) \
			ruby-mri -rjson -roptparse -ruri -rtempfile -rtmpdir -ropen3 -rdigest -rfileutils -e '' >/dev/null 2>&1 || dnf -y install ruby ruby-default-gems rubygem-json; \
			command -v cargo >/dev/null 2>&1 || dnf -y install cargo; \
			install -d -m0755 /srv/tmp; \
			install -pm0755 "$(repo_root)/scripts/prepare-lol-html-srpm-sources" "$$(dirname "$(spec)")/prepare-lol-html-srpm-sources"; \
			ruby-mri "$(repo_root)/scripts/prepare-lol-html-srpm-sources" --spec "$(spec)"; \
			;; \
	esac
	rpmbuild -bs \
		--define "_sourcedir $$(dirname "$(spec)")" \
		--define "_srcrpmdir $(outdir)" \
		"$(spec)"
