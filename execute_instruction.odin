package aurum

import "auras"

execute_instruction :: proc(register_file: ^Register_File, memory: ^Memory_Space, machine_word: u32le, hooks: []Aurum_Hook) -> Exception {
    switch machine_word >> 30 {
    case 0b00:
        if machine_word >> 15 & 0b11 == 0b11 {
            if ((machine_word >> 29) & 1) == 0b1 {
                if machine_word &~ 0x1F02_03FF != 0x2001_8000 { return nil }
                execute_set_clear_psr_bits(register_file, machine_word)
                return nil
            }
            if machine_word &~ 0x0F02_0000 != 0x0001_8000 { return nil }
            execute_move_from_psr(register_file, machine_word)
            return nil
        }
        return execute_data_transfer(register_file, machine_word)
    case 0b01:
        execute_data_processing(register_file, machine_word)
        return nil
    case 0b10:
        execute_branch(register_file, machine_word)
        return nil
    case 0b11:
        if machine_word >> 29 & 0b1 == 0b0 {
            execute_move_immediate(register_file, machine_word)
            return nil
        }
        return execute_software_interrupt(register_file, memory, machine_word, hooks)
    }
    panic("unreachable")
}

@(private = "file")
execute_data_transfer :: proc(register_file: ^Register_File, memory: ^Memory_Space, machine_word: u32le) -> Exception {
    instr := auras.Data_Transfer_Encoding(machine_word)

    base_address := register_read(register_file, instr.rm)

    assert(!(instr.b && instr.h))
    width: uint = (instr.b) ? 1 : (instr.h) ? 2 : 4
    offset := (instr.i) ? u32(instr.offset) : register_read(register_file, instr.offset)
    shift := instr.shift << 1
    offset <<= shift

    calculated_address := (instr.n) ? base_address - offset : base_address + offset
    effective_address := (instr.p) ? base_address : calculated_address
    writeback_address := (instr.p || instr.w) ? calculated_address : base_address

    register_write(register_file, instr.rm, writeback_address)

    if instr.s {
        return memory_write(memory, effective_address, width, register_read(register_file, instr.rd))
    }

    value := memory_read(memory, effective_address, width) or_return
    register_write(register_file, instr.rd, value)
    return nil
}

@(private = "file")
execute_move_from_psr :: proc(register_file: ^Register_File, machine_word: u32le) {
    instr := auras.Move_From_PSR_Encoding(machine_word)
    register_write(register_file, instr.rd, (^u32)(active_psr_bank(register_file))^)
}

@(private = "file")
execute_set_clear_psr_bits :: proc(register_file: ^Register_File, machine_word: u32le) {
    instr := auras.Set_Clear_PSR_Bits_Encoding(machine_word)
    bank := uint(register_file.psr[0].s)

    mask := (instr.i) ? u32(instr.operand) : u32(register_read(register_file, instr.operand))

    // User mode
    if !register_file.psr[bank].p {
        assert(!register_file.psr[bank].s)
        (^u32)(&register_file.psr[bank])^ |= (mask & 0x0F)
    }

    // Supervisor/system mode
    if instr.s {
        (^u32)(&register_file.psr[bank])^ |= (mask & 0xFF)
    } else {
        (^u32)(&register_file.psr[bank])^ |= ~(mask & 0xFF)

        // Clear S bit if P bit is cleared and reenter user mode
        if !register_file.psr[bank].p {
            register_file.psr[bank].s = false
            register_file.pc = register_file.lr[1]
        }
    }

    // Maintain continuity of P and S bits between banks
    register_file.psr[~bank].p = register_file.psr[bank].p
    register_file.psr[~bank].s = register_file.psr[bank].s

    // Keep supervisor T bit hardcoded high
    register_file.psr[1].t = true
}

@(private = "file")
execute_data_processing :: proc(register_file: ^Register_File, machine_word: u32le) {
    instr := auras.Data_Processing_Encoding(machine_word)
    psr := active_psr_bank(register_file)

    lhs := u32(register_read(register_file, instr.rm))
    rhs := (instr.i) ? u32(instr.operand2) : u32(register_read(register_file, instr.operand2))
    shift := (instr.h) ? uint(instr.shift) : uint(register_read(register_file, instr.shift))

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
    register_write(register_file, instr.rd, u32(result))

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
execute_software_interrupt :: proc(register_file: ^Register_File, memory: ^Memory_Space, machine_word: u32le, hooks: []Aurum_Hook) -> Exception {
    machine_word := u32(machine_word)

    for hook in hooks {
        if machine_word & hook.mask == hook.pattern {
            hook.action(register_file, memory)
        }
    }

    return .Syscall
}

@(private = "file")
execute_branch :: proc(register_file: ^Register_File, machine_word: u32le) {
    instr := auras.Branch_Encoding(machine_word)
    psr := active_psr_bank(register_file)

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
        active_lr(register_file)^ = register_file.pc + WORD_SIZE
    }

    if !instr.i { // Branch to address in register (lowest two bits masked out)
        register_file.pc = register_read(register_file, instr.offset) &~ 0b11
        return
    }
    
    // Branch to relative address offset
    offset := u32(instr.offset) << 2
    if offset >> 25 == 0b1 { // sign extend
        offset |= 0xFC00_0000
    }
    register_file.pc += offset
}

@(private = "file")
execute_move_immediate :: proc(register_file: ^Register_File, machine_word: u32le) {
    instr := auras.Move_Immediate_Encoding(machine_word)

    imm: u32 = u32(instr.immediate)
    if instr.m {
        imm |= 0xFF00_0000
    }

    register_write(register_file, instr.rd, imm)
}
