#!/usr/bin/env python3
import sys, yaml


FIELDS = ["next","jam_z","jam_n","dispatch","endi","alu_op","src_a","src_b",
"a_is_rs1","b_is_rs2","wr_rd","wr_pc","wr_mar","wr_mdr","shift",
"mem_rd","mem_wr","ir_load","pc_inc","flags_we","imm_load","io_space"]


def pack_uinstr(entry):
word = 0
for f in FIELDS:
if f in entry:
val = entry[f]
if isinstance(val, str): val = int(val,0)
word |= (val & 1) if isinstance(val,bool) else val
return word


def main():
data = yaml.safe_load(open(sys.argv[1]))
with open("microcode.hex","w") as f:
for page, insts in data.get("pages",{}).items():
for name, vecs in insts.items():
for vec in vecs:
w = pack_uinstr(vec)
f.write(f"{w:024x}\n")


if __name__ == "__main__":
main()
