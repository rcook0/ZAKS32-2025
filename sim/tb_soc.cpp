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
        main_time++;
    }
    delete top;
    return 0;
}
