package aurum

import "auras"
import "term"

import "base:runtime"
import "core:encoding/ansi"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:sys/posix"
import "core:time"
import "core:unicode"

Runtime_State :: struct {
    regfile: Register_File,
    memory: Memory_Space,
    name_sorted_labels: []auras.Symbol_Table_Entry,
    offset_sorted_labels: []auras.Symbol_Table_Entry,
    raw_string_table: []u8,
    string_table: []string,
    breakpoints: [dynamic]u32,
    window_offset: int, // starting address of view window
    tracking_pc: bool,  // whether the view window is locked to the PC
    step_through: bool, // stop after next instruction run
}

// pseudo stdin that the emulator hooks into
core_stdin  : [dynamic]u8

// pseudo stdout that the emulator hooks into
core_stdout : [dynamic]u8

runtime_from_code_section :: proc(code: auras.Code_Section, memory_size: uint) -> Runtime_State {
    assert(uint(len(code.buffer)) <= memory_size) // TODO real error message
    memory := make([]u8, memory_size)
    copy_slice(memory, code.buffer[:])

    name_sorted_labels := slice.clone(code.symbol_table[:])

    raw_string_table := slice.clone(code.string_table[:])

    string_table := make_slice([]string, len(code.symbol_table))
    for symbol, i in code.symbol_table {
        string_table[i] = runtime.cstring_to_string(cstring(&raw_string_table[symbol.name]))
        name_sorted_labels[i].name = u32(i)
    }

    offset_sorted_labels := slice.clone(name_sorted_labels)
    slice.sort_by(offset_sorted_labels, less)

    return Runtime_State {
        regfile = register_file_init(),
        memory = Memory_Space{ physical = memory },
        name_sorted_labels = name_sorted_labels,
        raw_string_table = raw_string_table,
        string_table = string_table,
        offset_sorted_labels = offset_sorted_labels,
        breakpoints = make([dynamic]u32),
        window_offset = 0,
        tracking_pc = true,
        step_through = false,
    }

    less :: proc(i, j: auras.Symbol_Table_Entry) -> bool {
        return (i.offset < j.offset)
    }
}

halt := false

run :: proc(rt: ^Runtime_State, hooks: []Aurum_Hook) {
    for {
        interface(rt)
        if halt { return }
        execute_clock_cycle(&rt.regfile, &rt.memory, hooks)
    }
}

interface :: proc(rt: ^Runtime_State) {
    DISASSEMBLY_LINES :: 46 // TODO auto screen resize adjustments

    sb := strings.builder_make(0, 1024)
    defer strings.builder_destroy(&sb)

    if !rt.step_through && !halt {
        for bp in rt.breakpoints {
            if rt.regfile.pc == bp {
                rt.step_through = true
            }
        }

        // core stdout
        term.set_cursor_pos(&sb, 91, 1)
        write_core_stdout(&sb)
        // cursor to command line
        term.set_cursor_pos(&sb, 1, 48)
        os.write_string(os.stdout, strings.to_string(sb))

        if !rt.step_through { return }
    }

    term.clear_screen(&sb)
    term.set_cursor_pos(&sb, 1, 1)
    write_regfile(&sb, &rt.regfile)

    os.write_string(os.stdout, strings.to_string(sb))

    if rt.tracking_pc {
        rt.window_offset = int(rt.regfile.pc)
    }

    c: [1]u8
    redraw := true
    user_input: for {
        if redraw {
            redraw = false
            strings.builder_reset(&sb)
            // disassembly
            term.set_cursor_pos(&sb, 17, 1)
            write_disassembly(&sb, rt, rt.window_offset, DISASSEMBLY_LINES)
            // core stdout
            term.set_cursor_pos(&sb, 91, 1)
            write_core_stdout(&sb)
            // cursor to command line
            term.set_cursor_pos(&sb, 1, 48)
            os.write_string(os.stdout, strings.to_string(sb))

            // final print without user input
            if halt { return }
        }
        os.read(os.stdin, c[:])
        switch c[0] {
        case 's':
            break user_input
        case 'R':
            rt.step_through = false
            break user_input
        case 'j': // view window down
            rt.tracking_pc = false
            if rt.window_offset < len(rt.memory.physical) - 4 {
                rt.window_offset += 4
            }
            redraw = true
        case 'k': // view window up
            rt.tracking_pc = false
            if rt.window_offset > 0 {
                rt.window_offset -= 4
            }
            redraw = true
        // TODO arrow keys
        case 'd'-'a'+1: // <Ctrl-D> window down by half page
            rt.tracking_pc = false
            rt.window_offset += 4 * (DISASSEMBLY_LINES / 2)
            rt.window_offset = min(rt.window_offset, len(rt.memory.physical) - 4)
            redraw = true
        case 'u'-'a'+1: // <Ctrl-U> window up by half page
            rt.tracking_pc = false
            rt.window_offset -= 4 * (DISASSEMBLY_LINES / 2)
            rt.window_offset = max(rt.window_offset, 0)
            redraw = true
        case 'c': // track pc
            rt.tracking_pc = true
            rt.window_offset = int(rt.regfile.pc)
            redraw = true
        case ':':
            redraw = command(rt)
        case '/':
            // search(rt) TODO
        }
    }

    return
}

command :: proc(rt: ^Runtime_State) -> (redraw: bool) {
    // TODO command history and move cursor left/right

    term.clear_line()
    term.set_cursor_col(1)
    os.write_byte(os.stdout, ':')

    sb := strings.builder_make(0, 32)
    defer strings.builder_destroy(&sb)

    c: [1]u8
    user_input: for {
        os.read(os.stdin, c[:])
        switch c {
        case '\b', '\177': // backspace, delete
            if strings.builder_len(sb) == 0 { continue }
            resize(&sb.buf, strings.builder_len(sb) - 1)
            // remove trailing character from line
            term.move_cursor(ansi.CUB)
            term.clear_cursor_to_line_end()
        case '\e': // escape
            term.clear_line()
            term.set_cursor_col(1)
            return
        case '\n':
            break user_input
        case:
            strings.write_byte(&sb, c[0])
            os.write_byte(os.stdout, c[0])
        }
    }

    command := auras.Tokenizer{ line = strings.to_string(sb) }
    token, ok := auras.tokenizer_next(&command)
    if !ok { return }

    switch token {
    case "b":
        return breakpoint_command(rt, &command)
    case: 
        bad_value("Not a runtime command", token)
    }

    redraw = false
    return
}

breakpoint_command :: proc(rt: ^Runtime_State, command: ^auras.Tokenizer) -> (redraw: bool) {
    token, ok := auras.tokenizer_next(command)
    if !ok { return }

    remove := false
    switch token[0] {
    case '+': break
    case '-': remove = true
    case:
        bad_value("Unknown option", token)
        return
    }

    token, ok = auras.tokenizer_next(command)
    if !ok { return }

    address: u32 = ---
    parse_option: switch {
    case unicode.is_number(rune(token[0])):
        v: uint = ---
        v, ok = strconv.parse_uint(token)
        if !ok {
            bad_value("Unknown option", token)
            redraw = false
            return
        }
        address = u32(v)
    case unicode.is_alpha(rune(token[0])), token[0] == '_':
        for label, i in rt.string_table {
            if token == label {
                address = rt.name_sorted_labels[i].offset
                break parse_option
            }
        }
        bad_value("Label not found", token)
        redraw = false
        return
    case:
        bad_value("Unknown option", token)
        redraw = false
        return
    }

    term.clear_line()
    term.set_cursor_col(1)

    backing: [10]u8 = ---
    address_string := strings.builder_from_slice(backing[:])
    strings.write_string(&address_string, "0x")
    strings.write_uint(&address_string, uint(address), base = 16)

    breakpoint_index := -1
    for b, i in rt.breakpoints {
        if address == b {
            breakpoint_index = i
            break
        }
    }

    if remove {
        if breakpoint_index == -1 {
            bad_value("Breakpoint not found", strings.to_string(address_string))
            redraw = false
            return
        }
        unordered_remove(&rt.breakpoints, breakpoint_index)
        os.write_string(os.stdout, "Breakpoint removed at ")
        os.write_string(os.stdout, strings.to_string(address_string))
        rt.window_offset = int(address)
        redraw = true
        return
    }

    if breakpoint_index != -1 {
        bad_value("Breakpoint already exists", strings.to_string(address_string))
    } else {
        append(&rt.breakpoints, address)
        os.write_string(os.stdout, "Breakpoint added at ")
        os.write_string(os.stdout, strings.to_string(address_string))
    }
    
    rt.window_offset = int(address)
    redraw = true
    return
}

bad_value :: proc(message, value: string) {
    term.clear_line()
    term.set_cursor_col(1)
    term.set_text_style(ansi.BOLD, ansi.ITALIC, ansi.FG_BRIGHT_RED)
    os.write_string(os.stdout, message)
    os.write_string(os.stdout, ": ")
    os.write_string(os.stdout, value)
    term.set_text_style(ansi.RESET)
}

write_regfile :: proc(b: ^strings.Builder, regfile: ^Register_File) {
    @static prev_regfile := Register_File{}
  
    for reg, i in regfile.gpr {
        term.save_cursor_pos(b)

        // register name
        term.set_text_style(b, ansi.FAINT)
        strings.write_byte(b, 'r')
        strings.write_uint(b, uint(i) + 1)
        strings.write_byte(b, ' ')
        if i + 1 <= 9 { strings.write_byte(b, ' ') }
        term.set_text_style(b, ansi.NO_BOLD_FAINT)

        // register data
        if reg != prev_regfile.gpr[i] {
            // invert colours on value change
            term.set_text_style(b, ansi.INVERT, ansi.FG_YELLOW)
        }
        write_hex_word(b, reg)

        term.restore_cursor_pos(b)
        term.move_cursor(b, ansi.CUD)
    }

    for i in 0..=1 {
        term.move_cursor(b, ansi.CUD)
        term.save_cursor_pos(b)

        // bank header
        term.set_text_style(b, ansi.FG_YELLOW)
        strings.write_string(b, "<bank ")
        strings.write_byte(b,  '0' + u8(i))
        strings.write_byte(b, '>')
        if i == int(active_psr_bank_index(regfile)) {
            term.set_text_style(b, ansi.BOLD, ansi.FG_RED)
            strings.write_string(b, " *")
        }
        term.set_text_style(b, ansi.FG_DEFAULT)

        term.restore_cursor_pos(b)
        term.move_cursor(b, ansi.CUD)
        term.save_cursor_pos(b)

        // stack pointer
        term.set_text_style(b, ansi.FAINT)
        strings.write_string(b, "sp  ")
        term.set_text_style(b, ansi.NO_BOLD_FAINT)
        if regfile.sp[i] != prev_regfile.sp[i] {
            // invert colours on value change
            term.set_text_style(b, ansi.INVERT, ansi.FG_YELLOW)
        }
        write_hex_word(b, regfile.sp[i])

        term.restore_cursor_pos(b)
        term.move_cursor(b, ansi.CUD)
        term.save_cursor_pos(b)

        // link register
        term.set_text_style(b, ansi.FAINT)
        strings.write_string(b, "lr  ")
        term.set_text_style(b, ansi.NO_BOLD_FAINT)
        if regfile.lr[i] != prev_regfile.lr[i] {
            // invert colours on value change
            term.set_text_style(b, ansi.INVERT, ansi.FG_YELLOW)
        }
        write_hex_word(b, regfile.lr[i])

        term.restore_cursor_pos(b)
        term.move_cursor(b, ansi.CUD)
        term.save_cursor_pos(b)

        // program status register
        write_psr(b, regfile.psr[i])

        term.restore_cursor_pos(b)
        term.move_cursor(b, ansi.CUD)
    }

    prev_regfile = regfile^

    return

    write_psr :: proc(b: ^strings.Builder, r: Program_Status_Register) {
        FLAG_LETTERS :: "PSTICVNZ"

        term.set_text_style(b, ansi.FAINT)
        strings.write_string(b, "psr ")
        term.set_text_style(b, ansi.NO_BOLD_FAINT)

        for c, i in FLAG_LETTERS {
            flag_set := ((1 << uint(7 - i)) & u32(r) != 0)
            term.set_text_style(b, ansi.NO_BOLD_FAINT, (flag_set) ? ansi.BOLD : ansi.FAINT)
            strings.write_byte(b, u8(c))
        }
    }
}

write_disassembly :: proc(b: ^strings.Builder, rt: ^Runtime_State, window_offset: int, lines: int) {
    address := u32(window_offset)
    for i := 0; i < lines; i += 1 {
        term.save_cursor_pos(b)
        term.clear_cursor_to_line_end(b)

        // end of memory
        if address >= u32(len(rt.memory.physical)) {
            // strings.write_string(b, "    ")
            term.restore_cursor_pos(b)
            term.move_cursor(b, ansi.CUD)
            continue
        }

        // label
        if label := get_label_at_address(rt, address); label != "" {
            strings.write_string(b, "    ")

            write_hex_word(b, address)
            term.set_text_style(b, ansi.FG_YELLOW)
            strings.write_string(b, " <")
            strings.write_string(b, label)
            strings.write_byte(b, '>')
            term.set_text_style(b, ansi.FG_DEFAULT)
            strings.write_byte(b, ':')

            term.restore_cursor_pos(b)
            term.move_cursor(b, ansi.CUD)
            term.save_cursor_pos(b)
            term.clear_cursor_to_line_end(b)

            i += 1
            if i == lines { break }
        }

        on_pc_line := (address == rt.regfile.pc)

        breakpoint := false
        for b in rt.breakpoints {
            if address == b {
                breakpoint = true
                break
            }
        }

        // pc and breakpoint lines
        if on_pc_line {
            term.set_text_style(b, ansi.INVERT, ansi.FG_YELLOW)
            if breakpoint {
                term.set_text_style(b, ansi.FG_BRIGHT_RED)
            }
            strings.write_string(b, (breakpoint) ? "  * " : "    ")
            term.set_text_style(b, ansi.NO_BOLD_FAINT)
        } else {
            term.set_text_style(b, ansi.BOLD, ansi.FG_BRIGHT_RED)
            strings.write_string(b, (breakpoint) ? "  * " : "    ")
            term.set_text_style(b, ansi.NO_BOLD_FAINT, ansi.FG_DEFAULT)
        }

        // address
        write_hex_word(b, address)
        strings.write_string(b, ":   ")

        // data at address in bytes
        if !on_pc_line {
            term.set_text_style(b, ansi.FAINT)
        }
        for j in 0..<4 { 
            if address >= u32(len(rt.memory.physical)) {
                strings.write_string(b, "   ")
                continue
            }
            write_hex_byte(b, rt.memory.physical[address + u32(j)])
            strings.write_byte(b, ' ')
        }
        term.set_text_style(b, ansi.NO_BOLD_FAINT)
        strings.write_string(b, "   ")

        eol_padding := 38

        // disassembled instruction
        machine_word := u32((^u32le)(&rt.memory.physical[address])^)
        if instr, ok := auras.decode_instruction(machine_word); ok {
            strings.write_string(b, instr)
            eol_padding -= len(instr)
            delete(instr)
        } else {
            strings.write_string(b, "<unknown>")
        }

        // branch destination as comment
        if machine_word >> 30 == 0b10 && ((machine_word >> 28) & 1) == 1 { // branch
            offset := machine_word & 0x00FF_FFFF
            offset |= (offset >> 23 != 0) ? 0xFF00_0000 : 0
            offset <<= 2
            destination := address + offset
            if label := get_label_at_address(rt, destination); label != "" {
                term.set_text_style(b, ansi.ITALIC)
                if address != rt.regfile.pc {
                    // dim comment unless line is already inverted (bad contrast)
                    term.set_text_style(b, ansi.FG_CYAN)
                }
                strings.write_string(b, " ; <")
                strings.write_string(b, label)
                strings.write_string(b, ">")
                eol_padding -= len(label) + 5
            }
        }

        if on_pc_line {
            // highlight remainder of line
            for ; eol_padding >= 0; eol_padding -= 1 {
                strings.write_byte(b, ' ')
            }
        }

        term.restore_cursor_pos(b)
        term.move_cursor(b, ansi.CUD)

        address += 4
    }

    return

    get_label_at_address :: #force_inline proc(rt: ^Runtime_State, address: u32) -> string {
        if i, ok := slice.binary_search_by(rt.offset_sorted_labels[:], address, by); ok {
            return rt.string_table[rt.offset_sorted_labels[i].name]
        }
        return ""

        by :: proc(symbol: auras.Symbol_Table_Entry, offset: u32) -> slice.Ordering {
            if symbol.offset == offset { return .Equal }
            return (symbol.offset > offset) ? .Greater : .Less
        }
    }
}

write_core_stdout :: proc(b: ^strings.Builder) {
    term.save_cursor_pos(b)
    strings.write_string(b, "> ")
    for c in core_stdout {
        if c == '\n' {
            term.restore_cursor_pos(b)
            term.move_cursor(b, ansi.CUD)
            term.save_cursor_pos(b)
            strings.write_string(b, "> ")
            continue
        }
        strings.write_byte(b, c)
    }
}

write_hex_word :: proc(b: ^strings.Builder, i: u32) {
    buf: [8]u8 = ---
    i := i
    for j := 7; j >= 0; j -= 1 {
        buf[j] = u8(i & 0xF) + '0'
        if buf[j] > '9' {
            buf[j] += 'A' - '9' - 1
        }
        i >>= 4
    }
    strings.write_bytes(b, buf[:])
}

write_hex_byte :: proc(b: ^strings.Builder, i: u8) {
    buf: [2]u8 = ---
    i := i
    for j := 1; j >= 0; j -= 1 {
        buf[j] = u8(i & 0xF) + '0'
        if buf[j] > '9' {
            buf[j] += 'A' - '9' - 1
        }
        i >>= 4
    }
    strings.write_bytes(b, buf[:])
}
