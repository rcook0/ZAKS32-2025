PYTHON  := python3
UASM    := tools/uasm.py
ASMZ32  := tools/asmz32.py

rom:
\t$(PYTHON) $(UASM) microcode/*.yaml
\t$(PYTHON) $(ASMZ32) firmware/hello.z32 -o hello.hex

build:
\tverilator -Wall --cc rtl/soc_top.sv sim/tb_soc.cpp --exe -o Vsoc_top
\tmake -C obj_dir -f Vsoc_top.mk

run: build
\t./obj_dir/Vsoc_top
