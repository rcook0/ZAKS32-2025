#include "Vsoc_top.h"
#include "verilated.h"
#include "iss.h" // Python ISS callable via pybind11 or IPC
#include <iostream>

vluint64_t main_time = 0;

double sc_time_stamp() { return main_time; }

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vsoc_top *top = new Vsoc_top;

    while (!Verilated::gotFinish() && main_time < 200000) {
        top->clk = (main_time & 1);
        top->eval();
        
        if (top->uart_tx_ready) {
            char c = (char)top->uart_tx_data;
            std::cout << c << std::flush;
        }

        // ISS Diff
        if (top->commit_valid) {
            uint32_t instr = top->commit_instr;
            iss.step(instr);   // update reference model

            for (int i = 0; i < 16; i++) {
                if (top->regfile[i] != iss.regs[i]) {
                    VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
                                ("Regfile mismatch at r" + std::to_string(i)).c_str());
                }
            }
        }
        
        main_time++;
        if (main_time > MAX_TIME) {
            for (int i=0; i<16; i++) {
                 std::cout << "REGDUMP " << i << " " 
                           << std::hex << top->regfile_dbg[i] << std::endl;
            }
            break;
        }
    }
    
    delete top;
    return 0;
}
