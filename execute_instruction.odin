package aurum

import "core:fmt"
import "auras"

execute_instruction :: proc(regfile: ^Register_File, memory: ^Memory_Space, machine_word: u32le, hooks: []Aurum_Hook) -> Exception {
    switch machine_word >> 30 {
    case 0b00:
        if machine_word >> 15 & 0b11 == 0b11 {
            if ((machine_word >> 29) & 1) == 0b1 {
                if machine_word &~ 0x1F02_03FF != 0x2001_8000 { return nil }
                execute_set_clear_psr_bits(regfile, machine_word)
                return nil
            }
            if machine_word &~ 0x0F02_0000 != 0x0001_8000 { return nil }
            execute_move_from_psr(regfile, machine_word)
            return nil
        }
        return execute_data_transfer(regfile, memory, machine_word)
    case 0b01:
        execute_data_processing(regfile, machine_word)
        return nil
    case 0b10:
        execute_branch(regfile, machine_word)
        return nil
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
execute_data_transfer :: proc(regfile: ^Register_File, memory: ^Memory_Space, machine_word: u32le) -> Exception {
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
        return memory_write(memory, effective_address, width, register_read(regfile, instr.rd))
    }

    value := memory_read(memory, effective_address, width) or_return
    if instr.m && value >> ((width * 8) - 1) == 1 { // sign extend
        value |= 0xFFFF_FFFF << (width * 8)
    }
    register_write(regfile, instr.rd, value)
    return nil
}

@(private = "file")
execute_move_from_psr :: proc(regfile: ^Register_File, machine_word: u32le) {
    instr := auras.Move_From_PSR_Encoding(machine_word)
    register_write(regfile, instr.rd, (^u32)(active_psr_bank(regfile))^)
}

@(private = "file")
execute_set_clear_psr_bits :: proc(regfile: ^Register_File, machine_word: u32le) {
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
        return
    }

    // Supervisor/system mode
    if instr.s {
        (^u32)(&regfile.psr[bank])^ |= (mask & 0xFF)
    } else {
        (^u32)(&regfile.psr[bank])^ &= ~(mask & 0xFF)

        // Clear S bit if P bit is cleared and reenter user mode
        if !regfile.psr[bank].p {
            regfile.psr[bank].s = false
            regfile.pc = regfile.lr[1]
        }
    }

    // Maintain continuity of P and S bits between banks
    regfile.psr[~bank & 1].p = regfile.psr[bank].p
    regfile.psr[~bank & 1].s = regfile.psr[bank].s

    // Keep supervisor T bit hardcoded high
    regfile.psr[1].t = true
}

@(private = "file")
execute_data_processing :: proc(regfile: ^Register_File, machine_word: u32le) {
    instr := auras.Data_Processing_Encoding(machine_word)
    psr := active_psr_bank(regfile)

    lhs := u32(register_read(regfile, instr.rm))
    rhs := (instr.i) ? u32(instr.operand2) : u32(register_read(regfile, instr.operand2))
    shift := (instr.h) ? uint(instr.shift) : uint(register_read(regfile, instr.shift))

    shift_carry: bool = psr.c
    if instr.d {
        shift = (shift == 0) ? 32 : shift
        shift_carry = (1 << (shift - 1) & rhs != 0)
        rhs = (instr.a) ? u32(i32(rhs) >> shift) : rhs >> shift
    } else if shift != 0 {
        shift_carry = (1 << (31 - shift) & rhs != 0)
        rhs = rhs << shift
    }

    result: u64 = ---
    switch instr.opcode {
    case .add: result = u64(lhs) + u64(rhs)
    case .adc: result = u64(lhs) + u64(rhs) + u64(psr.c)
    case .sub: result = u64(lhs) + ~u64(rhs)
    case .sbc: result = u64(lhs) + ~u64(rhs) + u64(psr.c)
    case .and: result = u64(lhs & rhs)
    case .or:  result = u64(lhs | rhs)
    case .xor: result = u64(lhs ~ rhs)
    case .btc: result = u64(lhs &~ rhs)
    }
    register_write(regfile, instr.rd, u32(result))

    // Condition code updates are disabled for left shifts with instr.a set
    if (!instr.d && instr.a) { return }

    switch instr.opcode {
    case .add, .adc, .sub, .sbc:
        psr.c = (1 << 32 & result != 0)
        psr.v = ((lhs & rhs & ~u32(result)) | (~lhs & ~rhs & u32(result)) != 0)
    case .and, .or, .xor, .btc:
        psr.c = shift_carry
    }

    psr.n = (1 << 31 & result != 0)
    psr.z = u32(result) == 0
}

@(private = "file")
execute_software_interrupt :: proc(regfile: ^Register_File, memory: ^Memory_Space, machine_word: u32le, hooks: []Aurum_Hook) -> Exception {
    machine_word := u32(machine_word)

    for hook in hooks {
        if machine_word &~ hook.mask == hook.pattern {
            hook.action(regfile, memory)
        }
    }

    (^u32)(&regfile.psr[0])^ |= 0xF0 
    (^u32)(&regfile.psr[1])^ |= 0xF0 

    return .Syscall
}

@(private = "file")
execute_branch :: proc(regfile: ^Register_File, machine_word: u32le) {
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
        case .ls: follow_branch = !psr.c &&  psr.z
        case .ge: follow_branch =  psr.n ==  psr.v
        case .lt: follow_branch =  psr.n !=  psr.v
        case .gt: follow_branch =  psr.n ==  psr.v && !psr.z
        case .le: follow_branch =  psr.n !=  psr.v &&  psr.z
        case .al: follow_branch =  true
        case: panic("invalid instruction") // TODO handle as exception
    }
    if !follow_branch { return }

    if instr.l { // Move next instruction address to link register
        active_lr(regfile)^ = regfile.pc + WORD_SIZE
    }

    if !instr.i { // Branch to address in register (lowest two bits masked out)
        regfile.pc = register_read(regfile, instr.offset) &~ 0b11
        return
    }
    
    // Branch to relative address offset
    offset := u32(instr.offset) << 2
    if offset >> 25 == 0b1 { // sign extend
        offset |= 0xFC00_0000
    }
    regfile.pc += offset
}

@(private = "file")
execute_move_immediate :: proc(regfile: ^Register_File, machine_word: u32le) {
    instr := auras.Move_Immediate_Encoding(machine_word)

    imm: u32 = u32(instr.immediate)
    if instr.m {
        imm |= 0xFF00_0000
    }

    register_write(regfile, instr.rd, imm)
}
