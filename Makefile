rom:
    python3 tools/uasm.py microcode/ucode.yaml
    python3 tools/asmz32.py firmware/hello.z32 -o hello.hex

run: build
    ./obj_dir/Vsoc_top

build:
    verilator -Wall --cc rtl/soc_top.sv sim/tb_soc.cpp --exe -o Vsoc_top
    make -C obj_dir -f Vsoc_top.mk
