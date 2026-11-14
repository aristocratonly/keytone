import CoreGraphics

enum KeyCategory: CaseIterable { case normal, space, enter, backspace, modifier }

struct KeyInfo: Identifiable {
    let code: UInt16
    let label: String
    let width: CGFloat
    var id: UInt16 { code }
}

private func K(_ c: UInt16, _ l: String, _ w: CGFloat = 1) -> KeyInfo { KeyInfo(code: c, label: l, width: w) }

enum Keymap {
    static let rows: [[KeyInfo]] = [
        [K(50,"`"),K(18,"1"),K(19,"2"),K(20,"3"),K(21,"4"),K(23,"5"),K(22,"6"),K(26,"7"),K(28,"8"),K(25,"9"),K(29,"0"),K(27,"-"),K(24,"="),K(51,"⌫",2)],
        [K(48,"⇥",1.5),K(12,"Q"),K(13,"W"),K(14,"E"),K(15,"R"),K(17,"T"),K(16,"Y"),K(32,"U"),K(34,"I"),K(31,"O"),K(35,"P"),K(33,"["),K(30,"]"),K(42,"\\",1.5)],
        [K(57,"⇪",1.75),K(0,"A"),K(1,"S"),K(2,"D"),K(3,"F"),K(5,"G"),K(4,"H"),K(38,"J"),K(40,"K"),K(37,"L"),K(41,";"),K(39,"'"),K(36,"⏎",2.25)],
        [K(56,"⇧",2.25),K(6,"Z"),K(7,"X"),K(8,"C"),K(9,"V"),K(11,"B"),K(45,"N"),K(46,"M"),K(43,","),K(47,"."),K(44,"/"),K(60,"⇧",2.75)],
        [K(63,"fn"),K(59,"⌃"),K(58,"⌥"),K(55,"⌘",1.25),K(49,"",5.5),K(54,"⌘",1.25),K(61,"⌥"),K(123,"←"),K(125,"↓"),K(124,"→")],
    ]

    /// Horizontal position 0...1 of each key on the board (used for stereo panning).
    static let column: [UInt16: CGFloat] = {
        var m: [UInt16: CGFloat] = [:]
        for row in rows {
            let total = row.reduce(0) { $0 + $1.width }
            var x: CGFloat = 0
            for k in row { m[k.code] = (x + k.width / 2) / total; x += k.width }
        }
        return m
    }()

    static func category(_ c: UInt16) -> KeyCategory {
        switch c {
        case 49: return .space
        case 36, 76: return .enter
        case 51, 117: return .backspace
        case 54...63: return .modifier
        default: return .normal
        }
    }

    /// macOS virtual keycode -> libuiohook scancode (used by Mechvibes packs).
    static let scancode: [UInt16: Int] = [
        53:1, 18:2, 19:3, 20:4, 21:5, 23:6, 22:7, 26:8, 28:9, 25:10, 29:11, 27:12, 24:13, 51:14,
        48:15, 12:16, 13:17, 14:18, 15:19, 17:20, 16:21, 32:22, 34:23, 31:24, 35:25, 33:26, 30:27, 36:28,
        59:29, 0:30, 1:31, 2:32, 3:33, 5:34, 4:35, 38:36, 40:37, 37:38, 41:39, 39:40, 50:41,
        56:42, 42:43, 6:44, 7:45, 8:46, 9:47, 11:48, 45:49, 46:50, 43:51, 47:52, 44:53, 60:54,
        58:56, 49:57, 57:58,
        122:59, 120:60, 99:61, 118:62, 96:63, 97:64, 98:65, 100:66, 101:67, 109:68, 103:87, 111:88,
        62:3613, 61:3640, 55:3675, 54:3676,
        126:57416, 125:57424, 123:57419, 124:57421, 117:3667, 115:3655, 119:3663, 116:3657, 121:3665,
    ]

    /// macOS virtual keycode -> W3C KeyboardEvent.code (used by Mechvibes v2 packs).
    static let codeName: [UInt16: String] = {
        var m: [UInt16: String] = [53:"Escape", 50:"Backquote", 27:"Minus", 24:"Equal", 51:"Backspace", 48:"Tab",
            33:"BracketLeft", 30:"BracketRight", 42:"Backslash", 57:"CapsLock", 41:"Semicolon", 39:"Quote", 36:"Enter",
            56:"ShiftLeft", 60:"ShiftRight", 43:"Comma", 47:"Period", 44:"Slash", 59:"ControlLeft", 62:"ControlRight",
            58:"AltLeft", 61:"AltRight", 55:"MetaLeft", 54:"MetaRight", 49:"Space", 63:"Fn",
            123:"ArrowLeft", 124:"ArrowRight", 125:"ArrowDown", 126:"ArrowUp", 117:"Delete", 115:"Home", 119:"End",
            116:"PageUp", 121:"PageDown", 76:"NumpadEnter",
            122:"F1", 120:"F2", 99:"F3", 118:"F4", 96:"F5", 97:"F6", 98:"F7", 100:"F8", 101:"F9", 109:"F10", 103:"F11", 111:"F12"]
        let letters: [(UInt16, String)] = [(0,"A"),(11,"B"),(8,"C"),(2,"D"),(14,"E"),(3,"F"),(5,"G"),(4,"H"),(34,"I"),(38,"J"),(40,"K"),(37,"L"),(46,"M"),
            (45,"N"),(31,"O"),(35,"P"),(12,"Q"),(15,"R"),(1,"S"),(17,"T"),(32,"U"),(9,"V"),(13,"W"),(7,"X"),(16,"Y"),(6,"Z")]
        for (c, l) in letters { m[c] = "Key" + l }
        let digits: [(UInt16, String)] = [(29,"0"),(18,"1"),(19,"2"),(20,"3"),(21,"4"),(23,"5"),(22,"6"),(26,"7"),(28,"8"),(25,"9")]
        for (c, d) in digits { m[c] = "Digit" + d }
        return m
    }()
}
