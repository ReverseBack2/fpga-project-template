#!/bin/sh
# Exercise the public commands in a disposable copy of the starter.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/fpga-template-check.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir "$work/project"
cp "$root/Makefile" "$work/project/"
cp -R "$root/rtl" "$root/tb" "$root/sim" "$root/fpga" "$work/project/"
cd "$work/project"
# Prove that neither simulation nor synthesis source lists require a flat RTL tree.
mkdir -p rtl/core/counter rtl/include/nested
mv rtl/counter.sv rtl/core/counter/counter.sv
printf '%s\n' '`define COUNTER_WIDTH 8' > rtl/include/nested/width.svh
printf '%s\n' '`include "include/nested/width.svh"' > rtl/include/counter.svh
{ printf '%s\n' '`include "include/counter.svh"'; \
  sed 's/WIDTH = 8/WIDTH = `COUNTER_WIDTH/' rtl/core/counter/counter.sv; } > "$work/source"
mv "$work/source" rtl/core/counter/counter.sv
for definition in sim/tests/*.mk; do
    sed 's#rtl/counter.sv#rtl/core/counter/counter.sv#g' "$definition" > "$work/definition"
    mv "$work/definition" "$definition"
done
printf '%s\n' 'rtl/core/counter/counter.sv' > fpga/rtl.f
run_make() {
    if ! make --no-print-directory "$@" > "$work/output" 2>&1; then
        cat "$work/output"
        exit 1
    fi
}
run_make check
test -s build/sim/counter/dump.vcd
test -s build/sim/reset/dump.vcd
cp -p build/sim/counter/obj/Vtb_counter "$work/compiled"
cp -p build/sim/reset/obj/Vtb_reset "$work/reset-compiled"
run_make sim
test ! build/sim/counter/obj/Vtb_counter -nt "$work/compiled"
printf '%s\n' 'PASS: both tests, independent traces, and cache reuse'
cp -p build/sim/counter/obj/Vtb_counter "$work/compiled"
cp -p rtl/include/nested/width.svh "$work/original-header"
sleep 1
printf '\n// Nested include dependency check\n' >> rtl/include/nested/width.svh
# Prove content changes are detected even when the modification time is unchanged.
touch -r "$work/original-header" rtl/include/nested/width.svh
run_make sim
test build/sim/counter/obj/Vtb_counter -nt "$work/compiled"
run_make sim TEST=reset
cp -p build/sim/counter/obj/Vtb_counter "$work/compiled"
cp -p build/sim/reset/obj/Vtb_reset "$work/reset-compiled"
printf '%s\n' 'PASS: nested RTL and recursive header dependencies'

# Editing saved defaults selects a test without invalidating either compiled design.
cp Makefile "$work/original-Makefile"
sed -e 's/^TEST ?= counter$/TEST ?= reset/' -e 's/^PART ?=$/PART ?= xc7a35tcpg236-1/' Makefile > "$work/new-Makefile"
mv "$work/new-Makefile" Makefile
run_make sim
test ! build/sim/reset/obj/Vtb_reset -nt "$work/reset-compiled"
run_make -s info
grep -q '^test=reset$' "$work/output"
grep -q '^part=xc7a35tcpg236-1$' "$work/output"
cp "$work/original-Makefile" Makefile
printf '%s\n' 'PASS: saved TEST and PART defaults preserve compiled simulators'

# A source edit must rebuild its test without rebuilding the other testbench.
sleep 1
printf '\n// Source dependency check\n' >> tb/tb_counter.sv
run_make sim
test build/sim/counter/obj/Vtb_counter -nt "$work/compiled"
run_make sim TEST=reset
test ! build/sim/reset/obj/Vtb_reset -nt "$work/reset-compiled"
cp -p build/sim/counter/obj/Vtb_counter "$work/compiled"
sleep 1
run_make sim VERILATOR_FLAGS='--timing --assert -DCACHE_CHECK=1'
test build/sim/counter/obj/Vtb_counter -nt "$work/compiled"
printf '%s\n' 'PASS: source and flag changes rebuild only the selected simulator'

# An included header must invalidate the simulator too.
printf '%s\n' '`define HEADER_CHECK 1' > rtl/check.svh
{ printf '%s\n' '`include "check.svh"'; cat tb/tb_counter.sv; } > "$work/bench"
mv "$work/bench" tb/tb_counter.sv
printf '\nSIM_FLAGS := -Irtl\n' >> sim/tests/counter.mk
run_make sim
cp -p build/sim/counter/obj/Vtb_counter "$work/compiled"
sleep 1
printf '%s\n' '`define HEADER_CHECK 2' > rtl/check.svh
run_make sim
test build/sim/counter/obj/Vtb_counter -nt "$work/compiled"
printf '%s\n' 'PASS: included header changes invalidate the cache'

# A failed compilation clears the previous waveform before invoking the compiler.
printf '%s\n' 'this is invalid SystemVerilog' >> tb/tb_counter.sv
if make sim > "$work/output" 2>&1; then
    cat "$work/output"
    echo 'Expected a compilation failure.' >&2
    exit 1
fi
test ! -e build/sim/counter/dump.vcd
test -s build/sim/reset/dump.vcd
if make sim TEST=missing > "$work/output" 2>&1; then exit 1; fi
if make synth > "$work/output" 2>&1; then exit 1; fi
printf '%s\n' 'PASS: failure status, stale trace removal, unknown tests, and unset part'
