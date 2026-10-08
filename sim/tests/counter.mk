SIM_TOP := tb_counter
# Put SystemVerilog packages before modules that import them.
SIM_SOURCES := rtl/counter.sv tb/tb_counter.sv
SIM_LAYOUT := sim/waves/counter.gtkw
