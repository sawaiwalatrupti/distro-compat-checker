# tests/compat/Makefile

SCRIPT  := check_compat.sh
OUTFILE := /tmp/compat_report.txt

.PHONY: run run-all lint clean

run:
	bash $(SCRIPT)

run-all:
	bash $(SCRIPT) --all -o $(OUTFILE)
	@echo "Report written to $(OUTFILE)"

lint:
	shellcheck $(SCRIPT) lib/checks.sh lib/default_suite.sh

clean:
	rm -f $(OUTFILE)
