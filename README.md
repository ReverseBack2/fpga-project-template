# FPGA project template

A local, editor-independent starter for Verilator simulation, GTKWave viewing, and scripted Vivado builds. Use GitHub's **Use this template** button, clone your new repository, and run `make help`.

The template uses GNU Make, POSIX shell, and Vivado Tcl. It adds no Python runner, virtual environment, server configuration, or IDE dependency. Install Verilator and its package dependencies, a C++ compiler, and Make. Install GTKWave for waveform viewing. Vivado is needed only for the FPGA targets.

## Run and select tests

Edit the defaults at the top of `Makefile`:

```make
TEST ?= counter
PART ?=
TOP ?= counter
JOBS ?= 2
VIVADO_VERSION ?= 2026.1
```

`TEST` chooses the default simulation. Set `PART` once to your board's exact FPGA device. Leave it blank until you have selected a device. Simulation does not require a part or Vivado.

```sh
make list-tests
make lint
make build
make sim
make view
make simview
make simview TEST=reset
make test                     # Run every registered test
make check                    # Lint and run every test
make clean                    # Remove build outputs
```

`counter` checks reset, counting, overflow, and another reset. `reset` checks held reset and restarting after reset. Both testbenches stop with a nonzero status on failure and have a timeout.

Each test has its own simulator, `sim.log`, and `dump.vcd` under `build/sim/TEST/`. An unchanged build reuses its simulator. Source, common header, compiler, tool-version, and compilation-argument changes invalidate the cache. Runtime arguments and memory images do not require recompilation. A simulation clears its previous waveform before compilation so a failed build cannot leave an old trace available.

The simulation prints its log after it finishes. `simview` opens GTKWave after a successful simulation. To inspect a partial trace from a failed simulation, use `make view`.

## Add a module or full-design test

Create `sim/tests/NAME.mk`:

```make
SIM_TOP := tb_NAME
SIM_SOURCES := rtl/package.sv rtl/your_module.sv tb/tb_NAME.sv
SIM_FLAGS := -Irtl
SIM_LAYOUT := sim/waves/NAME.gtkw
```

List packages before sources that import them. The testbench top can instantiate one module or the complete design. Tests appear automatically in `make list-tests` and `make test`.

RTL can have any number of subdirectories. List the complete repository-relative paths, such as `rtl/cpu/execute/alu.sv`, in `SIM_SOURCES` and `fpga/rtl.f`. Files are compiled in the listed order, so packages can precede their users. The tools do not automatically compile every source in the RTL tree. Each test can select the modules it needs.

The default include directory is `rtl/` in both simulation and Vivado. A source at any depth can include `rtl/common/types.svh` with `` `include "common/types.svh" ``. Add other simulation include directories in `SIM_FLAGS` and matching synthesis include directories in `fpga/create_project.tcl` when needed.

Common headers under `rtl/` and `tb/` are dependencies. If you use headers elsewhere, include them in `SIM_HEADERS` in the test definition. List any source-list files used through additional flags there too. Explicit source ordering avoids compiling unrelated testbench tops.

Write the trace to `dump.vcd` in the testbench. The simulator runs from `build/sim/NAME`. Pass runtime data using absolute paths and testbench plusargs:

```sh
make sim TEST=NAME RUN_ARGS="+image=$PWD/sim/data/program.hex"
```

The testbench must read the plusarg using `$value$plusargs`. Save GTKWave signal selections to the test's `SIM_LAYOUT` path. Layouts are committed; generated traces are ignored.

## Build an FPGA design

Set `PART` and `TOP` at the top of `Makefile`. List synthesis sources in `fpga/rtl.f`, with one repository-relative path per line. Blank lines and lines beginning with `#` are ignored. Replace the example clock constraint with the actual board clock. Add `fpga/constraints/pins.xdc` with board pins and I/O standards before generating a bitstream.

Load your installed Vivado environment, then run:

```sh
make ip                       # Recreate and generate IP without top-level synthesis
make synth
make impl
make bitstream
make gui
```

All FPGA targets use the same part, top, tool version, constraints, and IP hooks. Command-line values override saved defaults for one run:

```sh
make synth PART=xc7a35tcpg236-1 TOP=counter JOBS=2
```

The starter defaults to Vivado 2026.1. Set `VIVADO_VERSION` deliberately when migrating a project, and review its IP versions. The installed version must match. Check device and IP license requirements for your selected design.

Outputs go to `build/vivado`. Synthesis produces utilization and timing reports plus a checkpoint. Implementation adds routed timing, DRC, CDC, and utilization reports plus a routed checkpoint. A negative worst setup slack or absence of timed paths fails the implementation target. Review hold timing, unconstrained paths, CDC results, and timing exceptions before using hardware. Bitstream generation requires board constraints and passes Vivado's checks.

## Configure IP and use the GUI

Add IP recreation scripts under `fpga/ip/` and source them in the required order from `fpga/ip/create.tcl`. Source block-design recreation scripts from `fpga/bd/create.tcl`. Both hooks run for batch and GUI builds, with `$root` for repository inputs and `$output` for generated products. Project creation generates registered block designs and adds their HDL wrappers.

Existing `.xci` definitions directly under `fpga/ip/` are loaded automatically. Load definitions in subdirectories explicitly with `read_ip` in the hook. [IP configuration details](fpga/ip/README.md) describe the supported inputs.

Use `make gui` to configure complex IP or pins. Export IP with `write_ip_tcl` and block designs with `write_bd_tcl`. Save constraints under `fpga/constraints/`. Bring referenced initialization files into the repository. Commit these inputs and verify a fresh batch build. The generated project is under `build/vivado/gui`; your repository files own the design.

Vendor IP may require a simulation model that differs from its synthesis implementation. Keep these selections in the test's source list and synthesis source list. Verilator cannot consume IEEE P1735 encrypted RTL. Use a compatible model for local tests and validate integration with the actual IP separately.

## Use another editor or machine

Every operation is available through Make. Configure an editor task to run `make simview`, or pass `TEST=NAME` for a specific test. `make info` prints the resolved defaults and selected waveform paths as plain `key=value` lines for other tools.

On macOS, install Verilator through Homebrew and enable the Xcode command-line tools. On Linux, install your distribution's simulation tools. On Windows, use Make and Verilator inside WSL2. Keep the checkout in the WSL filesystem. Use GTKWave through WSLg, or open the VCD in a Windows viewer.

Tool paths are overridable:

```sh
make sim VERILATOR=/path/to/verilator
make view GTKWAVE=/path/to/gtkwave
make synth VIVADO=/path/to/vivado
```

Use project and source paths without spaces for compatibility with Make and Verilator source lists. Native Windows build orchestration is not tested. Vivado FPGA targets need an operating system supported by your Vivado release.

## Validation and sharing

GitHub Actions verifies the Make workflow on Linux and macOS. It checks test switching, cache reuse and invalidation, independent waveforms, and failure handling. Vivado is not installed on GitHub-hosted runners. Validate FPGA builds with your selected tool version and board.

The template is MIT licensed. Generated binaries, projects, logs, and waveforms stay out of Git. Keep a failure trace only when it helps reproduce a problem, together with its exact inputs and simulator version.
