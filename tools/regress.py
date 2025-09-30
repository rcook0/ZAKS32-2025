import random
from iss import Z32ISS

# We assume Verilator build is ready: obj_dir/Vsoc_top
import subprocess

def random_instr():
    """Generate a random 32-bit instruction in our encoding scheme."""
    op = random.choice([
        0x00, 0x01, 0x02, 0x03, 0x04, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x27, 0x28,
        0x29, 0x2A, 0x2D, 0x2E, 0x2F, 0x30, 0x31
    ])
    rd  = random.randint(0,15)
    rs1 = random.randint(0,15)
    rs2 = random.randint(0,15)
    imm = random.randint(-128,127) & 0x3FFF
    instr = (op << 26) | (rd << 22) | (rs1 << 18) | (rs2 << 14) | (imm & 0x3FFF)
    return instr

def run_iss(instrs, steps=100):
    iss = Z32ISS()
    for i in range(steps):
        pc = iss.pc
        if pc//4 < len(instrs):
            instr = instrs[pc//4]
            iss.step(instr)
        else:
            break
    return iss

def write_hex(instrs, fname="rand.hex"):
    with open(fname,"w") as f:
        for instr in instrs:
            f.write(f"{instr:08X}\n")

def run_rtl(hexfile="rand.hex", cycles=5000):
    """Run Verilator sim with given hexfile and capture final reg dump."""
    cmd = ["./obj_dir/Vsoc_top", f"+rom={hexfile}"]
    out = subprocess.check_output(cmd, timeout=10).decode()
    # Expect testbench to dump regfile_dbg at end
    regs = [0]*16
    for line in out.splitlines():
        if line.startswith("REGDUMP"):
            parts = line.split()
            idx, val = int(parts[1]), int(parts[2],16)
            regs[idx] = val
    return regs

def main():
    # Generate program
    instrs = [random_instr() for _ in range(128)]
    write_hex(instrs)

    # Run ISS
    iss = run_iss(instrs, steps=200)

    # Run RTL
    rtl_regs = run_rtl()

    # Compare
    for i in range(16):
        if rtl_regs[i] != iss.regs[i]:
            print(f"Mismatch R{i}: RTL={rtl_regs[i]:08X}, ISS={iss.regs[i]:08X}")
        else:
            print(f"R{i}: {rtl_regs[i]:08X}")

if __name__ == "__main__":
    main()
