package aurum

import "core:fmt"
import "core:os"
import "core:sys/posix"

Aurum_Hook :: struct {
    mask: u32,
    pattern: u32,
    action: proc(^Register_File, ^Memory_Space)
}

SYSCALL_MASK :: 0xE000_0000

SYSCALL_ID_WRITE :: 0
SYSCALL_ID_READ  :: 1

aurum_write :: Aurum_Hook{
    mask    = SYSCALL_MASK,
    pattern = SYSCALL_ID_WRITE,
    action  = proc(register_file: ^Register_File, memory: ^Memory_Space) {
        fd    := register_file.gpr[0] // r1
        buf   := register_file.gpr[1] // r2
        count := register_file.gpr[2] // r3

        if fd > 1 { return }

        if buf > u32(len(memory.physical)) {
            register_file.gpr[0] = 0
            return
        }

        written := memory.physical[buf:min(buf + count, u32(len(memory.physical)))]
        append_string(&core_stdout, string(written))
        register_file.gpr[0] = u32(len(written))
    }
}

aurum_halt :: Aurum_Hook{
    mask    = SYSCALL_MASK,
    pattern = 1,
    action  = proc(register_file: ^Register_File, memory: ^Memory_Space) {
        halt = true
    }
}

// aurum_read :: Aurum_Hook{
//     mask    = SYSCALL_MASK,
//     pattern = SYSCALL_ID_WRITE,
//     action  = proc(register_file: ^Register_File, memory: ^Memory_Space) {
//         fd    := register_file.gpr[0] // r1
//         buf   := register_file.gpr[1] // r2
//         count := register_file.gpr[2] // r3
//
//         // TODO
//     }
// }
//
