GHDL=ghdl
GHDL_FLAGS=--std=08
GHDL_OPTIMIZE := -O3
GHDL_OPT := -frelaxed-rules --warn-no-vital-generic -frelaxed $(GHDL_OPTIMIZE)
GHDL_ELAB_OPTS := --mb-comments 
GHDL_WARNS := -Wbinding -Wreserved -Wlibrary -Wvital-generic -Wdelayed-checks -Wbody -Wspecs -Wunused --warn-no-runtime-error
MODULES_V1=\
	src_rtl/v1/NIST_LWAPI_pkg.o\
	src_rtl/v1/design_pkg.o\
	src_rtl/LWC/fwft_fifo.o\
	src_rtl/LWC/StepDownCountLd.o\
	src_rtl/LWC/data_piso.o\
	src_rtl/LWC/data_sipo.o\
	src_rtl/LWC/key_piso.o\
	src_rtl/v1/CryptoCore.o\
	src_rtl/LWC/PostProcessor.o\
	src_rtl/LWC/PreProcessor.o\
	src_rtl/LWC/LWC.o\
    src_tb/v1/LWC_TB_compatibility_pkg.o\
	src_tb/v1/LWC_TB

v1: $(MODULES_V1)
	$(info More v1 testbench output can be found in log.txt or failed_testvectors.txt)

# Binary depends on the object file
%: %.o
	$(GHDL) -e $(GHDL_FLAGS) $(GHDL_OPT) $(GHDL_WARNS) $(GHDL_ELAB_OPTS) LWC_TB
	$(GHDL) -r $(GHDL_FLAGS) $(GHDL_OPT) $(GHDL_WARNS) $(GHDL_ELAB_OPTS) LWC_TB

# Object file depends on source
%.o: %.vhd
	$(GHDL) -a $(GHDL_FLAGS) $(GHDL_OPT) $(GHDL_WARNS) $(GHDL_ELAB_OPTS) $<

.PHONY: clean
clean:
	$(info Cleaning up...)
	rm -f *.o *_TB work*.cf e*.lst failed_testvectors.txt result.txt log.txt lwc_tb timing.txt timing.csv

