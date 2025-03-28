package term

// TODO use "core:encoding/ansi" constants

import "core:encoding/ansi"
import "core:os"
import "core:strings"
import "core:mem"

clear_screen_builder :: #force_inline proc(b: ^strings.Builder) { strings.write_string(b, ansi.CSI + "2" + ansi.ED) }
clear_screen_stdout  :: #force_inline proc() { os.write_string(os.stdout, ansi.CSI + "2" + ansi.ED) }
clear_screen :: proc{ clear_screen_builder, clear_screen_stdout }

clear_cursor_to_line_end_builder :: #force_inline proc(b: ^strings.Builder) { strings.write_string(b, ansi.CSI + "0" + ansi.EL); }
clear_cursor_to_line_end_stdout  :: #force_inline proc() { os.write_string(os.stdout, ansi.CSI + "0" + ansi.EL); }
clear_cursor_to_line_end :: proc{ clear_cursor_to_line_end_builder, clear_cursor_to_line_end_stdout }

clear_line_start_to_cursor_builder :: #force_inline proc(b: ^strings.Builder) { strings.write_string(b, ansi.CSI + "1" + ansi.EL); }
clear_line_start_to_cursor_stdout  :: #force_inline proc() { os.write_string(os.stdout, ansi.CSI + "1" + ansi.EL); }
clear_line_start_to_cursor :: proc{ clear_line_start_to_cursor_builder, clear_line_start_to_cursor_stdout }

clear_line_builder :: #force_inline proc(b: ^strings.Builder) { strings.write_string(b, ansi.CSI + "2" + ansi.EL); }
clear_line_stdout  :: #force_inline proc() { os.write_string(os.stdout, ansi.CSI + "2" + ansi.EL) }
clear_line :: proc{ clear_line_builder, clear_line_stdout }

save_cursor_pos_builder :: #force_inline proc(b: ^strings.Builder) { strings.write_string(b, ansi.DECSC) }
save_cursor_pos_stdout  :: #force_inline proc() { os.write_string(os.stdout, ansi.DECSC) }
save_cursor_pos :: proc{ save_cursor_pos_builder, save_cursor_pos_stdout }

restore_cursor_pos_builder :: #force_inline proc(b: ^strings.Builder) { strings.write_string(b, ansi.DECRC) }
restore_cursor_pos_stdout  :: #force_inline proc() { os.write_string(os.stdout, ansi.DECRC) }
restore_cursor_pos :: proc{ restore_cursor_pos_builder, restore_cursor_pos_stdout }

set_text_style_builder :: proc(b: ^strings.Builder, styles: ..string) {
    strings.write_string(b, ansi.CSI)
    for style, i in styles {
        strings.write_string(b, style)
        if i < len(styles) - 1 {
            strings.write_byte(b, ';')
        }
    }
    strings.write_byte(b, 'm')
}

set_text_style_stdout :: proc(styles: ..string) {
    os.write_string(os.stdout, ansi.CSI)
    for style, i in styles {
        os.write_string(os.stdout, style)
        if i < len(styles) - 1 {
            os.write_byte(os.stdout, ';')
        }
    }
    os.write_string(os.stdout, ansi.SGR)
}

set_text_style :: proc{ set_text_style_builder, set_text_style_stdout }

set_cursor_pos_builder :: proc(b: ^strings.Builder, x, y: uint) {
    strings.write_string(b, ansi.CSI)
    strings.write_uint(b, y)
    strings.write_byte(b, ';')
    strings.write_uint(b, x)
    strings.write_string(b, ansi.CUP)
}

set_cursor_pos_stdout :: proc(x, y: uint) {
    buf: [48]u8
    sb := strings.builder_from_bytes(buf[:])
    strings.write_string(&sb, ansi.CSI)
    strings.write_uint(&sb, y)
    strings.write_byte(&sb, ';')
    strings.write_uint(&sb, x)
    strings.write_string(&sb, ansi.CUP)
    os.write(os.stdout, sb.buf[:])
}

set_cursor_pos :: proc{ set_cursor_pos_builder, set_cursor_pos_stdout }

set_cursor_col_builder :: proc(b: ^strings.Builder, x: uint) {
    strings.write_string(b, ansi.CSI)
    strings.write_uint(b, x)
    strings.write_string(b, ansi.CHA)
}

set_cursor_col_stdout :: proc(x: uint) {
    buf: [24]u8
    sb := strings.builder_from_bytes(buf[:])
    strings.write_string(&sb, ansi.CSI)
    strings.write_uint(&sb, x)
    strings.write_string(&sb, ansi.CHA)
    os.write(os.stdout, sb.buf[:])
}

set_cursor_col :: proc{ set_cursor_col_builder, set_cursor_col_stdout }

move_cursor_builder :: proc(b: ^strings.Builder, direction: string, n: uint = 1) {
    if n == 0 { return }
    strings.write_string(b, ansi.CSI)
    if n > 1 {
        strings.write_uint(b, n)
    }
    strings.write_string(b, direction)
}

move_cursor_stdout :: proc(direction: string, n: uint = 1) {
    buf: [24]u8
    sb := strings.builder_from_bytes(buf[:])
    if n == 0 { return }
    strings.write_string(&sb, ansi.CSI)
    if n > 1 {
        strings.write_uint(&sb, n)
    }
    strings.write_string(&sb, direction)
    os.write(os.stdout, sb.buf[:])
}

move_cursor :: proc{ move_cursor_builder, move_cursor_stdout }
