# FPGA project template

Start a project with local Verilator simulation, local GTKWave viewing, and scripted Vivado builds. The example is an 8-bit counter with a self-checking SystemVerilog testbench. No FPGA board is required to simulate.

Use GitHub's **Use this template** button. Clone your new repository locally and open `project.sublime-project` in Sublime Text.

## Run the example

Install Python 3.9 or newer, Verilator 5.020 or newer, Make, and a C++ compiler. For the optional workbench client, use Python 3.12 or newer.

```sh
make lint
make sim
make simview  # Requires gtkwave on PATH
```

The waveform is `build/sim/dump.vcd`. An unchanged design reuses its compiled simulator. The simulation checks reset, counting, overflow, and another reset. A failed assertion exits with an error. Save GTKWave's signal selection as `sim/waves/counter.gtkw` to keep it with your project. Runtime data belongs in `sim/data`; the simulator runs from `build/sim`.

On macOS, install Verilator through Homebrew and enable the Xcode command-line tools. Configure your existing GTKWave application through the optional workbench client if it is not on PATH. On Windows, run simulation inside Ubuntu 24.04 on WSL2 and use GTKWave through WSLg. Keep the checkout in the WSL filesystem and open it in native Sublime through `\\wsl.localhost\Ubuntu\home\YOUR_USER\projects\YOUR_PROJECT`.

## Adapt the project

| Path | Purpose |
| --- | --- |
| `rtl/` | Synthesizable RTL |
| `tb/` | Self-checking simulation testbenches |
| `sim/files.f` | Simulation source list |
| `sim/run.py` | Simulation top, compiler arguments, and cache |
| `fpga/rtl.f` | Synthesis source list |
| `fpga/create_project.tcl` | Top module, constraints, and IP inputs |
| `fpga/build.tcl` | Synthesis, implementation, reports, and bitstream |
| `project.toml` | Project commands, input snapshot list, tool version, part |

When changing the top module, update both the testbench top in `sim/run.py` and the synthesis top in `fpga/create_project.tcl`. Update both file lists for new source files. Add external dependencies as regular files inside the checkout, and list their directories in `remote.inputs`. Symlink inputs are rejected by the workbench.

Set `vivado.part` to your exact FPGA part. Replace the example clock constraint with your actual clock. Add `fpga/constraints/pins.xdc` with board-specific package pins and I/O standards before generating a bitstream. The supplied counter exposes signals directly; adapt its ports or add a board wrapper to match your board.

## Build with Vivado

This starter pins Vivado **2026.1**. Install it separately and obtain a free Basic license. Device support and licensed IP must match the part and IP you choose. AMD's [licensing page](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado/vivado-licensing-options.html) describes renewal and tier limits. [2026.1 downloads](https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/development-tools/2026-1.html) note that Basic excludes minor releases such as 2026.1.1.

From the checkout root, with Vivado's environment loaded:

```sh
vivado -mode batch -source fpga/build.tcl -tclargs synth YOUR_EXACT_PART 2
vivado -mode batch -source fpga/build.tcl -tclargs impl YOUR_EXACT_PART 2
vivado -mode batch -source fpga/build.tcl -tclargs bitstream YOUR_EXACT_PART 2
```

Outputs go to `build/vivado`. Implementation reports utilization, timing, DRC, and CDC. The script fails when the worst reported setup path has negative slack or no timed paths exist. This is a starting check, not full timing signoff: review hold timing, unconstrained paths, CDC results, and exceptions before using hardware. Bitstream generation also runs Vivado's checks.

The optional private workbench client provides `fpga sim --view`, `fpga synth --wait`, `fpga status`, `fpga logs`, and `fpga fetch`. Simulation and the Tcl scripts work without that client.

## Use the GUI for constraints and IP

```sh
vivado -mode gui -source fpga/gui.tcl -tclargs YOUR_EXACT_PART 2
```

This recreates the project in `build/vivado/gui`. Save constraints into `fpga/constraints`, not only inside the generated project. Put reusable `.xci` files in `fpga/ip`. Export block designs with `write_bd_tcl` and explicitly source their recreation script from `create_project.tcl`; block designs are not discovered automatically. Commit the inputs and prove that a fresh batch build works. Never treat the generated `.xpr` as the only copy of your design.

## Validation and sharing

GitHub Actions runs lint, simulation, and a second simulation to check cache reuse. Proprietary Vivado is not run on GitHub-hosted CI. Vivado commands need validation on your installed version and selected board.

The template is MIT licensed. Change `.github/CODEOWNERS` after generating a repository for another owner. CODEOWNERS requests review; repository access settings control who can push. Ignore generated builds and VCD files in Git. Keep a trace only when it helps reproduce a failure, alongside the exact inputs and simulator version.
