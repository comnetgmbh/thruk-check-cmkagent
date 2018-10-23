#!/usr/bin/make

split: windows10
	mkdir $@
	cat windows10 | perl -e 'my $$fh; while (<>) { open($$fh, ">", "split/$$1") if /^<<<([^:>]+).*>>>$$/; print($$fh $$_); }'
.PHONY: split
