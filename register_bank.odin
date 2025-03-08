package aurum

import "core:mem"

WORD_SIZE :: size_of(u32)

Exception :: enum {
    None        =  0,
    Reset       =  4,
    Syscall     =  8,
    Bus_Fault   = 12,
    Usage_Fault = 16,
    Instruction = 20,
    Divide_Zero = 24,
    Systick     = 28,
    _           = 32,
    _           = 36,
    _           = 40,
    _           = 44,
    _           = 48,
    _           = 52,
    _           = 56,
    _           = 60,
    IRQ0        = 64,
    IRQ1        = 68,
    IRQ2        = 72,
    IRQ3        = 76,
    IRQ4        = 80,
    IRQ5        = 84,
    IRQ6        = 88,
    IRQ7        = 92,
}

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

active_psr_bank :: #force_inline proc(register_file: ^Register_File) -> ^Program_Status_Register {
    return &register_file.psr[uint(register_file.psr[0].s)]
}

active_sp :: #force_inline proc(register_file: ^Register_File) -> ^u32 {
    return &register_file.sp[uint(register_file.psr[0].s)]
}

active_lr :: #force_inline proc(register_file: ^Register_File) -> ^u32 {
    return &register_file.lr[uint(register_file.psr[0].s)]
}

register_read :: #force_inline proc (register_file: ^Register_File, register: u32) -> u32 {
    bank := uint(register_file.psr[0].s)
    switch register {
    case 0: return 0
    case 1..=13: return register_file.gpr[register - 1]
    case 14: return register_file.sp[bank]
    case 15: return register_file.lr[bank]
    }
    panic("trying to read from invalid register")
}

register_write :: #force_inline proc (register_file: ^Register_File, register: u32, value: u32) {
    bank := uint(register_file.psr[0].s)
    switch register {
    case 0: return
    case 1..=13: register_file.gpr[register - 1] = value
    case 14: register_file.sp[bank] = value
    case 15: register_file.lr[bank] = value
    case: panic("trying to write to invalid register")
    }
}
