#!/usr/bin/env python3
import sys, re

# Opcodes (6-bit space, matches our ISA sketch)
OPC = {
    'NOP': 0x00, 'ADD': 0x01, 'SUB': 0x02,
    'AND': 0x03, 'OR': 0x04,  'XOR': 0x05,
    'NOT': 0x06, 'SHL': 0x07, 'SHR': 0x08, 'SAR': 0x09,
    'ADDI':0x0A, 'ANDI':0x0B, 'ORI':0x0C, 'XORI':0x0D, 'LUI':0x0E,
    'LD':  0x10, 'ST':  0x11,
    'BEQ': 0x18, 'BNE': 0x19,
    'JAL': 0x1C, 'HALT':0x3F
}

REG = { f'r{i}': i for i in range(16) }

def enc_r(op, rd, rs1, rs2, funct=0):
    return (OPC[op]<<26) | (rd<<22) | (rs1<<18) | (rs2<<14) | (funct<<8)

def enc_i(op, rd, rs1, imm):
    imm &= (1<<18)-1
    return (OPC[op]<<26) | (rd<<22) | (rs1<<18) | imm

def enc_j(op, target):
    target &= (1<<26)-1
    return (OPC[op]<<26) | target

def parse_imm(tok):
    if tok.startswith(\"'\") and tok.endswith(\"'\") and len(tok)==3:
        return ord(tok[1])
    return int(tok, 0)

def assemble_line(line):
    line = line.split(';')[0].strip()
    if not line: return None
    toks = re.split(r'[\\s,\\[\\]+]+', line)
    op = toks[0].upper()
    if op in ('ADD','SUB','AND','OR','XOR'):
        rd, rs1, rs2 = map(str.lower, toks[1:4])
        return enc_r(op, REG[rd], REG[rs1], REG[rs2])
    elif op in ('ADDI','ANDI','ORI','XORI','LUI'):
        rd, rs1, imm = toks[1].lower(), toks[2].lower(), parse_imm(toks[3])
        return enc_i(op, REG[rd], REG[rs1], imm)
    elif op == 'LD': # LD rd, [rs1+imm]
        rd, rs1, imm = toks[1].lower(), toks[2].lower(), parse_imm(toks[3])
        return enc_i('LD', REG[rd], REG[rs1], imm)
    elif op == 'ST': # ST [rs1+imm], rs2
        rs1, imm, rs2 = toks[1].lower(), parse_imm(toks[2]), toks[3].lower()
        return enc_i('ST', REG[rs2], REG[rs1], imm)
    elif op in ('BEQ','BNE'):
        rs1, rs2, imm = toks[1].lower(), toks[2].lower(), parse_imm(toks[3])
        return enc_i(op, 0, REG[rs1], imm) | (REG[rs2]<<14)
    elif op in ('JAL','HALT','NOP'):
        return enc_j(op, 0)
    else:
        raise ValueError(f\"Unknown op {op}\")\n\ndef assemble(srcfile, outfile):\n    words = []\n    with open(srcfile) as f:\n        for line in f:\n            w = assemble_line(line)\n            if w is not None:\n                words.append(w)\n    with open(outfile,'w') as f:\n        for w in words:\n            f.write(f\"{w:08x}\\n\")\n\nif __name__ == '__main__':\n    if len(sys.argv)<3:\n        print(\"Usage: asmz32.py input.z32 -o output.hex\")\n        sys.exit(1)\n    src = sys.argv[1]\n    out = sys.argv[3] if sys.argv[2]=='-o' else 'a.hex'\n    assemble(src, out)\n```\n\n---\n\n### Usage\n```bash\npython3 tools/asmz32.py firmware/hello.z32 -o hello.hex\n```\nGenerates a flat text file with one 32-bit instruction per line in hex, ready for `$readmemh` in your ROM.\n\n---\n\nDo you want me to also fold `asmz32.py` into the repo plan (so it shows up under `tools/` in the canvas doc), alongside `uasm.py`? That way the build instructions are fully self-contained.
