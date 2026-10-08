# Defaults for this project. Command-line assignments override these values.
TEST ?= counter
PART ?=
TOP ?= counter
JOBS ?= 2
VIVADO_VERSION ?= 2026.1

# Tool locations and additional arguments can be overridden by any environment.
VERILATOR ?= verilator
VIVADO ?= vivado
GTKWAVE ?= gtkwave
VERILATOR_FLAGS ?= --timing --assert
RUN_ARGS ?=
export CXX CXXFLAGS

.DEFAULT_GOAL := help
TESTS := $(sort $(basename $(notdir $(wildcard sim/tests/*.mk))))
TEST_CONFIG := sim/tests/$(TEST).mk
-include $(TEST_CONFIG)
SIM_FLAGS ?= -Irtl
SIM_LAYOUT ?=
# Include common headers in dependency checks. Add external headers in the test definition.
SIM_HEADERS ?= $(shell find rtl tb -type f \( -name '*.svh' -o -name '*.vh' \))
SIM_DIR := $(CURDIR)/build/sim/$(TEST)
SIM_BINARY := $(SIM_DIR)/obj/V$(SIM_TOP)
SIM_CONFIG := $(SIM_DIR)/compile.config
WAVEFORM := $(SIM_DIR)/dump.vcd

.PHONY: help list-tests check-test check-jobs build lint sim view simview test check
.PHONY: check-vivado ip synth impl bitstream gui clean info FORCE

help:
	@printf '%s\n' 'Edit TEST and PART at the top of Makefile.' \
	  'make build|lint|sim|view|simview [TEST=name] [RUN_ARGS="+arg=value"]' \
	  'make list-tests|test|check' \
	  'make ip|synth|impl|bitstream|gui [PART=exact-part] [TOP=module] [JOBS=2]' \
	  'make info [TEST=name]    Print the resolved project settings.' \
	  'make clean               Remove generated build outputs.'

list-tests:
	@printf '%s\n' $(TESTS)

check-test:
	@case '$(TEST)' in ''|*[!A-Za-z0-9_-]*) echo 'Invalid TEST name.' >&2; exit 1;; esac
	@test -f '$(TEST_CONFIG)' || { echo 'Unknown TEST=$(TEST). Run make list-tests.' >&2; exit 1; }
	@test -n '$(SIM_TOP)' && test -n '$(SIM_SOURCES)' || { echo 'Define SIM_TOP and SIM_SOURCES in $(TEST_CONFIG).' >&2; exit 1; }

check-jobs:
	@case '$(JOBS)' in ''|*[!0-9]*|0) echo 'JOBS must be a positive integer.' >&2; exit 1;; esac

# Compare configuration contents instead of touching the stamp on every build.
$(SIM_CONFIG): FORCE | check-test check-jobs
	@mkdir -p '$(SIM_DIR)'
	@set -e; { printf '%s\n' '$(VERILATOR)' '--binary --trace' '$(VERILATOR_FLAGS) $(SIM_FLAGS)' '$(SIM_TOP)' \
	  '$(SIM_SOURCES)' '$(SIM_HEADERS)' '$(CXX)' '$(CXXFLAGS)'; \
	  '$(VERILATOR)' --version; $(CXX) --version; } > '$@.tmp'
	@if cmp -s '$@.tmp' '$@'; then rm '$@.tmp'; else mv '$@.tmp' '$@'; fi

$(SIM_BINARY): $(SIM_SOURCES) $(SIM_HEADERS) $(SIM_CONFIG)
	@mkdir -p '$(SIM_DIR)/obj'
	'$(VERILATOR)' --binary --trace --build-jobs '$(JOBS)' \
	  --Mdir '$(SIM_DIR)/obj' --top-module '$(SIM_TOP)' \
	  $(VERILATOR_FLAGS) $(SIM_FLAGS) $(SIM_SOURCES)
	@touch '$@'

build: check-test check-jobs $(SIM_BINARY)
	@printf '%s\n' 'Simulator: $(SIM_BINARY)'

lint: check-test
	'$(VERILATOR)' --lint-only --top-module '$(SIM_TOP)' \
	  $(VERILATOR_FLAGS) $(SIM_FLAGS) $(SIM_SOURCES)

# Clear the trace before compilation too, so a failed build cannot show an old run.
sim: check-test
	@mkdir -p '$(SIM_DIR)'
	@rm -f '$(WAVEFORM)'
	+$(MAKE) --no-print-directory build TEST='$(TEST)'
	@sh sim/run.sh '$(SIM_DIR)' '$(SIM_BINARY)' $(RUN_ARGS)

view: check-test
	@test -f '$(WAVEFORM)' || { echo 'No waveform. Run make sim TEST=$(TEST).' >&2; exit 1; }
	@sh sim/view.sh '$(GTKWAVE)' '$(WAVEFORM)' '$(SIM_LAYOUT)'

simview:
	+$(MAKE) --no-print-directory sim TEST='$(TEST)'
	+$(MAKE) --no-print-directory view TEST='$(TEST)'

test:
	@set -e; for name in $(TESTS); do $(MAKE) --no-print-directory sim TEST="$$name"; done

check:
	@set -e; for name in $(TESTS); do \
	  $(MAKE) --no-print-directory lint sim TEST="$$name"; done

check-vivado: check-jobs
	@case '$(PART)' in ''|*[!A-Za-z0-9_-]*) echo 'Set PART to your exact FPGA device at the top of Makefile.' >&2; exit 1;; esac
	@case '$(TOP)' in ''|*[!A-Za-z0-9_]*) echo 'Set TOP to the synthesis module.' >&2; exit 1;; esac

ip synth impl bitstream: check-vivado
	@mkdir -p build/vivado
	cd build/vivado && '$(VIVADO)' -mode batch -source ../../fpga/build.tcl \
	  -tclargs '$@' '$(PART)' '$(JOBS)' '$(TOP)' '$(VIVADO_VERSION)'

gui: check-vivado
	@mkdir -p build/vivado
	cd build/vivado && '$(VIVADO)' -mode gui -source ../../fpga/gui.tcl \
	  -tclargs '$(PART)' '$(JOBS)' '$(TOP)' '$(VIVADO_VERSION)'

# Plain key=value output also lets external tools use Make's resolved defaults.
info: check-test check-jobs
	@printf '%s\n' 'format=make-v1' 'test=$(TEST)' 'tests=$(TESTS)' \
	  'top=$(TOP)' 'part=$(PART)' 'jobs=$(JOBS)' 'vivado_version=$(VIVADO_VERSION)' \
	  'waveform=build/sim/$(TEST)/dump.vcd' 'wave_layout=$(SIM_LAYOUT)'

clean:
	rm -rf build

FORCE:
