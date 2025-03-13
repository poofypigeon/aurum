package aurum

// TODO test swi flags
// TODO test swi lr
// TODO test ascii length with newlines/tabs

import "core:fmt"
import "core:slice"
import "core:os"
import "core:time"
import "core:sys/posix"

import "auras"

main :: proc() {
    term_canon: posix.termios
    posix.tcgetattr(posix.STDIN_FILENO, &term_canon)
    defer posix.tcsetattr(posix.STDIN_FILENO, .TCSADRAIN, &term_canon)

    term_raw := term_canon
    term_raw.c_lflag &~= { .ECHO, .ICANON }
    posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &term_raw)

    file, err := os.open("hello_world.s")
    if err != nil {
        os.print_error(os.stderr, err, "error")
        os.exit(1)
    }

    data, success := os.read_entire_file_from_handle(file)
    if !success {
        fmt.eprintln("oops")
    }

    source_file := auras.create_source_file()
    auras.process_text(&source_file, string(data))

    slice.sort_by(source_file.symbol_table[:], cmp)

    regfile := register_file_init()

    for{
        // clear screen
        fmt.print("\033[2J")
        // cursor position
        fmt.print("\033[1;2H")
        rf_stream := regfile_stream(regfile)
        fmt.print(rf_stream)
        // cursor position
        fmt.print("\033[1;18H")
        dis_stream := disassembly_stream(regfile, source_file, 23)
        fmt.print(dis_stream)
        delete(dis_stream)

        buf: [1]u8
        os.read(os.stdin, buf[:])
        regfile.pc += 4
    }

    cmp :: proc(i: auras.Symbol_Table_Entry, j: auras.Symbol_Table_Entry) -> bool {
        return i.offset < j.offset
    }
}
