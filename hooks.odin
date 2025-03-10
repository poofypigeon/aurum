package aurum

import "core:fmt"
import "core:os"

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
      
        // TODO deal with fd

        if buf > u32(len(memory.raw_bytes)) {
            register_file.gpr[0] = 0
            return
        }

        written := string(memory.raw_bytes[buf:min(buf + count, u32(len(memory.raw_bytes)))])
        fmt.print(written) 
        register_file.gpr[0] = u32(len(written))
    }
}

aurum_halt :: Aurum_Hook{
    mask    = SYSCALL_MASK,
    pattern = 1,
    action  = proc(register_file: ^Register_File, memory: ^Memory_Space) {
        os.exit(0)
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
