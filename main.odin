package aurum

// TODO test swi flags
// TODO test swi lr
// TODO test ascii length with newlines/tabs

import "core:fmt"
import "core:os"

import "auras"
HELLO_WORLD :: `
_vec_none:
    mvi sp, 0x3FFF
_vec_reset:
    b _handler_reset
_vec_syscall:
    b _handler_syscall
_vec_bus_fault:
    nop
_vec_usage_fault:
    nop
_vec_instruction:
    nop
_vec_systick:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
_vec_irq0:
    nop
_vec_irq1:
    nop
_vec_irq2:
    nop
_vec_irq3:
    nop
_vec_irq4:
    nop
_vec_irq5:
    nop
_vec_irq6:
    nop
_vec_irq7:
    nop

_handler_reset:
    m32 lr, hello_world ; set user entry point to hello_world
    scl 0xC0            ; enter user mode 

_handler_syscall:
    scl 0xC0            ; reenter user mode

hello_world:
    mvi r1, 0
    m32 r2, hello_world_string
    ld  r3, [r2] + 4
    swi 0
    swi 1
    
hello_world_string:
    word * ascii "Hello world!\n"

    align 0x4000
`

main :: proc() {
    file := auras.create_source_file()
    defer auras.cleanup_source_file(&file)

    if !auras.process_text(&file, HELLO_WORLD) {
        fmt.println("goodbye.")
        os.exit(1)
    }


    run(file.buffer[:], { aurum_write, aurum_halt })
}
