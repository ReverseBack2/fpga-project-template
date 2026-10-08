# Waveform layouts

Save GTKWave signal selections as `sim/waves/TEST.gtkw` and set `SIM_LAYOUT` in the test definition. `make view` and `make simview` load that layout when it exists. Layouts are committed; traces remain in `build/sim/TEST` and are ignored.
