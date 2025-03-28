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
    m32 r2, hello_world_string
    ld  r3, [r2] + 4
    swi 0
    swi 1
    
hello_world_string:
    word * ascii "Hello world!\n"
