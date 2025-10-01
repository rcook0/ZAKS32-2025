import random, subprocess
from iss import Z32ISS

# Opcodes (from our encoding scheme)
NOP, ADD, SUB, DCR, MVI, LXI, MOV = 0x00,0x01,0x02,0x03,0x04,0x05,0x06
JMP, JNZ, CALL, RET, PUSH, POP, OUT, HLT, RETI = 0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F
ANA, ORA, XRA, CMP = 0x27,0x28,0x29,0x2A
LDA, STA, LDAX, STAX, XCHG, XTHL = 0x2D,0x2E,0x2F,0x30,0x31,0x2C

def encode(op, rd=0, rs1=0, rs2=0, imm=0):
    imm &= 0x3FFF
    return (op<<26) | (rd<<22) | (rs1<<18) | (rs2<<14) | imm

# --- Directed test programs ---

def test_arithmetic():
    """Load R1=10, R2=20, ADD into R3"""
    return [
        encode(MVI, rd=1, imm=10),
        encode(MVI, rd=2, imm=20),
        encode(ADD, rd=3, rs1=1, rs2=2),
        encode(HLT)
    ]

def test_branch_loop():
    """Decrement R1 from 3 to 0, loop with JNZ"""
    return [
        encode(MVI, rd=1, imm=3),        # R1=3
        encode(DCR, rd=1),               # R1=2
        encode(JNZ, imm=-2),             # back to DCR until Z=1
        encode(HLT)
    ]

def test_stack():
    """Push/Pop with R1=42, verify roundtrip"""
    return [
        encode(MVI, rd=1, imm=42),
        encode(PUSH, rd=1),
        encode(MVI, rd=1, imm=0),        # clear R1
        encode(POP, rd=1),               # restore 42
        encode(HLT)
    ]

def test_io():
    """OUT 'X'"""
    return [
        encode(MVI, rd=1, imm=ord('X')),
        encode(OUT, rd=1),
        encode(HLT)
    ]

# Memory tests

def test_mem_abs():
    """Store to absolute address, then load back"""
    return [
        encode(MVI, rd=1, imm=123),     # R1=123
        encode(STA, rs1=1, imm=0x010),  # MEM[0x10] = R1
        encode(MVI, rd=2, imm=0),       # Clear R2
        encode(LDA, rd=2, imm=0x010),   # R2 = MEM[0x10]
        encode(HLT)
    ]

def test_mem_indirect():
    """Use register pair pointer for LDAX/STAX"""
    return [
        encode(MVI, rd=1, imm=77),       # R1=77
        encode(MVI, rd=3, imm=0x020),    # R3=0x20 (pointer base)
        encode(STAX, rs1=3, rs2=1),      # MEM[R3] = R1
        encode(MVI, rd=2, imm=0),        # Clear R2
        encode(LDAX, rd=2, rs1=3),       # R2 = MEM[R3]
        encode(HLT)
    ]


# --- Random generator as before ---

def random_instr():
    op = random.choice([NOP, ADD, SUB, DCR, MVI, MOV, JMP, JNZ,
                        CALL, RET, PUSH, POP, OUT, HLT, ANA, ORA, XRA, CMP])
    rd  = random.randint(0,15)
    rs1 = random.randint(0,15)
    rs2 = random.randint(0,15)
    imm = random.randint(-32,31) & 0x3FFF
    return encode(op, rd, rs1, rs2, imm)

def random_prog(length=32):
    return [random_instr() for _ in range(length)]

# --- Runner helpers ---

def write_hex(instrs, fname="prog.hex"):
    with open(fname,"w") as f:
        for instr in instrs:
            f.write(f"{instr:08X}\n")

def run_iss(instrs, steps=100):
    iss = Z32ISS()
    for _ in range(steps):
        pc = iss.pc
        if pc//4 < len(instrs):
            instr = instrs[pc//4]
            iss.step(instr)
        else:
            break
    return iss

def run_rtl(hexfile="prog.hex", cycles=5000):
    cmd = ["./obj_dir/Vsoc_top", f"+rom={hexfile}"]
    out = subprocess.check_output(cmd, timeout=10).decode()
    regs = [0]*16
    for line in out.splitlines():
        if line.startswith("REGDUMP"):
            _, idx, val = line.split()
            regs[int(idx)] = int(val,16)
    return regs

def regress(instrs, name="test"):
    write_hex(instrs)
    iss = run_iss(instrs, steps=200)
    rtl_regs = run_rtl("prog.hex")
    print(f"=== {name} ===")
    for i in range(16):
        print(f"R{i:02}: ISS={iss.regs[i]:08X} RTL={rtl_regs[i]:08X}")

def main():
    regress(test_arithmetic(), "Arithmetic")
    regress(test_branch_loop(), "Branch Loop")
    regress(test_stack(), "Stack Ops")
    regress(test_io(), "I/O UART")
    regress(random_prog(64), "Random Fuzz")

if __name__ == "__main__":
    main()
