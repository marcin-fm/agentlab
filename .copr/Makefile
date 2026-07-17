.PHONY: srpm

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
	rpmbuild -bs \
		--define "_sourcedir $$(dirname "$(spec)")" \
		--define "_srcrpmdir $(outdir)" \
		"$(spec)"
