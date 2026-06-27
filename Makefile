.PHONY: default format lint gen_vimdoc gen_readme docs tests tests_selected tests_recent

.SILENT:

NVIM := nvim --headless --noplugin -l

default: format lint tests docs

format:
	stylua --glob '*.lua' .

lint:
	selene --config selene/config.toml lua tests

GEN_TARGETS := gen_vimdoc gen_readme

$(GEN_TARGETS): gen_%:
	$(NVIM) bin/gen_$*.lua

docs: gen_vimdoc gen_readme

tests:
	@mkdir -p tmp
	@: > tmp/tests_state
	$(NVIM) bin/run_tests.lua

tests_selected:
	selected=$$($(NVIM) bin/run_tests.lua --list 2>&1 | fzf --multi); \
	if [ -n "$$selected" ]; then \
		printf '%s' "$$selected" > tmp/tests_state; \
		FYLER_NVIM_TEST_SELECTED="$$selected" $(NVIM) bin/run_tests.lua; \
	fi

tests_recent:
	@[ -f tmp/tests_state ] || { echo "No test state found. Run 'make tests' or 'make tests_selected' first."; exit 1; }
	filter=$$(cat tmp/tests_state); \
	if [ -z "$$filter" ]; then \
		$(NVIM) bin/run_tests.lua; \
	else \
		FYLER_NVIM_TEST_SELECTED="$$filter" $(NVIM) bin/run_tests.lua; \
	fi
