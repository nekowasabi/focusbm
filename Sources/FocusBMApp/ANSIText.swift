import SwiftUI

/// Converts tmux `capture-pane -e` output (SGR colors) into an AttributedString.
enum ANSIText {
    static let defaultForeground = Color(white: 0.9)

    /// Raw text with every CSI escape sequence removed (for blank-line checks).
    static func stripped(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\u{1b}\\[[0-9;:?]*[ -/]*[@-~]", with: "", options: .regularExpression)
    }

    static func attributed(_ raw: String) -> AttributedString {
        var out = AttributedString()
        var fg: Color?, bg: Color?
        var bold = false, dim = false
        var buf = ""

        func flush() {
            guard !buf.isEmpty else { return }
            var run = AttributedString(buf)
            let base = fg ?? defaultForeground
            run.foregroundColor = dim ? base.opacity(0.6) : base
            run.backgroundColor = bg
            if bold { run.inlinePresentationIntent = .stronglyEmphasized }
            out += run
            buf = ""
        }

        let s = Array(raw.unicodeScalars)
        var i = 0
        while i < s.count {
            guard s[i] == "\u{1b}" else { buf.unicodeScalars.append(s[i]); i += 1; continue }
            i += 1
            guard i < s.count, s[i] == "[" else { continue }  // lone ESC: drop
            i += 1
            var params = ""
            while i < s.count, !(0x40...0x7E).contains(s[i].value) { params.unicodeScalars.append(s[i]); i += 1 }
            guard i < s.count else { break }
            let final = s[i]; i += 1
            guard final == "m" else { continue }  // non-SGR CSI: drop
            flush()
            var codes = params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
            if codes.isEmpty { codes = [0] }
            var k = 0
            while k < codes.count {
                let c = codes[k]; k += 1
                switch c {
                case 0: fg = nil; bg = nil; bold = false; dim = false
                case 1: bold = true
                case 2: dim = true
                case 22: bold = false; dim = false
                case 30...37: fg = palette(c - 30)
                case 90...97: fg = palette(c - 90 + 8)
                case 40...47: bg = palette(c - 40)
                case 100...107: bg = palette(c - 100 + 8)
                case 39: fg = nil
                case 49: bg = nil
                case 38, 48:
                    var color: Color?
                    if k < codes.count, codes[k] == 5, k + 1 < codes.count {
                        color = palette(codes[k + 1]); k += 2
                    } else if k < codes.count, codes[k] == 2, k + 3 < codes.count {
                        color = Color(red: Double(codes[k + 1]) / 255, green: Double(codes[k + 2]) / 255, blue: Double(codes[k + 3]) / 255)
                        k += 4
                    }
                    if c == 38 { fg = color } else { bg = color }
                default: break
                }
            }
        }
        flush()
        return out
    }

    private static let basic: [(Double, Double, Double)] = [
        (0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0), (0, 0, 238), (205, 0, 205), (0, 205, 205), (229, 229, 229),
        (127, 127, 127), (255, 0, 0), (0, 255, 0), (255, 255, 0), (92, 92, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
    ]

    /// xterm 256-color palette: 0-15 basic, 16-231 6x6x6 cube, 232-255 grayscale.
    static func palette(_ n: Int) -> Color? {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
        switch n {
        case 0..<16: let c = basic[n]; return rgb(c.0, c.1, c.2)
        case 16..<232:
            let levels: [Double] = [0, 95, 135, 175, 215, 255]
            let v = n - 16
            return rgb(levels[v / 36], levels[v / 6 % 6], levels[v % 6])
        case 232..<256: let g = Double(8 + 10 * (n - 232)); return rgb(g, g, g)
        default: return nil
        }
    }
}
