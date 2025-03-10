#+private

package aurum

import "core:mem"
import "core:slice"
import "core:testing"

import "auras"


//===----------------------------------------------------------===//
//    Data Transfer Instructions
//===----------------------------------------------------------===//


// ld


@(test)
test_data_transfer_ld_bus_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 2, 4)

    machine_word := auras.encode_machine_word("ld r1, [r2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, Exception.Bus_Fault)
}

@(test)
test_data_transfer_ld_usage_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 2, 2)

    machine_word := auras.encode_machine_word("ld r1, [r2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, Exception.Usage_Fault)
}

@(test)
test_data_transfer_ld_base_address :: proc(t: ^testing.T) {
    memory_buffer := []u32{ 0xDEAD_BEEF }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := Register_File{}
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 0)
}

@(test)
test_data_transfer_ld_immediate_offset :: proc(t: ^testing.T) {
    memory_buffer := []u32{ 0x0000_0000, 0xDEAD_BEEF }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := Register_File{}
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2 + 4]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 0)
}

@(test)
test_data_transfer_ld_immediate_offset_with_shift :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0x0000_0000, 0xDEAD_BEEF }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := Register_File{}
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2 + 1 lsl 2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 0)
}

@(test)
test_data_transfer_ld_immediate_negative_offset :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0xDEAD_BEEF, 0x0000_0000 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := Register_File{}
    register_write(&regfile, 2, 4)

    machine_word := auras.encode_machine_word("ld r1, [r2 - 4]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 4)
}

@(test)
test_data_transfer_ld_negative_register_offset_with_shift :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0xDEAD_BEEF, 0x0000_0000 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := Register_File{}
    register_write(&regfile, 2, 4)
    register_write(&regfile, 3, 1)

    machine_word := auras.encode_machine_word("ld r1, [r2 - r3 lsl 2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 4)
    testing.expect_value(t, register_read(&regfile, 3), 1)
}

@(test)
test_data_transfer_ld_pre_increment :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0x1111_1111, 0x2222_2222 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := Register_File{}
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2 + 4]!")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x2222_2222)
    testing.expect_value(t, register_read(&regfile, 2), 4)
}

@(test)
test_data_transfer_ld_post_increment :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0x1111_1111, 0x2222_2222 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := Register_File{}
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2] + 4")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x1111_1111)
    testing.expect_value(t, register_read(&regfile, 2), 4)
}

@(test)
test_data_transfer_ldh_usage_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 2, 1)

    machine_word := auras.encode_machine_word("ldh r1, [r2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, Exception.Usage_Fault)
}

@(test)
test_data_transfer_ldh :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x11, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("ldh r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_2211)
}

@(test)
test_data_transfer_ldh_halfword_aligned :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x11, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := Register_File{}
    register_write(&regfile, 2, 2)

    machine_word := auras.encode_machine_word("ldh r1, [r2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_4433)
}

@(test)
test_data_transfer_ldh_sign_bit :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x00, 0x80, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("ldh r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_8000)
}

@(test)
test_data_transfer_ldsh_sign_bit :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x00, 0x80, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("ldsh r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xFFFF_8000)
}

@(test)
test_data_transfer_ldb :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x11, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("ldb r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0011)
}

@(test)
test_data_transfer_ldb_byte_aligned :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x11, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := Register_File{}
    register_write(&regfile, 2, 1)

    machine_word := auras.encode_machine_word("ldb r1, [r2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0022)
}

@(test)
test_data_transfer_ldb_sign_bit :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x80, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("ldb r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0080)
}

@(test)
test_data_transfer_ldsb_sign_bit :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x80, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("ldsb r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xFFFF_FF80)
}


// st


@(test)
test_data_transfer_st_bus_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 1, 4)

    machine_word := auras.encode_machine_word("st r0, [r1]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, Exception.Bus_Fault)
}

@(test)
test_data_transfer_st_usage_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 1, 2)

    machine_word := auras.encode_machine_word("st r0, [r1]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, Exception.Usage_Fault)
}

@(test)
test_data_transfer_st :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 1, 0xDECAF)

    machine_word := auras.encode_machine_word("st r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, (^u32le)(slice.as_ptr(memory.raw_bytes))^, u32le(0xDECAF))
}

@(test)
test_data_transfer_sth_usage_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 1, 1)

    machine_word := auras.encode_machine_word("sth r0, [r1]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, Exception.Usage_Fault)
}

@(test)
test_data_transfer_sth :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 1, 0xCAFE)

    machine_word := auras.encode_machine_word("sth r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, (^u32le)(slice.as_ptr(memory.raw_bytes))^, u32le(0xCAFE))
}

@(test)
test_data_transfer_sth_halfword_aligned :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 1, 0xCAFE)
    register_write(&regfile, 2, 2)

    machine_word := auras.encode_machine_word("sth r1, [r2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, (^u32le)(slice.as_ptr(memory.raw_bytes))^, u32le(0xCAFE_0000))
}

@(test)
hest_data_transfer_stb :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 1, 0xAF)

    machine_word := auras.encode_machine_word("sth r1, [r0]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, (^u32le)(slice.as_ptr(memory.raw_bytes))^, u32le(0xAF))
}

@(test)
test_data_transfer_stb_halfword_aligned :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := Register_File{}
    register_write(&regfile, 1, 0xAF)
    register_write(&regfile, 2, 1)

    machine_word := auras.encode_machine_word("stb r1, [r2]")
    branch_address := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, (^u32le)(slice.as_ptr(memory.raw_bytes))^, u32le(0x0000_AF00))
}


//===----------------------------------------------------------===//
//    Move from PSR and set/clear PSR bits instructions
//===----------------------------------------------------------===//


@(test)
test_move_from_psr_default_value :: proc(t: ^testing.T) {
    regfile := register_file_init()

    machine_word := auras.encode_machine_word("smv r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xF0)
}

@(test)
test_set_clear_psr_bits_privileged_supervisor_immediate :: proc(t: ^testing.T) {
    regfile := register_file_init()
    machine_word: u32 = ---
    branch_address: Branch_Address = ---

    // Clear I bit from supervisor bank
    machine_word = auras.encode_machine_word("scl 0x15")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0xE0)
    testing.expect_value(t, u32(regfile.psr[0]), 0xF0)
    
    // Set I, V, and Z bits in supervisor bank
    machine_word = auras.encode_machine_word("sst 0x15")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0xF5)
    testing.expect_value(t, u32(regfile.psr[0]), 0xF0)
}

@(test)
test_set_clear_psr_bits_privileged_system_immediate :: proc(t: ^testing.T) {
    regfile := register_file_init()
    machine_word: u32 = ---
    branch_address: Branch_Address = ---

    // Clear S bit, switching to user/system bank (P bit remains set)
    machine_word = auras.encode_machine_word("scl 0x40")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0xB0)
    testing.expect_value(t, u32(regfile.psr[0]), 0xB0)
    
    // Clear I bit from user/system bank
    machine_word = auras.encode_machine_word("scl 0x15")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0xB0)
    testing.expect_value(t, u32(regfile.psr[0]), 0xA0)

    // Set I, V, and Z bits in supervisor bank
    machine_word = auras.encode_machine_word("sst 0x15")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0xB0)
    testing.expect_value(t, u32(regfile.psr[0]), 0xB5)
}

@(test)
test_set_clear_psr_bits_user_immediate :: proc(t: ^testing.T) {
    regfile := register_file_init()
    machine_word: u32 = ---
    branch_address: Branch_Address = ---

    // Clear S bit, switching to user/system bank (P bit remains set)
    machine_word = auras.encode_machine_word("scl 0x40")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0xB0)
    testing.expect_value(t, u32(regfile.psr[0]), 0xB0)
    
    // Clear P, (S), and I bits of system/user bank, switching from system to user mode
    machine_word = auras.encode_machine_word("scl 0xD0")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, 0)
    testing.expect_value(t, u32(regfile.psr[1]), 0x30)
    testing.expect_value(t, u32(regfile.psr[0]), 0x20)

    // Set V and Z bits in user/system bank -- ensure protected bits are not updated
    machine_word = auras.encode_machine_word("sst 0xE5")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0x30)
    testing.expect_value(t, u32(regfile.psr[0]), 0x25)
}

@(test)
test_set_clear_psr_bits_user_register :: proc(t: ^testing.T) {
    regfile := register_file_init()
    machine_word: u32 = ---
    branch_address: Branch_Address = ---

    // Clear S bit, switching to user/system bank (P bit remains set)
    register_write(&regfile, 1, 0x40)
    machine_word = auras.encode_machine_word("scl r1")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0xB0)
    testing.expect_value(t, u32(regfile.psr[0]), 0xB0)
    
    // Clear P, (S), and I bits of system/user bank, switching from system to user mode
    register_write(&regfile, 1, 0xD0)
    machine_word = auras.encode_machine_word("scl r1")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, 0)
    testing.expect_value(t, u32(regfile.psr[1]), 0x30)
    testing.expect_value(t, u32(regfile.psr[0]), 0x20)

    // Set V and Z bits in user/system bank -- ensure protected bits are not updated
    register_write(&regfile, 1, 0xE5)
    machine_word = auras.encode_machine_word("sst r1")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, u32(regfile.psr[1]), 0x30)
    testing.expect_value(t, u32(regfile.psr[0]), 0x25)
}

@(test)
test_move_from_psr_user :: proc(t: ^testing.T) {
    regfile := register_file_init()
    machine_word: u32 = ---
    branch_address: Branch_Address = ---

    regfile.lr[1] = 0xCAFE

    // Clear S and P bits, switching to user mode
    machine_word = auras.encode_machine_word("scl 0xC0")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, 0xCAFE)

    // Set V and Z bits in user/system bank
    machine_word = auras.encode_machine_word("sst 0x05")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)

    machine_word = auras.encode_machine_word("smv r1")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x35)
}


//===----------------------------------------------------------===//
//    Data processing instructions
//===----------------------------------------------------------===//


// lsl


@(test)
test_data_processing_lsl_by_0 :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true } }
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("lsl r1, r2, 0")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), rhs)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lsl_by_less_than_32_cout1 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("lsl r1, r2, 1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), rhs << 1)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lsl_by_less_than_32_cout0 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("lsl r1, r2, 2")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), rhs << 2)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lsl_by_32 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 32)

    machine_word := auras.encode_machine_word("lsl r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_lsl_by_more_than_32 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 64)

    machine_word := auras.encode_machine_word("lsl r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}


// lslk


@(test)
test_data_processing_lslk_by_0 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("lslk r1, r2, 0")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), rhs)
    // flags unmodified for k variant instructions
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lslk_by_less_than_32_cout1 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("lslk r1, r2, 1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    // flags unmodified for k variant instructions
    testing.expect_value(t, register_read(&regfile, 1), rhs << 1)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lslk_by_less_than_32_cout0 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("lslk r1, r2, 2")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    // flags unmodified for k variant instructions
    testing.expect_value(t, register_read(&regfile, 1), rhs << 2)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lslk_by_32 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 32)

    machine_word := auras.encode_machine_word("lslk r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lslk_by_more_than_32 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 64)

    machine_word := auras.encode_machine_word("lslk r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


// lsr


@(test)
test_data_processing_lsr_by_0_is_lsr_by_32 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 3, rhs)
    register_write(&regfile, 4, 32)
    machine_word: u32 = ---
    branch_address: Branch_Address = ---

    machine_word = auras.encode_machine_word("lsr r1, r3, r0")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    testing.expect_value(t, branch_address, nil)
    psr1 := active_psr_bank(&regfile)

    machine_word = auras.encode_machine_word("lsr r2, r3, r4")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    testing.expect_value(t, branch_address, nil)
    psr2 := active_psr_bank(&regfile)
    
    testing.expect_value(t, register_read(&regfile, 1), register_read(&regfile, 1))
    testing.expect_value(t, psr1, psr2)
}

@(test)
test_data_processing_lsr_by_less_than_32_cout1 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("lsr r1, r2, 1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), rhs >> 1)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lsr_by_less_than_32_cout0 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("lsr r1, r2, 2")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), rhs >> 2)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_lsr_by_32 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 32)

    machine_word := auras.encode_machine_word("lsr r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_lsr_by_more_than_32 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 64)

    machine_word := auras.encode_machine_word("lsr r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}


// asr


@(test)
test_data_processing_asr_by_0_is_asr_by_32 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 3, rhs)
    register_write(&regfile, 4, 32)
    machine_word: u32 = ---
    branch_address: Branch_Address = ---

    machine_word = auras.encode_machine_word("asr r1, r3, r0")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    testing.expect_value(t, branch_address, nil)
    psr1 := active_psr_bank(&regfile)

    machine_word = auras.encode_machine_word("asr r2, r3, r4")
    branch_address = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    testing.expect_value(t, branch_address, nil)
    psr2 := active_psr_bank(&regfile)
    
    testing.expect_value(t, register_read(&regfile, 1), register_read(&regfile, 1))
    testing.expect_value(t, psr1, psr2)
}

@(test)
test_data_processing_asr_by_less_than_32_positive_cout1 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0x2AAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("asr r1, r2, 1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), rhs >> 1)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_asr_by_less_than_32_positive_cout0 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0x2AAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("asr r1, r2, 2")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), rhs >> 2)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_asr_by_less_than_32_negative_cout1 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("asr r1, r2, 1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), (rhs >> 1) | 0x8000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_asr_by_less_than_32_negative_cout0 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)

    machine_word := auras.encode_machine_word("asr r1, r2, 2")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), (rhs >> 2) | 0xC000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_asr_by_32_positive :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0x2AAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 32)

    machine_word := auras.encode_machine_word("asr r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_asr_by_32_negative :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 32)

    machine_word := auras.encode_machine_word("asr r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xFFFF_FFFF)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_asr_by_more_than_32_positive :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0x2AAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 64)

    machine_word := auras.encode_machine_word("asr r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_asr_by_more_than_32_negative :: proc(t: ^testing.T) {
    regfile := Register_File{}
    rhs: u32 = 0xAAAA_5555
    register_write(&regfile, 2, rhs)
    register_write(&regfile, 3, 64)

    machine_word := auras.encode_machine_word("asr r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xFFFF_FFFF)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


// add


@(test)
test_data_processing_add_no_flags :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0xCAFE)
    register_write(&regfile, 3, 0xFACADE)

    machine_word := auras.encode_machine_word("add r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE + 0xFACADE)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_add_cvz :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x8000_0000)
    register_write(&regfile, 3, 0x8000_0000)

    machine_word := auras.encode_machine_word("add r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, true)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_add_vn :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x4000_0000)
    register_write(&regfile, 3, 0x4000_0000)

    machine_word := auras.encode_machine_word("add r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x8000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, true)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_addk :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x8000_0000)
    register_write(&regfile, 3, 0x8000_0000)

    machine_word := auras.encode_machine_word("addk r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_add_shift :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x1)

    machine_word := auras.encode_machine_word("add r1, r0, r2 lsl 31")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x8000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


// adc 


@(test)
test_data_processing_adc_cin0 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0xCAFE)
    register_write(&regfile, 3, 0xFACADE)

    machine_word := auras.encode_machine_word("adc r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE + 0xFACADE)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_adc_cin1 :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true } }
    register_write(&regfile, 2, 0xCAFE)
    register_write(&regfile, 3, 0xFACADE)

    machine_word := auras.encode_machine_word("adc r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE + 0xFACADE + 1)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


// sub


@(test)
test_data_processing_sub_lhs_gt_rhs :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 1234)
    register_write(&regfile, 3, 10)

    machine_word := auras.encode_machine_word("sub r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 1234 - 10)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_sub_lhs_lt_rhs :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 10)
    register_write(&regfile, 3, 1234)

    machine_word := auras.encode_machine_word("sub r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), ~u32(1234 - 10) + 1) // -1234
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, true)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_sub_cvz :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x8000_0000)
    register_write(&regfile, 3, ~u32(0x8000_0000) + 1) // -0x8000_0000 == 0x8000_0000

    machine_word := auras.encode_machine_word("sub r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, true)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_sub_n :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x4000_0000)
    register_write(&regfile, 3, ~u32(0x4000_0000) + 1) // -0x4000_0000

    machine_word := auras.encode_machine_word("sub r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x8000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_subk :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x8000_0000)
    register_write(&regfile, 3, ~u32(0x8000_0000) + 1)

    machine_word := auras.encode_machine_word("subk r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_sub_shift :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, ~u32(0x1) + 1) // -1

    machine_word := auras.encode_machine_word("sub r1, r0, r2 lsl 31")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x8000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


// sbc 


@(test)
test_data_processing_sbc_cin1 :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true } }
    register_write(&regfile, 2, 0xCAFE)
    register_write(&regfile, 3, ~u32(0xFACADE) + 1) // -0xFACADE

    machine_word := auras.encode_machine_word("sbc r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE + 0xFACADE)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_sbc_cin0 :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0xCAFE)
    register_write(&regfile, 3, ~u32(0xFACADE) + 1) // -0xFACADE

    machine_word := auras.encode_machine_word("sbc r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE + 0xFACADE - 1)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


// and


@(test)
test_data_processing_and_cv_no_update :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true, v = true } }
    register_write(&regfile, 2, 0xCAFE)
    register_write(&regfile, 3, 0xFACADE)

    machine_word := auras.encode_machine_word("and r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE & 0xFACADE)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, true)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_and_n :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x8000_0000)
    register_write(&regfile, 3, 0x8000_0000)

    machine_word := auras.encode_machine_word("and r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x8000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_and_z :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("and r1, r0, r0")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_andk_z :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("andk r1, r0, r0")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


// or


@(test)
test_data_processing_or_cv_no_update :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true, v = true } }
    register_write(&regfile, 2, 0xCAFE)
    register_write(&regfile, 3, 0xFACADE)

    machine_word := auras.encode_machine_word("or r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE | 0xFACADE)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, true)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_or_n :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x8000_0000)

    machine_word := auras.encode_machine_word("or r1, r0, r2")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x8000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_or_z :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("or r1, r0, r0")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_ork_z :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("ork r1, r0, r0")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


// xor


@(test)
test_data_processing_xor_cv_no_update :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true, v = true } }
    register_write(&regfile, 2, 0xCAFE)
    register_write(&regfile, 3, 0xFACADE)

    machine_word := auras.encode_machine_word("xor r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE ~ 0xFACADE)
    testing.expect_value(t, active_psr_bank(&regfile).c, true)
    testing.expect_value(t, active_psr_bank(&regfile).v, true)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_xor_n :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x8000_0000)

    machine_word := auras.encode_machine_word("xor r1, r0, r2")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x8000_0000)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, true)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}

@(test)
test_data_processing_xor_z :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 2, 0x8000_0000)
    register_write(&regfile, 3, 0x8000_0000)

    machine_word := auras.encode_machine_word("xor r1, r2, r3")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, true)
}

@(test)
test_data_processing_xork_z :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("xork r1, r0, r0")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0)
    testing.expect_value(t, active_psr_bank(&regfile).c, false)
    testing.expect_value(t, active_psr_bank(&regfile).v, false)
    testing.expect_value(t, active_psr_bank(&regfile).n, false)
    testing.expect_value(t, active_psr_bank(&regfile).z, false)
}


//===----------------------------------------------------------===//
//    Software intbranch_addressupt instruction
//===----------------------------------------------------------===//


@(test)
test_software_interrupt :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("swi 0xCAFE")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, Exception.Syscall)
}


//===----------------------------------------------------------===//
//    Branch instruction
//===----------------------------------------------------------===//


@(test)
test_branch_relative_offset_positive :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("b label")
    ((^auras.Branch_Encoding)(&machine_word)^).offset = 24 >> 2
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_relative_offset_negative :: proc(t: ^testing.T) {
    regfile := Register_File{ pc = 24 }

    machine_word := auras.encode_machine_word("b label")
    ((^auras.Branch_Encoding)(&machine_word)^).offset = ~(u32(12 - 1) >> 2) // -12 >> 2
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 12)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_register_offset :: proc(t: ^testing.T) {
    regfile := Register_File{}
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("b r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_bl :: proc(t: ^testing.T) {
    regfile := Register_File{ pc = 24 }

    machine_word := auras.encode_machine_word("bl label")
    ((^auras.Branch_Encoding)(&machine_word)^).offset = ~(u32(12 - 1) >> 2) // -12 >> 2
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 12)
    testing.expect_value(t, active_lr(&regfile)^, 24 + 4)
}

@(test)
test_branch_eq_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ z = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("beq r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_eq_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ z = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("beq r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_ne_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ z = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bne r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_ne_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ z = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bne r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_cs_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bcs r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_cs_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bcs r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_cc_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bcc r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_cc_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bcc r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_mi_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bmi r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_mi_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bmi r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_pl_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bpl r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_pl_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bpl r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_vs_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ v = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bvs r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_vs_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ v = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bvs r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_vc_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ v = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bvc r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_vc_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ v = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bvc r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_hi_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true, z = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bhi r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_hi_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = false, z = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bhi r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_ls_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = false, z = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bls r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_ls_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ c = true, z = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bls r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_ge_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true, v = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bge r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_ge_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true, v = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bge r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_lt_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true, v = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("blt r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_lt_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true, v = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("blt r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_gt_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true, v = true, z = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bgt r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_gt_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true, v = true, z = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("bgt r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_le_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true, v = false, z = true } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("ble r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, 24)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}

@(test)
test_branch_le_no_follow :: proc(t: ^testing.T) {
    regfile := Register_File{ psr = Program_Status_Register{ n = true, v = true, z = false } }
    register_write(&regfile, 1, 24)

    machine_word := auras.encode_machine_word("ble r1")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
    
    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, active_lr(&regfile)^, 0)
}


//===----------------------------------------------------------===//
//    Move immediate instruction
//===----------------------------------------------------------===//


@(test)
test_move_immediate_positive :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("mvi r1, 0xCAFE")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xCAFE)
}

@(test)
test_move_immediate_negative :: proc(t: ^testing.T) {
    regfile := Register_File{}

    machine_word := auras.encode_machine_word("mvi r1, -0xCAFE")
    branch_address := execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})

    testing.expect_value(t, branch_address, nil)
    testing.expect_value(t, register_read(&regfile, 1), ~u32(0xCAFE) + 1) // -0xCAFE
}
