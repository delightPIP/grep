import SwiftUI

struct TerminalMoleView: View {
    let size: CGFloat

    private static let rows = [
        "................", "................", ".....oooooo.....", "....ommmmmmo....",
        "...ommmmmmmmo...", "...omommmmomo...", "..ommomssmommo..", "..ommmssssmmmo..",
        "..ohhmmmmmmhho..", ".ohhhmmMMmmhhho.", ".ommmmMMMMmmmmo.", "..ommmmmmmmmmo..",
        ".rrommmmmmmmorr.", "rrrRrrrrrrRrrrrr", ".rrrrrRrrrrrrrr.", "................",
    ]

    private static let colors: [Character: Color] = [
        "M": Color(red: 0x4a / 255, green: 0x44 / 255, blue: 0x60 / 255),
        "R": Color(red: 0x6a / 255, green: 0x42 / 255, blue: 0x28 / 255),
        "h": Color(red: 0xf5 / 255, green: 0xc9 / 255, blue: 0xa3 / 255),
        "m": Color(red: 0x6c / 255, green: 0x65 / 255, blue: 0x85 / 255),
        "o": Color(red: 0x16 / 255, green: 0x12 / 255, blue: 0x0f / 255),
        "r": Color(red: 0x8a / 255, green: 0x5a / 255, blue: 0x3a / 255),
        "s": Color(red: 0xf2 / 255, green: 0xa0 / 255, blue: 0xa8 / 255),
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let cell = canvasSize.width / 16
            for (y, row) in Self.rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let color = Self.colors[ch] else { continue }
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}
