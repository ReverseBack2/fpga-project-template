#!/bin/sh
# Run from the selected test's output directory and keep its exit status and log.
set -u
run_dir=$1
shift
cd "$run_dir" || exit 1
"$@" > sim.log 2>&1
status=$?
cat sim.log
exit "$status"
