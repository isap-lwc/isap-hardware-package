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
MODULES_V1_8BIT=\
	src_rtl/v1_8bit/NIST_LWAPI_pkg.o\
	src_rtl/v1_8bit/design_pkg.o\
	src_rtl/LWC/fwft_fifo.o\
	src_rtl/LWC/StepDownCountLd.o\
	src_rtl/LWC/data_piso.o\
	src_rtl/LWC/data_sipo.o\
	src_rtl/LWC/key_piso.o\
	src_rtl/v1_8bit/CryptoCore.o\
	src_rtl/LWC/PostProcessor.o\
	src_rtl/LWC/PreProcessor.o\
	src_rtl/LWC/LWC.o\
    src_tb/v1_8bit/LWC_TB_compatibility_pkg.o\
	src_tb/v1_8bit/LWC_TB
MODULES_V1_16BIT=\
	src_rtl/v1_16bit/NIST_LWAPI_pkg.o\
	src_rtl/v1_16bit/design_pkg.o\
	src_rtl/LWC/fwft_fifo.o\
	src_rtl/LWC/StepDownCountLd.o\
	src_rtl/LWC/data_piso.o\
	src_rtl/LWC/data_sipo.o\
	src_rtl/LWC/key_piso.o\
	src_rtl/v1_16bit/CryptoCore.o\
	src_rtl/LWC/PostProcessor.o\
	src_rtl/LWC/PreProcessor.o\
	src_rtl/LWC/LWC.o\
    src_tb/v1_16bit/LWC_TB_compatibility_pkg.o\
	src_tb/v1_16bit/LWC_TB
MODULES_V1_LL=\
	src_rtl/v1_lowlatency/NIST_LWAPI_pkg.o\
	src_rtl/v1_lowlatency/design_pkg.o\
	src_rtl/LWC/fwft_fifo.o\
	src_rtl/LWC/StepDownCountLd.o\
	src_rtl/LWC/data_piso.o\
	src_rtl/LWC/data_sipo.o\
	src_rtl/LWC/key_piso.o\
	src_rtl/v1_lowlatency/CryptoCore.o\
	src_rtl/LWC/PostProcessor.o\
	src_rtl/LWC/PreProcessor.o\
	src_rtl/LWC/LWC.o\
    src_tb/v1_lowlatency/LWC_TB_compatibility_pkg.o\
	src_tb/v1_lowlatency/LWC_TB
MODULES_V1_STP=\
	src_rtl/v1_StP/NIST_LWAPI_pkg.o\
	src_rtl/v1_StP/design_pkg.o\
	src_rtl/LWC/fwft_fifo.o\
	src_rtl/LWC/StepDownCountLd.o\
	src_rtl/LWC/data_piso.o\
	src_rtl/LWC/data_sipo.o\
	src_rtl/LWC/key_piso.o\
	src_rtl/v1_StP/CryptoCore.o\
	src_rtl/LWC/PostProcessor.o\
	src_rtl/LWC/PreProcessor.o\
	src_rtl/LWC/LWC.o\
    src_tb/v1_StP/LWC_TB_compatibility_pkg.o\
	src_tb/v1_StP/LWC_TB
MODULES_V1_DECFAIL=\
	src_rtl/v1_decfail/NIST_LWAPI_pkg.o\
	src_rtl/v1_decfail/design_pkg.o\
	src_rtl/LWC/fwft_fifo.o\
	src_rtl/LWC/StepDownCountLd.o\
	src_rtl/LWC/data_piso.o\
	src_rtl/LWC/data_sipo.o\
	src_rtl/LWC/key_piso.o\
	src_rtl/v1_decfail/CryptoCore.o\
	src_rtl/v1_decfail/PostProcessor.o\
	src_rtl/LWC/PreProcessor.o\
	src_rtl/v1_decfail/LWC.o\
    src_tb/v1_decfail/LWC_TB_compatibility_pkg.o\
	src_tb/v1_decfail/LWC_TB
MODULES_V2=\
	src_rtl/v2/NIST_LWAPI_pkg.o\
	src_rtl/v2/design_pkg.o\
	src_rtl/LWC/fwft_fifo.o\
	src_rtl/LWC/StepDownCountLd.o\
	src_rtl/LWC/data_piso.o\
	src_rtl/LWC/data_sipo.o\
	src_rtl/LWC/key_piso.o\
	src_rtl/v2/CryptoCore.o\
	src_rtl/LWC/PostProcessor.o\
	src_rtl/LWC/PreProcessor.o\
	src_rtl/LWC/LWC.o\
    src_tb/v2/LWC_TB_compatibility_pkg.o\
	src_tb/v2/LWC_TB

v1: $(MODULES_V1)
	$(info More v1 testbench output can be found in log.txt or failed_testvectors.txt)

v1_8bit: $(MODULES_V1_8BIT)
	$(info More v1_8bit testbench output can be found in log.txt or failed_testvectors.txt)

v1_16bit: $(MODULES_V1_16BIT)
	$(info More v1_16bit testbench output can be found in log.txt or failed_testvectors.txt)

v1_lowlatency: $(MODULES_V1_LL)
	$(info More v1_lowlatency testbench output can be found in log.txt or failed_testvectors.txt)

v1_StP: $(MODULES_V1_STP)
	$(info More v1_StP testbench output can be found in log.txt or failed_testvectors.txt)

v1_decfail: $(MODULES_V1_DECFAIL)
	$(info More v1_decfail testbench output can be found in log.txt or failed_testvectors.txt)

v2: $(MODULES_V2)
	$(info More v2 testbench output can be found in log.txt or failed_testvectors.txt)

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

