package aurum

// TODO test swi flags
// TODO test swi lr
// TODO test ascii length with newlines/tabs

import "core:fmt"
import "core:os"
import "core:slice"
import "core:sys/posix"
import "core:time"

import "auras"

core_stdout: [2]posix.FD

run_with_debugger := true

main :: proc() {
    term_canon: posix.termios
    posix.tcgetattr(posix.STDIN_FILENO, &term_canon)
    defer posix.tcsetattr(posix.STDIN_FILENO, .TCSADRAIN, &term_canon)

    term_raw := term_canon
    term_raw.c_lflag &~= { .ECHO, .ICANON }
    posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &term_raw)

    posix.pipe(&core_stdout)
    res := posix.fcntl(core_stdout[0], .SETFL, posix.O_Flags{ posix.O_Flag_Bits.NONBLOCK })
    defer posix.close(core_stdout[0])
    defer posix.close(core_stdout[1])

    file, err := os.open("hello_world.s")
    if err != nil {
        os.print_error(os.stderr, err, "error")
        os.exit(1)
    }

    data, success := os.read_entire_file_from_handle(file)
    if !success {
        fmt.eprintln("oops")
        os.exit(1)
    }

    program := auras.create_code_section()
    auras.process_text(&program, string(data))

    // TODO run core in seperate thread to prevent jams
    aurum_run(&program, []Aurum_Hook{ aurum_write, aurum_halt })
}
