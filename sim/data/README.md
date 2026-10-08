# Simulation inputs

Keep runtime memory images and test data here. Each simulator runs from `build/sim/TEST`. Pass an absolute input path through `RUN_ARGS`, for example `make sim RUN_ARGS="+image=$PWD/sim/data/program.hex"`. Your testbench must read that plusarg with `$value$plusargs` before loading the file.
