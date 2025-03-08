package aurum

import "core:mem"
import "core:slice"
import "core:fmt"
import "auras"

main :: proc() {
    msg := []u8{ 'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', '!', '\n', 5,3,35,16 }
    memory := Memory_Space{ raw_bytes = slice.to_bytes(msg) }
    regfile := register_file_init()
    register_write(&regfile, 2, 0)
    register_write(&regfile, 3, 13)
    machine_word := auras.encode_machine_word("swi 0 ; write")

    err := execute_instruction(&regfile, &memory, machine_word, []Aurum_Hook{aurum_write})
    if err != nil {
        fmt.println("error:", err)
    }
}
