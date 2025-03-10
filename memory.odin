package aurum

import "core:math/bits"
import "core:fmt"

Memory_Space :: struct {
    raw_bytes: []u8
}

memory_read :: proc(memory: ^Memory_Space, address: u32, width: uint) -> (u32, Exception) {
    if uint(address) >= len(memory.raw_bytes) { return 0, .Bus_Fault }
    switch width {
    case 1:
        return u32(memory.raw_bytes[address]), nil
    case 2:
        if address % 2 != 0 { return 0, .Usage_Fault }
        return u32((^u16le)(&memory.raw_bytes[address])^), nil
    case 4:
        if address % 4 != 0 { return 0, .Usage_Fault }
        return u32((^u32le)(&memory.raw_bytes[address])^), nil
    }
    panic("invalid memory access width")
}

memory_write :: proc(memory: ^Memory_Space, address: u32, width: uint, value: u32) -> Exception {
    if uint(address) >= len(memory.raw_bytes) { return .Bus_Fault }
    switch width {
    case 1:
        memory.raw_bytes[address] = u8(value)
        return .None
    case 2:
        if address % 2 != 0 { return .Usage_Fault }
        ((^u16le)(&memory.raw_bytes[address]))^ = u16le(value)
        return .None
    case 4:
        if address % 4 != 0 { return .Usage_Fault }
        ((^u32le)(&memory.raw_bytes[address]))^ = u32le(value)
        return .None
    }
    panic("invalid memory access width")
}
