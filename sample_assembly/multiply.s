_vectors:
    b _handler_reset
    b _handler_syscall
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
    scl 0xC0                ; reenter user mode

_handler_reset:
    mvi sp, 0xFFC           ; initialize supervisor stack pointer
    m32 lr, _start          ; set user entry point to _start
    scl 0x40                ; user bank
    mvi sp, 0x7FC           ; initialize user stack pointer
    scl 0xC0                ; enter user mode 

_handler_syscall:
    scl 0xC0                ; reenter user mode

_start:
; uword decimal
    m32 r2, 0xDECAF         
    sub sp, sp, 16          ; uword_to_dec_str buffer
    mov r1, sp
    bl uword_to_dec_str
    mvi r13, 10             ; ascii '\n'
    stb r13, [sp + r1]
    add r1, r1, 1
    mov r3, r1
    mov r2, sp
    mvi r1, 0
    swi 0                   ; write
    add sp, sp, 16
; sword decimal
    m32 r2, 0xDECAF         
    sub sp, sp, 16          ; uword_to_dec_str buffer
    mov r1, sp
    bl sword_to_dec_str
    mvi r13, 10             ; ascii '\n'
    stb r13, [sp + r1]
    add r1, r1, 1
    mov r3, r1
    mov r2, sp
    mvi r1, 0
    swi 0                   ; write
    add sp, sp, 16
; sword decimal
    m32 r2, -0xDECAF         
    sub sp, sp, 16          ; uword_to_dec_str buffer
    mov r1, sp
    bl sword_to_dec_str
    mvi r13, 10             ; ascii '\n'
    stb r13, [sp + r1]
    add r1, r1, 1
    mov r3, r1
    mov r2, sp
    mvi r1, 0
    swi 0                   ; write
    add sp, sp, 16
; uword hex
    m32 r2, 0xDECAF         
    sub sp, sp, 16          ; uword_to_dec_str buffer
    mov r1, sp
    bl uword_to_hex_str
    mvi r13, 10             ; ascii '\n'
    stb r13, [sp + r1]
    add r1, r1, 1
    mov r3, r1
    mov r3, r1
    mov r2, sp
    mvi r1, 0
    swi 0                   ; write
    add sp, sp, 16
    swi 1                   ; halt

; arg r1 is operand 1
; arg r2 is operand 2
; ret r1 is result
mul:
    mov r3, r1
    mvi r1, 0
    mvi r13, -1
mul_loop:
    cmp r2, 0
    beq lr
    add r13, r13, 1
    lsr r2, r2, 1
    bcc mul_loop
    add r1, r1, r3 lsl r13
    b mul_loop

; arg r1 is destination pointer (at least 10 bytes)
; arg r2 is value
; ret r1 is length
uword_to_dec_str:
    mov r3, r1              ; destination pointer
    m32 r4, base10_digits   ; base10_digits pointer
    mvi r6, 0               ; first non-zero digit seen?
uword_to_dec_str_outer_loop:
    ld r5, [r4] + 4         ; load current digit magnitude
    cmp r5, 0               ; test for sentinal
    beq uword_to_dec_str_done
    mvi r13, 0              ; initialize current digit
uword_to_dec_str_inner_loop:
    cmp r2, r5
    bcc uword_to_dec_str_write_digit
    sub r2, r2, r5
    add r13, r13, 1
    b uword_to_dec_str_inner_loop
uword_to_dec_str_write_digit:
    cmp r13, r6             ; if zero, and first non-zero digit not seen and digit is zero, skip
    beq uword_to_dec_str_outer_loop
    add r6, r13, 48         ; ascii '0'
                            ; now r13 [0-9] will never equal r6 [48-57]
    stb r6, [r1] + 1
    b uword_to_dec_str_outer_loop
uword_to_dec_str_done:
    sub r1, r1, r3          ; calculate length
    b lr
base10_digits:
    word 1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1
    word 0                  ; sentinal value

; arg r1 is destination pointer (at least 11 bytes)
; arg r2 is value
; ret r1 is length
sword_to_dec_str:
    push lr                 ; push link address
    push r1                 ; push original destination pointer
    tst r2, -1              ; test if negative
    bpl sword_to_dec_str_pos; value is positive
    mvi r13, 45             ; ascii '-'
    stb r13, [r1] + 1
    not r2, r2              ; one's complement
    add r2, r2, 1           ; two's complement
sword_to_dec_str_pos:
    bl uword_to_dec_str
    pop r13                 ; pop original destination pointer
    pop lr                  ; pop link address
    ldb r13, [r13]          ; load first char of string
    cmp r13, 45             ; test if char is ascii '-'
    bne lr
    add r1, r1, 1           ; +1 length for minus sign
    b lr

; arg r1 is destination pointer (at least 8 bytes)
; arg r2 is value
; ret r1 is length
uword_to_hex_str:
    mov r3, r1              ; destination pointer
    mvi r13, 28             ; right shift amount
    mvi r4, 0xF             ; mask
uword_to_hex_str_loop:
    and r5, r4, r2 lsr r13  ; mask out digit
    add r5, r5, 48          ; ascii '0'
    cmp r5, 57              ; ascii '9'
    bls uword_to_hex_str_write_digit
    add r5, r5, 7           ; ascii 'A' - '9'
uword_to_hex_str_write_digit:
    stb r5, [r1] + 1
    cmp r13, 0
    beq uword_to_hex_str_done
    sub r13, r13, 4
    b uword_to_hex_str_loop
uword_to_hex_str_done:
    sub r1, r1, r3          ; calculate length
    b lr


