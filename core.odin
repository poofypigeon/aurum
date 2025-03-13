package aurum

import "core:fmt"
import "core:mem"

import "auras"


//===----------------------------------------------------------===//
//    Register File
//===----------------------------------------------------------===//


WORD_SIZE :: size_of(u32)

Program_Status_Register :: bit_field u32 {
    z: bool | 1,
    n: bool | 1,
    v: bool | 1,
    c: bool | 1,
    i: bool | 1,
    t: bool | 1,
    s: bool | 1,
    p: bool | 1,
    _: uint | 24,
}

Register_File :: struct {
    psr: [2]Program_Status_Register,
    gpr: [13]u32, // general purpose registers
    sp: [2]u32,   // stack pointer banks
    lr: [2]u32,   // link register banks
    pc: u32,      // program counter
}

register_file_init :: proc() -> Register_File {
    return Register_File{
        psr = Program_Status_Register{
            p = true, s = true, t = true, i = true
        }
    }
}

@(private = "file") ps_mask := u32(Program_Status_Register{ p = true, s = true })
@(private = "file") s_mask  := u32(Program_Status_Register{ s = true })

active_psr_bank_index :: #force_inline proc(regfile: ^Register_File) -> uint {
    return uint(regfile.psr[0].s)
}

active_psr_bank :: #force_inline proc(regfile: ^Register_File) -> ^Program_Status_Register {
    return &regfile.psr[active_psr_bank_index(regfile)]
}

active_sp :: #force_inline proc(regfile: ^Register_File) -> ^u32 {
    return &regfile.sp[uint(regfile.psr[0].s)]
}

active_lr :: #force_inline proc(regfile: ^Register_File) -> ^u32 {
    return &regfile.lr[uint(regfile.psr[0].s)]
}

register_read :: #force_inline proc (regfile: ^Register_File, register: u32) -> u32 {
    bank := uint(regfile.psr[0].s)
    switch register {
    case 0: return 0
    case 1..=13: return regfile.gpr[register - 1]
    case 14: return regfile.sp[bank]
    case 15: return regfile.lr[bank]
    }
    panic("trying to read from invalid register")
}

register_write :: #force_inline proc (regfile: ^Register_File, register: u32, value: u32) {
    bank := uint(regfile.psr[0].s)
    switch register {
    case 0: return
    case 1..=13: regfile.gpr[register - 1] = value
    case 14: regfile.sp[bank] = value
    case 15: regfile.lr[bank] = value
    case: panic("trying to write to invalid register")
    }
}


//===----------------------------------------------------------===//
//    Execution
//===----------------------------------------------------------===//


@(private)
Branch_Address :: union {
    u32,
    Exception
}

@(private)
Exception :: enum {
    None        = -1,
    Reset       =  0,
    Syscall     =  4,
    Bus_Fault   =  8,
    Usage_Fault = 12,
    Instruction = 16,
    Systick     = 20,
    _           = 24,
    _           = 28,
    _           = 32,
    _           = 36,
    _           = 40,
    _           = 44,
    _           = 48,
    _           = 52,
    _           = 56,
    IRQ0        = 60,
    IRQ1        = 64,
    IRQ2        = 68,
    IRQ3        = 72,
    IRQ4        = 76,
    IRQ5        = 80,
    IRQ6        = 84,
    IRQ7        = 88,
}

@(private)
execute_clock_cycle :: proc(regfile: ^Register_File, memory: ^Memory_Space, hooks: []Aurum_Hook) {
    machine_word, except := memory_read(memory, regfile.pc, WORD_SIZE)
    if except != nil { panic("misaligned program counter") }

    branch_address := execute_instruction(regfile, memory, machine_word, hooks)
    if branch_address == nil {
        regfile.pc += 4
        return
    }

    switch v in branch_address {
    case u32:       regfile.pc = v
    case Exception: regfile.pc = u32(v)
    }
}

@(private)
execute_instruction :: proc(regfile: ^Register_File, memory: ^Memory_Space, machine_word: u32, hooks: []Aurum_Hook) -> Branch_Address {
    switch machine_word >> 30 {
    case 0b00:
        if machine_word >> 15 & 0b11 == 0b11 {
            if ((machine_word >> 29) & 1) == 0b1 {
                return execute_set_clear_psr_bits(regfile, machine_word)
            }
            return execute_move_from_psr(regfile, machine_word)
        }
        return execute_data_transfer(regfile, memory, machine_word)
    case 0b01:
        execute_data_processing(regfile, machine_word)
        return nil
    case 0b10:
        return execute_branch(regfile, machine_word)
    case 0b11:
        if machine_word >> 29 & 0b1 == 0b0 {
            execute_move_immediate(regfile, machine_word)
            return nil
        }
        return execute_software_interrupt(regfile, memory, machine_word, hooks)
    }
    panic("unreachable")
}

@(private = "file")
execute_data_transfer :: proc(regfile: ^Register_File, memory: ^Memory_Space, machine_word: u32) -> Branch_Address {
    instr := auras.Data_Transfer_Encoding(machine_word)

    base_address := register_read(regfile, instr.rm)

    assert(!(instr.b && instr.h))
    width: uint = (instr.b) ? 1 : (instr.h) ? 2 : 4
    offset := (instr.i) ? u32(instr.offset) : register_read(regfile, instr.offset)
    shift := instr.shift * 2
    offset <<= shift

    calculated_address := (instr.n) ? base_address - offset : base_address + offset
    effective_address := (instr.p) ? base_address : calculated_address
    writeback_address := (instr.p || instr.w) ? calculated_address : base_address

    register_write(regfile, instr.rm, writeback_address)

    if instr.s {
        except := memory_write(memory, effective_address, width, register_read(regfile, instr.rd))
        if except == .None { return nil }
        return except
    }

    value := memory_read(memory, effective_address, width) or_return
    if instr.m && value >> ((width * 8) - 1) == 1 { // sign extend
        value |= 0xFFFF_FFFF << (width * 8)
    }
    register_write(regfile, instr.rd, value)
    return nil
}

@(private = "file")
execute_move_from_psr :: proc(regfile: ^Register_File, machine_word: u32) -> Branch_Address {
    MOVE_FROM_PSR_ENCODING_MASK :: 0x0F02_0000
    if machine_word &~ MOVE_FROM_PSR_ENCODING_MASK != 0x0001_8000 { return .Instruction } // Malformed

    instr := auras.Move_From_PSR_Encoding(machine_word)
    register_write(regfile, instr.rd, (^u32)(active_psr_bank(regfile))^)

    return nil
}

@(private = "file")
execute_set_clear_psr_bits :: proc(regfile: ^Register_File, machine_word: u32) -> Branch_Address {
    SET_CLEAR_PSR_BITS_ENCODING_MASK :: 0x1F02_03FF

    if machine_word &~ SET_CLEAR_PSR_BITS_ENCODING_MASK != 0x2001_8000 { // Malformed
        return .Instruction
    }

    instr := auras.Set_Clear_PSR_Bits_Encoding(machine_word)
    bank := uint(regfile.psr[0].s)

    mask := (instr.i) ? u32(instr.operand) : u32(register_read(regfile, instr.operand))

    // User mode
    if !regfile.psr[bank].p {
        assert(!regfile.psr[bank].s)
        if instr.s {
            (^u32)(&regfile.psr[bank])^ |= (mask & 0x0F)
        } else {
            (^u32)(&regfile.psr[bank])^ &= ~(mask & 0x0F)
        }
        return nil
    }

    // Supervisor/system mode
    reenter_user_mode := false

    if instr.s {
        (^u32)(&regfile.psr[bank])^ |= (mask & 0xFF)
    } else {
        (^u32)(&regfile.psr[bank])^ &= ~(mask & 0xFF)

        // Clear S bit if P bit is cleared and reenter user mode
        if !regfile.psr[bank].p {
            regfile.psr[bank].s = false
            reenter_user_mode = true
        }
    }

    // Maintain continuity of P and S bits between banks
    regfile.psr[~bank & 1].p = regfile.psr[bank].p
    regfile.psr[~bank & 1].s = regfile.psr[bank].s

    // Keep supervisor T bit hardcoded high
    regfile.psr[1].t = true

    return (reenter_user_mode) ? regfile.lr[1] : nil
}

@(private = "file")
execute_data_processing :: proc(regfile: ^Register_File, machine_word: u32) {
    instr := auras.Data_Processing_Encoding(machine_word)
    psr := active_psr_bank(regfile)

    lhs := u32(register_read(regfile, instr.rm))
    rhs := (instr.i) ? u32(instr.operand2) : u32(register_read(regfile, instr.operand2))
    shift := (instr.h) ? uint(instr.shift) : uint(register_read(regfile, instr.shift))

    shift_carry: bool = psr.c
    if instr.d {
        shift = (shift == 0) ? 32 : shift
        shift_carry = ((1 << (shift - 1)) & rhs != 0)
        if shift >= 32 {
            sign_bit_set := ((1 << 31) & rhs != 0)
            rhs = (instr.a && sign_bit_set) ? 0xFFFF_FFFF : 0
            shift_carry = (instr.a) ? sign_bit_set : shift_carry
        } else {
            rhs = (instr.a) ? u32(i32(rhs) >> shift) : rhs >> shift
        }
    } else if shift != 0 {
        shift_carry = ((1 << (32 - shift)) & rhs != 0)
        rhs = rhs << shift
    }

    result: u64 = ---
    switch instr.opcode {
    case .add: result = u64(lhs) + u64(rhs)
    case .adc: result = u64(lhs) + u64(rhs) + u64(psr.c)
    case .sub: result = u64(lhs) + u64(~u32(rhs)) + 1
    case .sbc: result = u64(lhs) + u64(~u32(rhs)) + u64(psr.c)
    case .and: result = u64(lhs & rhs)
    case .or: result = u64(lhs | rhs)
    case .xor: result = u64(lhs ~ rhs)
    case .btc: result = u64(lhs &~ rhs)
    }
    register_write(regfile, instr.rd, u32(result))

    // Condition code updates are disabled for left shifts with instr.a set
    if (!instr.d && instr.a) { return }

    switch instr.opcode {
    case .add, .adc, .sub, .sbc:
        psr.c = ((1 << 32) & result != 0)
        psr.v = overflow(lhs, rhs, u32(result))
    case .and, .or, .xor, .btc:
        psr.c = shift_carry
    }

    psr.n = (1 << 31 & result != 0)
    psr.z = u32(result) == 0

    overflow :: #force_inline proc(lhs: u32, rhs: u32, result: u32) -> bool {
        return ((((lhs & rhs & ~result) | (~lhs & ~rhs & result)) >> 31) != 0)
    }
}

@(private = "file")
execute_software_interrupt :: proc(regfile: ^Register_File, memory: ^Memory_Space, machine_word: u32, hooks: []Aurum_Hook) -> Branch_Address {
    machine_word := u32(machine_word)

    for hook in hooks {
        if machine_word &~ hook.mask == hook.pattern {
            hook.action(regfile, memory)
        }
    }

    regfile.lr[1] = regfile.pc + 4
    (^u32)(&regfile.psr[0])^ |= 0xF0
    (^u32)(&regfile.psr[1])^ |= 0xF0

    return .Syscall
}

@(private = "file")
execute_branch :: proc(regfile: ^Register_File, machine_word: u32) -> Branch_Address {
    instr := auras.Branch_Encoding(machine_word)
    psr := active_psr_bank(regfile)

    follow_branch: bool = ---
    switch instr.condition {
        case .eq: follow_branch =  psr.z
        case .ne: follow_branch = !psr.z
        case .cs: follow_branch =  psr.c
        case .cc: follow_branch = !psr.c
        case .mi: follow_branch =  psr.n
        case .pl: follow_branch = !psr.n
        case .vs: follow_branch =  psr.v
        case .vc: follow_branch = !psr.v
        case .hi: follow_branch =  psr.c && !psr.z
        case .ls: follow_branch = !psr.c ||  psr.z
        case .ge: follow_branch =  psr.n ==  psr.v
        case .lt: follow_branch =  psr.n !=  psr.v
        case .gt: follow_branch =  psr.n ==  psr.v && !psr.z
        case .le: follow_branch =  psr.n !=  psr.v ||  psr.z
        case .al: follow_branch =  true
        case: return .Instruction
    }
    if !follow_branch { return nil }

    if instr.l { // Move next instruction address to link register
        active_lr(regfile)^ = regfile.pc + WORD_SIZE
    }

    if !instr.i { // Branch to address in register (lowest two bits masked out)
        return register_read(regfile, instr.offset) &~ 0b11
    }
    
    // Branch to relative address offset
    offset := u32(instr.offset) << 2
    if offset >> 25 == 0b1 { // sign extend
        offset |= 0xFC00_0000
    }
    return regfile.pc + offset
}

@(private = "file")
execute_move_immediate :: proc(regfile: ^Register_File, machine_word: u32) {
    instr := auras.Move_Immediate_Encoding(machine_word)

    imm: u32 = u32(instr.immediate)
    if instr.m {
        imm |= 0xFF00_0000
    }

    register_write(regfile, instr.rd, imm)
}
