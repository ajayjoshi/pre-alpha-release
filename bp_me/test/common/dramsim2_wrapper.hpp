
#include "svdpi.h"

#include <fstream>
#include <iostream>
#include <sstream>
#include <cstdio>
#include <cstdint>
#include <string>
#include <cstdlib>
#include <map>
#include <queue>

#include "DRAMSim.h"

class bp_dram
{
  public:
    std::map<uint64_t, uint8_t> mem;

    uint64_t result_size;

    std::map<string, svBitVecVal *> result_data;
    std::map<string, bool> result_pending;

    std::map<uint64_t, std::queue<string>> addr_tracker;

    string tick_scope;

  public:
    void read_hex(char *);

    void read_complete(unsigned, uint64_t, uint64_t);
    void write_complete(unsigned, uint64_t, uint64_t);
};

