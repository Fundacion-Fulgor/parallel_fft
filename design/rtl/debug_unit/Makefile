# Simulator defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Source files
VERILOG_SOURCES += $(PWD)/spi_slave_mode0.v
VERILOG_SOURCES += $(PWD)/cdc_snapshot.v
VERILOG_SOURCES += $(PWD)/debug_unit.v
VERILOG_SOURCES += $(PWD)/top_debug_system.v

# Top level module name
TOPLEVEL = top_debug_system

# Python test module name
MODULE = test_debug_system

# Cocotb include
include $(shell cocotb-config --makefiles)/Makefile.sim