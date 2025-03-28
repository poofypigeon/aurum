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

original_mode: posix.termios

enable_raw_mode :: proc() {
    posix.tcgetattr(posix.STDIN_FILENO, &original_mode)

    raw := original_mode
    raw.c_lflag -= { .ECHO, .ICANON }
    res := posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw)
    assert(res == .OK)
}

disable_raw_mode :: proc "c" () {
    posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &original_mode)
}

main :: proc() {
    enable_raw_mode()
    posix.atexit(disable_raw_mode)

    if len(os.args) < 2 {
        fmt.eprintln("missing file")
        os.exit(0)
    }

    file_path := os.args[1]
    file, err := os.open(file_path)
    if err != nil {
        os.print_error(os.stderr, err, "error")
        os.exit(1)
    }

    data, success := os.read_entire_file_from_handle(file)
    if !success {
        fmt.eprintln("failed to read file")
        os.exit(1)
    }

    code, ok := auras.code_from_text(string(data))
    if !ok { os.exit(1) }

    // rt := runtime_from_code_section(code, 1 << 24)
    rt := runtime_from_code_section(code, 4096)
    auras.code_section_cleanup(&code)

    rt.step_through = true

    run(&rt, []Aurum_Hook{ aurum_write, aurum_halt })
}
