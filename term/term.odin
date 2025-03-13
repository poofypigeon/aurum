package term

import "core:strings"
import "core:os"

clear_screen :: #force_inline proc(b: ^strings.Builder) {
    strings.write_string(b, "\033[2J")
}

Clear_In_Line :: enum uint {
    Cursor_To_End,
    Start_To_Cursor,
    Entire_Line,
}

clear_in_line :: #force_inline proc(b: ^strings.Builder, how: Clear_In_Line) {
    strings.write_string(b, "\033[")
    strings.write_uint(b, uint(how))
    strings.write_byte(b, 'K')
}

save_cursor_pos :: #force_inline proc(b: ^strings.Builder) {
    strings.write_string(b, "\0337")
}

restore_cursor_pos :: #force_inline proc(b: ^strings.Builder) {
    strings.write_string(b, "\0338")
}

Text_Style :: enum uint {
    Reset              = 0,
    Bold               = 1,
    Dim                = 2,
    Italic             = 3,
    Underline          = 4,
    Blinking           = 5,
    Unknown            = 6, // Anything?
    Inverted           = 7,
    Hidden             = 8,
    Strike_Through     = 9,

    Not_Bold           = 22,
    Not_Dim            = 22, 
    Not_Italic         = 23,
    Not_Underline      = 24,
    Not_Blinking       = 25,
    Not_Inverted       = 27,
    Not_Hidden         = 28,
    Not_Strike_Through = 29,

    Black_FG   = 30,
    Red_FG     = 31,
    Green_FG   = 32,
    Yellow_FG  = 33,
    Blue_FG    = 34,
    Magenta_FG = 35,
    Cyan_FG    = 36,
    White_FG   = 37,
    Default_FG = 39,

    Black_BG   = 40,
    Red_BG     = 41,
    Green_BG   = 42,
    Yellow_BG  = 43,
    Blue_BG    = 44,
    Magenta_BG = 45,
    Cyan_BG    = 46,
    White_BG   = 47,
    Default_BG = 49,

    Bright_Black_FG   = 90,
    Bright_Red_FG     = 91,
    Bright_Green_FG   = 92,
    Bright_Yellow_FG  = 93,
    Bright_Blue_FG    = 94,
    Bright_Magenta_FG = 95,
    Bright_Cyan_FG    = 96,
    Bright_White_FG   = 97,

    Bright_Black_BG   = 100,
    Bright_Red_BG     = 101,
    Bright_Green_BG   = 102,
    Bright_Yellow_BG  = 103,
    Bright_Blue_BG    = 104,
    Bright_Magenta_BG = 105,
    Bright_Cyan_BG    = 106,
    Bright_White_BG   = 107,
}

set_text_style :: proc(b: ^strings.Builder, styles: ..Text_Style) {
    strings.write_string(b, "\033[")
    for style, i in styles {
        strings.write_uint(b, uint(style))
        if i < len(styles) - 1 {
            strings.write_byte(b, ';')
        }
    }
    strings.write_byte(b, 'm')
}

set_cursor_pos :: proc(b: ^strings.Builder, x, y: uint) {
    strings.write_string(b, "\033[")
    strings.write_uint(b, y)
    strings.write_byte(b, ';')
    strings.write_uint(b, x)
    strings.write_byte(b, 'H')
}

set_cursor_col :: proc(b: ^strings.Builder, x: uint) {
    strings.write_string(b, "\033[")
    strings.write_uint(b, x)
    strings.write_byte(b, 'G')
}

Direction :: enum uint {
    Up    = 'A',
    Down  = 'B',
    Right = 'C',
    Left  = 'D',
}

move_cursor :: proc(b: ^strings.Builder, direction: Direction, n: uint = 1) {
    if n == 0 { return }
    strings.write_string(b, "\033[")
    if n > 1 {
        strings.write_uint(b, n)
    }
    strings.write_byte(b, u8(direction))
}
