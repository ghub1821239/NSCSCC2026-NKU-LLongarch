#ifndef LA32R_CORE
#define LA32R_CORE

#include "la32r_common.hpp"
#include "la32r_mmu.hpp"
#include "la32r_csr.hpp"

#include <cstdint>
#include <cstring>
#include <cassert>
#include <queue>

#include <cstdio>

template<int nr_tlb_entry = 32>
class la32r_core {
public:
    la32r_core(uint32_t core_id, memory_bus &bus, bool trace) : mmu(bus), csr(core_id, pc, mmu), trace(trace) {
        reset();
    }

    void reset() {
        idle = false;
        end = false;
        counter = 0;
        pc = 0x1c000000u;
        memset(GPR, 0, sizeof(GPR));
        mmu.reset();
        csr.reset();
    }

    uint32_t get_pc() {
        return pc;
    }

    void csr_cfg(uint32_t index, uint32_t value) {
        csr.write(index, value);
    }

    void reg_cfg(uint32_t index, uint32_t value) {
        GPR[index] = value;
    }

    void step(uint8_t ext_int = 0) {
        exec(ext_int);
    }

    void jump(uint32_t new_pc) {
        pc = new_pc;
    }

    bool is_end() {
        return end;
    }

    bool open_golden_trace(const char *filename) {
        close_golden_trace();
        golden_fp = fopen(filename, "w");
        dump_trace = (golden_fp != nullptr);
        return dump_trace;
    }

    void close_golden_trace() {
        if(golden_fp) {
            fclose(golden_fp);
            golden_fp = nullptr;
        }
        dump_trace = false;
    }

private:
    void exec(uint8_t exc_int) {
        la32r_instr instr;
        la32r_exccode if_exc;
        uint32_t next_pc;
        bool cur_control_trans = false;
        bool ine = false;
        GPR[0] = 0;
        counter += 1;
        pc_trace.push(pc);
        while (pc_trace.size() > 16) {
            pc_trace.pop();
        }
        csr.pre_exec(exc_int);
        if (csr.need_trap()) {
            idle = false;
            goto ctrl_trans_and_exception;
        } else if (idle) {
            return;
        }
        if_exc = mmu.va_if(pc,
                           (char * ) & instr,
                           csr.get_cur_plv(),
                           csr.get_crmd_pg(),
                           csr.get_asid());
        if (if_exc.first != OK) {
            csr.raise_trap(if_exc, pc);
            goto ctrl_trans_and_exception;
        }
        switch (instr._i26.opcode) { // OPCODE.length == 6
        case JIRL:
            cur_control_trans = true;
            next_pc = GPR[instr._2ri16.rj] + (instr._2ri16.i16 << 2);
            set_GPR(instr._2ri16.rd, pc + 4);
            break;
        case B:
            cur_control_trans = true;
            next_pc = pc + (cal_i26(instr._i26.i26_hi, instr._i26.i26_lo) << 2);
            break;
        case BL:
            cur_control_trans = true;
            next_pc = pc + (cal_i26(instr._i26.i26_hi, instr._i26.i26_lo) << 2);
            set_GPR(1, pc + 4);
            break;
        case BEQ:
            if (GPR[instr._2ri16.rj] == GPR[instr._2ri16.rd]) {
                cur_control_trans = true;
                next_pc = pc + (instr._2ri16.i16 << 2);
            }
            break;
        case BNE:
            if (GPR[instr._2ri16.rj] != GPR[instr._2ri16.rd]) {
                cur_control_trans = true;
                next_pc = pc + (instr._2ri16.i16 << 2);
            }
            break;
        case BLT:
            if (GPR[instr._2ri16.rj] < GPR[instr._2ri16.rd]) {
                cur_control_trans = true;
                next_pc = pc + (instr._2ri16.i16 << 2);
            }
            break;
        case BGE:
            if (GPR[instr._2ri16.rj] >= GPR[instr._2ri16.rd]) {
                cur_control_trans = true;
                next_pc = pc + (instr._2ri16.i16 << 2);
            }
            break;
        case BLTU:
            if (static_cast<uint32_t>(GPR[instr._2ri16.rj]) < static_cast<uint32_t>(GPR[instr._2ri16.rd])) {
                cur_control_trans = true;
                next_pc = pc + (instr._2ri16.i16 << 2);
            }
            break;
        case BGEU:
            if (static_cast<uint32_t>(GPR[instr._2ri16.rj]) >= static_cast<uint32_t>(GPR[instr._2ri16.rd])) {
                cur_control_trans = true;
                next_pc = pc + (instr._2ri16.i16 << 2);
            }
            break;
        default:
            switch (instr._1rsi20.opcode) { // OPCODE.length == 7
            case LU12I_W:
                set_GPR(instr._1rsi20.rd, instr._1rsi20.si20 << 12);
                break;
            case PCADDU12I:
                set_GPR(instr._1rsi20.rd, pc + (instr._1rsi20.si20 << 12));
                break;
            default:
                switch (instr._2ri14.opcode) { // OPCODE.length == 8
                case CSR:
                    if (csr.get_cur_plv() != plv0) {
                        csr.raise_trap(std::make_pair(IPE, 0));
                    } else {
                        auto origin_val = csr.read(instr._2ri14.i14);
                        switch (instr._2ri14.rj) {
                        case RD: // csr read
                            set_GPR(instr._2ri14.rd, origin_val);
                            break;
                        case WR: // csr write
                        default: // csr exchange
                            auto mask = (instr._2ri14.rj == WR) ? ~0u : GPR[instr._2ri14.rj];
                            auto write_val = (GPR[instr._2ri14.rd] & mask) | (origin_val & ~mask);
                            trace_csr_write(instr._2ri14.i14, GPR[instr._2ri14.rd]);
                            csr.write(instr._2ri14.i14, write_val);
                            set_GPR(instr._2ri14.rd, origin_val);
                            break;
                        }
                    }
                    break;
                case LL_W: {
                    uint32_t temp;
                    uint32_t va = GPR[instr._2ri14.rj] + (instr._2ri14.i14 << 2);
                    la32r_exccode exc = mmu.va_read(va, 4, (char * ) & temp,
                                                    csr.get_cur_plv(),
                                                    csr.get_crmd_pg(),
                                                    csr.get_asid());
                    if (exc.first != OK) {
                        csr.raise_trap(exc, va);
                    } else {
                        set_GPR(instr._2ri14.rd, temp);
                        csr.set_llbit();
                    }
                    break;
                }
                case SC_W: {
                    uint32_t va = GPR[instr._2ri14.rj] + (instr._2ri14.i14 << 2);
                    if (csr.get_llbit()) {
                        la32r_exccode exc = mmu.va_write(va, 4, (char * ) & GPR[instr._2ri14.rd],
                                                         csr.get_cur_plv(),
                                                         csr.get_crmd_pg(),
                                                         csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        } else {
                            csr.clr_llbit();
                            set_GPR(instr._2ri14.rd, 1);
                        }
                    } else {
                        set_GPR(instr._2ri14.rd, 0);
                    }
                    break;
                }
                default:
                    switch (instr._2ri12.opcode) { // OPCODE.length == 10
                    case SLTI:
                        set_GPR(instr._2ri12.rd, GPR[instr._2ri12.rj] < instr._2ri12.i12);
                        break;
                    case SLTUI:
                        set_GPR(instr._2ri12.rd,
                                static_cast<uint32_t>(GPR[instr._2ri12.rj]) < static_cast<uint32_t>(instr._2ri12.i12));
                        break;
                    case ADDI_W:
                        set_GPR(instr._2ri12.rd, GPR[instr._2ri12.rj] + instr._2ri12.i12);
                        break;
                    case ANDI:
                        set_GPR(instr._2ri12.rd, static_cast<uint32_t>(GPR[instr._2ri12.rj]) &
                                                 (static_cast<uint32_t>(instr._2ri12.i12) & 0xfff));
                        break;
                    case ORI:
                        set_GPR(instr._2ri12.rd, static_cast<uint32_t>(GPR[instr._2ri12.rj]) |
                                                 (static_cast<uint32_t>(instr._2ri12.i12) & 0xfff));
                        break;
                    case XORI:
                        set_GPR(instr._2ri12.rd, static_cast<uint32_t>(GPR[instr._2ri12.rj]) ^
                                                 (static_cast<uint32_t>(instr._2ri12.i12) & 0xfff));
                        break;
                    case CACOP:
                        if (csr.get_cur_plv() != plv0) {
                            uint8_t code = instr._2ri12.rd;
                            // "HIT Invalidate" is allowed in plv3
                            if (csr.get_cur_plv() == plv3 && ((code >> 3) & 0b11) == 2) {
                                // cemu does nothing, because cache is not implemented
                            }
                            csr.raise_trap(std::make_pair(IPE, 0));
                        } else {
                            // cemu does nothing, because cache is not implemented
                        }
                        break;
                    case LD_B: {
                        uint32_t va = GPR[instr._2ri12.rj] + instr._2ri12.i12;
                        int8_t temp;
                        la32r_exccode exc = mmu.va_read(va, 1, (char * ) & temp,
                                                        csr.get_cur_plv(),
                                                        csr.get_crmd_pg(),
                                                        csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        } else {
                            set_GPR(instr._2ri12.rd, static_cast<int32_t>(temp));
                        }
                        break;
                    }
                    case LD_H: {
                        uint32_t va = GPR[instr._2ri12.rj] + instr._2ri12.i12;
                        int16_t temp;
                        la32r_exccode exc = mmu.va_read(va, 2, (char * ) & temp,
                                                        csr.get_cur_plv(),
                                                        csr.get_crmd_pg(),
                                                        csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        } else {
                            set_GPR(instr._2ri12.rd, static_cast<int32_t>(temp));
                        }
                        break;
                    }
                    case LD_W: {
                        uint32_t va = GPR[instr._2ri12.rj] + instr._2ri12.i12;
                        int32_t temp;
                        la32r_exccode exc = mmu.va_read(va, 4, (char * ) & temp,
                                                        csr.get_cur_plv(),
                                                        csr.get_crmd_pg(),
                                                        csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        } else {
                            set_GPR(instr._2ri12.rd, temp);
                        }
                        break;
                    }
                    case ST_B: {
                        uint32_t va = GPR[instr._2ri12.rj] + instr._2ri12.i12;
                        la32r_exccode exc = mmu.va_write(va, 1, (char * ) & GPR[instr._2ri12.rd],
                                                         csr.get_cur_plv(),
                                                         csr.get_crmd_pg(),
                                                         csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        }
                        break;
                    }
                    case ST_H: {
                        uint32_t va = GPR[instr._2ri12.rj] + instr._2ri12.i12;
                        la32r_exccode exc = mmu.va_write(va, 2, (char * ) & GPR[instr._2ri12.rd],
                                                         csr.get_cur_plv(),
                                                         csr.get_crmd_pg(),
                                                         csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        }
                        break;
                    }
                    case ST_W: {
                        uint32_t va = GPR[instr._2ri12.rj] + instr._2ri12.i12;
                        la32r_exccode exc = mmu.va_write(va, 4, (char * ) & GPR[instr._2ri12.rd],
                                                         csr.get_cur_plv(),
                                                         csr.get_crmd_pg(),
                                                         csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        }
                        break;
                    }
                    case LD_BU: {
                        uint32_t va = GPR[instr._2ri12.rj] + instr._2ri12.i12;
                        uint8_t temp;
                        la32r_exccode exc = mmu.va_read(va, 1, (char * ) & temp,
                                                        csr.get_cur_plv(),
                                                        csr.get_crmd_pg(),
                                                        csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        } else {
                            set_GPR(instr._2ri12.rd, temp);
                        }
                        break;
                    }
                    case LD_HU: {
                        uint32_t va = GPR[instr._2ri12.rj] + instr._2ri12.i12;
                        uint16_t temp;
                        la32r_exccode exc = mmu.va_read(va, 2, (char * ) & temp,
                                                        csr.get_cur_plv(),
                                                        csr.get_crmd_pg(),
                                                        csr.get_asid());
                        if (exc.first != OK) {
                            csr.raise_trap(exc, va);
                        } else {
                            set_GPR(instr._2ri12.rd, temp);
                        }
                        break;
                    }
                    case PRELD:
                        // cemu does nothing, because cache is not implemented
                        break;
                    default:
                        switch (instr._3r.opcode) { // OPCODE.length == 17
                        case ADD_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] + GPR[instr._3r.rk]);
                            break;
                        case SUB_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] - GPR[instr._3r.rk]);
                            break;
                        case SLT:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] < GPR[instr._3r.rk]);
                            break;
                        case SLTU:
                            set_GPR(instr._3r.rd, static_cast<uint32_t>(GPR[instr._3r.rj]) <
                                                  static_cast<uint32_t>(GPR[instr._3r.rk]));
                            break;
                        case NOR:
                            set_GPR(instr._3r.rd, ~(GPR[instr._3r.rj] | GPR[instr._3r.rk]));
                            break;
                        case AND:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] & GPR[instr._3r.rk]);
                            break;
                        case OR:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] | GPR[instr._3r.rk]);
                            break;
                        case XOR:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] ^ GPR[instr._3r.rk]);
                            break;
                        case SLL_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] << (GPR[instr._3r.rk] & 0x1f));
                            break;
                        case SRL_W:
                            set_GPR(instr._3r.rd,
                                    static_cast<uint32_t>(GPR[instr._3r.rj]) >> (GPR[instr._3r.rk] & 0x1f));
                            break;
                        case SRA_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] >> (GPR[instr._3r.rk] & 0x1f));
                            break;
                        case MUL_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] * GPR[instr._3r.rk]);
                            break;
                        case MULH_W: {
                            uint64_t result =
                                    static_cast<int64_t>(GPR[instr._3r.rj]) * static_cast<int64_t>(GPR[instr._3r.rk]);
                            set_GPR(instr._3r.rd, result >> 32);
                            break;
                        }
                        case MULH_WU: {
                            uint64_t result =
                                    static_cast<uint32_t>(GPR[instr._3r.rj]) * 1llu *
                                    static_cast<uint32_t>(GPR[instr._3r.rk]);
                            set_GPR(instr._3r.rd, result >> 32);
                            break;
                        }
                        case DIV_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] / GPR[instr._3r.rk]);
                            break;
                        case MOD_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] % GPR[instr._3r.rk]);
                            break;
                        case DIV_WU:
                            set_GPR(instr._3r.rd, static_cast<uint32_t>(GPR[instr._3r.rj]) /
                                                  static_cast<uint32_t>(GPR[instr._3r.rk]));
                            break;
                        case MOD_WU:
                            set_GPR(instr._3r.rd, static_cast<uint32_t>(GPR[instr._3r.rj]) %
                                                  static_cast<uint32_t>(GPR[instr._3r.rk]));
                            break;
                        case BREAK:
                            csr.raise_trap(std::make_pair(BRK, 0));
                            break;
                        case SYSCALL:
                            csr.raise_trap(std::make_pair(SYS, 0));
                            if ((*((int *) &instr) & 0x7fff) == 0x11) {
                                end = true;
                            }
                            break;
                        case SLLI_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] << instr._3r.rk);
                            break;
                        case SRLI_W:
                            set_GPR(instr._3r.rd, static_cast<uint32_t>(GPR[instr._3r.rj]) >> instr._3r.rk);
                            break;
                        case SRAI_W:
                            set_GPR(instr._3r.rd, GPR[instr._3r.rj] >> instr._3r.rk);
                            break;
                        case IDLE:
                            if (csr.get_cur_plv() != plv0) {
                                csr.raise_trap(std::make_pair(IPE, 0));
                            } else {
                                idle = true;
                            }
                            break;
                        case INVTLB:
                            if (csr.get_cur_plv() != plv0) {
                                csr.raise_trap(std::make_pair(IPE, 0));
                            } else {
                                csr.tlb_invalidate(instr._3r.rd, GPR[instr._3r.rj] & 0x3ff, GPR[instr._3r.rk]);
                            }
                            break;
                        case DBAR:
                        case IBAR:
                            // DBAR & IBAR are ignored in cemu
                            break;
                        default:
                            switch (instr._2r.opcode) { // OPCODE.length == 22
                            case RDTIMEL_W:
                                if (instr._2r.rd == 0) { // RDCNTID
                                    set_GPR(instr._2r.rj, csr.get_timer_id());
                                } else if (instr._2r.rj == 0) { // RDCNTVL.W
                                    set_GPR(instr._2r.rd, counter & 0xffffffffu,false);
                                } else {
                                    // la32r only has RDCNTVL.W & RDCNTVH.W & RDCNTID
                                }
                                break;
                            case RDTIMEH_W:
                                if (instr._2r.rj == 0) { // RDCNTVH.W
                                    set_GPR(instr._2r.rd, counter >> 32,false);
                                } else {
                                    // la32r only has RDCNTVL.W & RDCNTVH.W & RDCNTID
                                }
                                break;
                            case CPUCFG: {
                                uint32_t rjv = static_cast<uint32_t>(GPR[instr._2r.rj]);
                                set_GPR(instr._2r.rd, cpucfg_read(rjv));
                                break;
                            }
                            case TLBSRCH:
                                if (csr.get_cur_plv() != plv0) {
                                    csr.raise_trap(std::make_pair(IPE, 0));
                                } else {
                                    csr.tlb_search();
                                    trace_csr_write(TLBIDX, csr.read(TLBIDX));
                                }
                                break;
                            case TLBRD:
                                if (csr.get_cur_plv() != plv0) {
                                    csr.raise_trap(std::make_pair(IPE, 0));
                                } else {
                                    csr.tlb_read();
                                }
                                break;
                            case TLBWR:
                                if (csr.get_cur_plv() != plv0) {
                                    csr.raise_trap(std::make_pair(IPE, 0));
                                } else {
                                    csr.tlb_write(false);
                                }
                                break;
                            case TLBFILL:
                                if (csr.get_cur_plv() != plv0) {
                                    csr.raise_trap(std::make_pair(IPE, 0));
                                } else {
                                    csr.tlb_write(true);
                                }
                                break;
                            case ERTN:
                                if (csr.get_cur_plv() != plv0) {
                                    csr.raise_trap(std::make_pair(IPE, 0));
                                } else {
                                    csr.ertn();
                                }
                                break;
                            default:
                                ine = true;
                            }
                        }
                    }
                }
            }
        }
        if (ine) csr.raise_trap(std::make_pair(INE, 0));
    ctrl_trans_and_exception:
        if (!csr.need_trap()) {
            pc = cur_control_trans ? next_pc : (pc + 4);
        } else {
            pc = csr.get_trap_pc();
        }
    }

    uint32_t cpucfg_read(uint32_t rj_value) {
        const uint32_t word0 = 0x14800100u;//PRID

         // word1: ARCH=LA32R, PGMMU=1, PALEN=32, VALEN=32, HP=1
    const uint32_t word1 =  (0u << 0)   |  // ARCH
                            (1u << 2)   |  // PGMMU
                            (0u << 3)   |  // IOCSR
                            (31u << 4)  |  // PALEN-1
                            (31u << 12) |  // VALEN-1
                            (0u << 20)  |  // UAL
                            (0u << 21)  |  // RI
                            (0u << 22)  |  // EP
                            (0u << 23)  |  // RPLV
                            (1u << 24)  |  // HP
                            (0u << 25)  |  // CRC
                            (0u << 26);    // MSG_INT
                            // word2: FP_ver=1, LVZ_ver=1, LLFTP=1, LLFTP_ver=1, DIV32=1
                            const uint32_t word2 =
                            (1u << 3)   |  // FP_ver
                            (1u << 11)  |  // LVZ_ver
                            (1u << 14)  |  // LLFTP
                            (1u << 15)  |  // LLFTP_ver
                            (1u << 25);    // DIV32
                            const uint32_t word3 = 0u;
                            const uint32_t word4 = 75u;            // CC_FREQ
                            const uint32_t word5 = (1u << 16) | 1u; // CC_DIV=1, CC_MUL=1
                            const uint32_t word6 =
                            (0u << 0)  |   // PMP
                            (1u << 1)  |   // PMVER
                            (0u << 4)  |   // PMNUM
                            (31u << 8);    // PMBITS
                            const uint32_t word10 =
                            (1u << 0) |    // L1_IU_Present
                            (1u << 2);     // L1_D_Present
                            const uint32_t word11 =
                            (1u) |         // Way-1
                            (10u << 16) |  // Index_log2
                            (4u << 24);    // Linesize_log2
                            const uint32_t word12 = word11;
                            const uint32_t word13 = 0u;
                            const uint32_t word14 = 0u;
                            switch (rj_value) {
                            case 0x0:  return word0;
                            case 0x1:  return word1;
                            case 0x2:  return word2;
                            case 0x3:  return word3;
                            case 0x4:  return word4;
                            case 0x5:  return word5;
                            case 0x6:  return word6;
                            case 0x10: return word10;
                            case 0x11: return word11;
                            case 0x12: return word12;
                            case 0x13: return word13;
                            case 0x14: return word14;
                            default:   return 0u;
}

    }

    void set_GPR(uint8_t index, uint32_t value, bool trace_gpr = true) {
        GPR[index] = value;
        if (index == 0) {
            return;
        }
        if (trace) {
            fprintf(stderr, "pc = %08x,  reg = %02d, val = %08x\n", pc, index, value);
        }
        if (dump_trace && golden_fp && trace_gpr) {
            fprintf(golden_fp,"1 %08x %02x %08x\n", pc, index, value);
        }
    }

    void trace_csr_write(uint16_t csr_index, uint32_t wdata) {
        if(dump_trace && golden_fp) {
            fprintf(golden_fp, "2 %08x %04x %08x\n", pc ,csr_index, wdata);
        }
    }

    int32_t cal_i26(unsigned int hi10, unsigned int lo16) {
        return static_cast<int32_t>((hi10 << 16) | lo16) << 6 >> 6;
    }

    bool trace;
    bool end;
    bool dump_trace = false;
    FILE *golden_fp = nullptr;
    std::queue <uint32_t> pc_trace;

    bool idle;
    uint64_t counter;
    uint32_t pc;
    int32_t GPR[32];
    la32r_mmu<nr_tlb_entry> mmu;
    la32r_csr<nr_tlb_entry> csr;
};

#endif // LA32R_CORE
