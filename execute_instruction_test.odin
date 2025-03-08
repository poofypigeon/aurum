#+private

package aurum

import "core:mem"
import "core:slice"
import "core:testing"

import "auras"

@(test)
test_data_transfer_ld_bus_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := register_file_init()
    register_write(&regfile, 2, 4)

    machine_word := auras.encode_machine_word("ld r1, [r2]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, Exception.Bus_Fault)
}

@(test)
test_data_transfer_ld_usage_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := register_file_init()
    register_write(&regfile, 2, 2)

    machine_word := auras.encode_machine_word("ld r1, [r2]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, Exception.Usage_Fault)
}

@(test)
test_data_transfer_ld_base_address :: proc(t: ^testing.T) {
    memory_buffer := []u32{ 0xDEAD_BEEF }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := register_file_init()
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 0)
}

@(test)
test_data_transfer_ld_immediate_offset :: proc(t: ^testing.T) {
    memory_buffer := []u32{ 0x0000_0000, 0xDEAD_BEEF }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := register_file_init()
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2 + 4]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 0)
}

@(test)
test_data_transfer_ld_immediate_offset_with_shift :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0x0000_0000, 0xDEAD_BEEF }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := register_file_init()
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2 + 1 lsl 2]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 0)
}

@(test)
test_data_transfer_ld_immediate_negative_offset :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0xDEAD_BEEF, 0x0000_0000 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := register_file_init()
    register_write(&regfile, 2, 4)

    machine_word := auras.encode_machine_word("ld r1, [r2 - 4]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 4)
}

@(test)
test_data_transfer_ld_negative_register_offset_with_shift :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0xDEAD_BEEF, 0x0000_0000 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := register_file_init()
    register_write(&regfile, 2, 4)
    register_write(&regfile, 3, 1)

    machine_word := auras.encode_machine_word("ld r1, [r2 - r3 lsl 2]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xDEAD_BEEF)
    testing.expect_value(t, register_read(&regfile, 2), 4)
    testing.expect_value(t, register_read(&regfile, 3), 1)
}

@(test)
test_data_transfer_ld_pre_increment :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0x1111_1111, 0x2222_2222 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := register_file_init()
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2 + 4]!")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x2222_2222)
    testing.expect_value(t, register_read(&regfile, 2), 4)
}

@(test)
test_data_transfer_ld_post_increment :: proc(t: ^testing.T) {
    memory_buffer := []u32le{ 0x1111_1111, 0x2222_2222 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(memory_buffer) }
    regfile := register_file_init()
    register_write(&regfile, 2, 0)

    machine_word := auras.encode_machine_word("ld r1, [r2] + 4")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x1111_1111)
    testing.expect_value(t, register_read(&regfile, 2), 4)
}

@(test)
test_data_transfer_ldh_usage_fault :: proc(t: ^testing.T) {
    memory := Memory_Space{ raw_bytes = []u8{ 0, 0, 0, 0 } }
    regfile := register_file_init()
    register_write(&regfile, 2, 1)

    machine_word := auras.encode_machine_word("ldh r1, [r2]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, Exception.Usage_Fault)
}

@(test)
test_data_transfer_ldh :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x11, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := register_file_init()

    machine_word := auras.encode_machine_word("ldh r1, [r0]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_2211)
}

@(test)
test_data_transfer_ldh_halfword_aligned :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x11, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := register_file_init()
    register_write(&regfile, 2, 2)

    machine_word := auras.encode_machine_word("ldh r1, [r2]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_4433)
}

@(test)
test_data_transfer_ldh_sign_bit :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x00, 0x80, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := register_file_init()

    machine_word := auras.encode_machine_word("ldh r1, [r0]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_8000)
}

@(test)
test_data_transfer_ldsh_sign_bit :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x00, 0x80, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := register_file_init()

    machine_word := auras.encode_machine_word("ldsh r1, [r0]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xFFFF_8000)
}

@(test)
test_data_transfer_ldb :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x11, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := register_file_init()

    machine_word := auras.encode_machine_word("ldb r1, [r0]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0011)
}

@(test)
test_data_transfer_ldb_byte_aligned :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x11, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := register_file_init()
    register_write(&regfile, 2, 1)

    machine_word := auras.encode_machine_word("ldb r1, [r2]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0022)
}

@(test)
test_data_transfer_ldb_sign_bit :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x80, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := register_file_init()

    machine_word := auras.encode_machine_word("ldb r1, [r0]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0x0000_0080)
}

@(test)
test_data_transfer_ldsb_sign_bit :: proc(t: ^testing.T) {
    memory_buffer := []u8{ 0x80, 0x22, 0x33, 0x44 }
    memory := Memory_Space{ raw_bytes = memory_buffer }
    regfile := register_file_init()

    machine_word := auras.encode_machine_word("ldsb r1, [r0]")
    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{})

    testing.expect_value(t, err, nil)
    testing.expect_value(t, register_read(&regfile, 1), 0xFFFF_FF80)
}

// TODO
