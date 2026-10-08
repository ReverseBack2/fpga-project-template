# IP definitions

Store reviewed IP recreation Tcl here and source it from `create.tcl` in the required order. Project creation calls this hook for both batch and GUI builds. The hook can use `$root` for repository inputs and `$output` for generated products.

You can also put existing XCI definitions directly in this directory. Project creation loads them before the hook. For an XCI in a subdirectory, call `read_ip` explicitly from the hook.

Keep each IP's version fixed in its creation script. Write generated products under `$output`, not into this source directory. `make ip` recreates the project and generates output products without running top-level synthesis. `make synth` and later targets do this automatically.

After configuring IP in the GUI, use `write_ip_tcl` to export its recreation script. Export block designs with `write_bd_tcl` and source their scripts from `../bd/create.tcl`. Keep referenced memory initialization and other input files in the repository, using paths relative to `$root`. Verify recreation with a fresh batch build.
