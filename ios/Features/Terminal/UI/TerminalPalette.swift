import SwiftUI

struct TerminalPalette {
    let bg: Color
    let surface: Color
    let surfaceRaised: Color
    let line: Color
    let ink: Color
    let inkMuted: Color
    let prompt: Color
    let command: Color
    let notice: Color
    let danger: Color
    let select: Color

    static let dark = TerminalPalette(
        bg: Color(red: 0x0b / 255, green: 0x0d / 255, blue: 0x10 / 255),
        surface: Color(red: 0x14 / 255, green: 0x17 / 255, blue: 0x1c / 255),
        surfaceRaised: Color(red: 0x1c / 255, green: 0x20 / 255, blue: 0x27 / 255),
        line: Color(red: 0x2e / 255, green: 0x34 / 255, blue: 0x3d / 255),
        ink: Color(red: 0xe7 / 255, green: 0xe9 / 255, blue: 0xec / 255),
        inkMuted: Color(red: 0x99 / 255, green: 0xa2 / 255, blue: 0xad / 255),
        prompt: Color(red: 0x7f / 255, green: 0xe0 / 255, blue: 0xa3 / 255),
        command: Color(red: 0x86 / 255, green: 0xc8 / 255, blue: 0xff / 255),
        notice: Color(red: 0xf2 / 255, green: 0xc8 / 255, blue: 0x6b / 255),
        danger: Color(red: 0xff / 255, green: 0x8f / 255, blue: 0x86 / 255),
        select: Color(red: 0x1f / 255, green: 0x3a / 255, blue: 0x52 / 255)
    )
}
