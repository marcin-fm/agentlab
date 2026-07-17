.PHONY: srpm

srpm:
	test -n "$(spec)"
	test -n "$(outdir)"
	spectool -g -C "$$(dirname "$(spec)")" "$(spec)"
	rpmbuild -bs \
		--define "_sourcedir $$(dirname "$(spec)")" \
		--define "_srcrpmdir $(outdir)" \
		"$(spec)"
