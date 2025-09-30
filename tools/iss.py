// Python Golden Model (Instruction Set Simulator)

class Z32ISS:
    def __init__(self):
        self.regs = [0]*16
        self.pc = 0
        self.flags = {"Z":0,"N":0,"C":0,"P":0}
        self.mem = [0]*65536

def step(self, instr):
    op = (instr>>26)&0x3F
    rd = (instr>>22)&0xF
    rs1 = (instr>>18)&0xF
    rs2 = (instr>>14)&0xF
    imm = instr & ((1<<18)-1)
    if op==0x00: # NOP
        self.pc += 4
    elif op==0x01: # ADD
        self.regs[rd] = (self.regs[rs1]+self.regs[rs2])&0xFFFFFFFF
        self.pc += 4
    # Extend for other ops …
    return self.pc
  
