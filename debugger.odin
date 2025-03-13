package aurum

import "auras"

import "core:strings"
import "core:slice"
import "core:fmt"
import "base:runtime"

Debugger_State :: struct{

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

write_hex :: proc{ write_hex_byte, write_hex_word }

regfile_stream :: proc(regfile: Register_File) -> string {
    @static buf: [512]u8
    sb := strings.builder_from_slice(buf[:])
  
    for reg, i in regfile.gpr {
        // save cursor pos
        strings.write_string(&sb, "\0337")
        // register data
        strings.write_byte(&sb, 'r')
        strings.write_uint(&sb, uint(i) + 1)
        strings.write_byte(&sb, ' ')
        if i + 1 <= 9 { strings.write_byte(&sb, ' ') }
        write_hex(&sb, reg)
        // restore cursor pos and jump to next line
        strings.write_string(&sb, "\0338\033[B")
    }

    for i in 0..=1 {
        // jump to next line and save cursor pos
        strings.write_string(&sb, "\033[B\0337")
        // bank header
        strings.write_string(&sb, "<bank ")
        strings.write_byte(&sb, u8(i) + '0')
        strings.write_string(&sb, ">")
        // restore cursor pos, jump to next line, and save cursor pos
        strings.write_string(&sb, "\0338\033[B\0337")
        // stack pointer
        strings.write_string(&sb, "sp  ")
        write_hex(&sb, regfile.sp[i])
        // restore cursor pos, jump to next line, and save cursor pos
        strings.write_string(&sb, "\0338\033[B\0337")
        // link register
        strings.write_string(&sb, "lr  ")
        write_hex(&sb, regfile.lr[i])
        // restore cursor pos, jump to next line, and save cursor pos
        strings.write_string(&sb, "\0338\033[B\0337")
        // program status register
        strings.write_string(&sb, "psr ")
        write_psr(&sb, regfile.psr[i])
        // restore cursor pos and jump to next line
        strings.write_string(&sb, "\0338\033[B")
    }

    return strings.to_string(sb)

    write_psr :: proc(b: ^strings.Builder, r: Program_Status_Register) {
        FLAG_LETTERS :: "PSTICVNZ"
        for c, i in FLAG_LETTERS {
            flag_set := ((1 << uint(7 - i)) & u32(r) != 0)
            strings.write_string(b, (flag_set) ? "\033[0;1m" : "\033[0;2m")
            strings.write_byte(b, u8(c))
        }
    }
}

disassembly_stream :: proc(regfile: Register_File, code: auras.Source_File, lines: int) -> string {
    sb: strings.Builder
    strings.builder_init(&sb, 0, 256)

    address := regfile.pc
    for i := 0; i < lines; i += 1 {
        // save cursor pos
        strings.write_string(&sb, "\0337")
        // label
        if index, ok := slice.binary_search_by(code.symbol_table[:], address, by); ok {
            symbol := runtime.cstring_to_string(cstring(&code.string_table[code.symbol_table[index].name]))
            write_hex(&sb, address)
            strings.write_string(&sb, " <")
            strings.write_string(&sb, symbol)
            strings.write_string(&sb, ">:")
            // restore cursor pos and jump to next line
            strings.write_string(&sb, "\0338\033[B")
            i += 1
            if i == lines {
                break
            }
        }

        // save cursor pos
        strings.write_string(&sb, "\0337")
        if address == regfile.pc {
            strings.write_string(&sb, "\033[2D\033[;36m> ")
        }
        write_hex(&sb, address)
        strings.write_string(&sb, ":   ")
        for j in 0..<4 { 
            if address >= u32(len(code.buffer)) {
                strings.write_string(&sb, "   ")
                continue
            }
            write_hex(&sb, code.buffer[address + u32(j)])
            strings.write_byte(&sb, ' ')
        }
        strings.write_string(&sb, "   ")
        if instr, ok := auras.decode_instruction(u32((^u32le)(&code.buffer[address])^)); ok {
            strings.write_string(&sb, instr)
            delete(instr)
        }
        // restore cursor pos and jump to next line
        strings.write_string(&sb, "\0338\033[B")

        address += 4
    }

    by :: proc(symbol: auras.Symbol_Table_Entry, offset: u32) -> slice.Ordering {
        if symbol.offset == offset { return .Equal }
        return (symbol.offset > offset) ? .Greater : .Less
    }

    return strings.to_string(sb)

}


