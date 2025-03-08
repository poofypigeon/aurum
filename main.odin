package aurum

import "core:mem"
import "core:slice"
import "core:fmt"
import "auras"

main :: proc() {
    regfile := register_file_init()
    machine_word: u32le = ---
    err: Exception = ---

    // Clear I bit from supervisor bank
    machine_word = auras.encode_machine_word("scl 0x25")
    err = execute_instruction(&regfile, &Memory_Space{}, machine_word, []Aurum_Hook{})
}
