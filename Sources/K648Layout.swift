import Foundation
import CoreGraphics

enum KeyZone: String, CaseIterable, Identifiable {
    case all = "Todas"
    case wasd = "WASD"
    case arrows = "Flechas"
    case numpad = "Numpad"
    case function = "Fila F"
    case modifiers = "Modificadores"
    case alpha = "Alfanuméricas"
    var id: String { rawValue }
}

struct KeyboardKey: Identifiable, Hashable {
    let id: String          // e.g. "K1"
    let name: String        // Official name e.g. "Esc", "Num7"
    let label: String       // Keycap text
    let x: CGFloat          // Normalized/base canvas X (0..600)
    let y: CGFloat          // Normalized/base canvas Y (0..226)
    let width: CGFloat
    let height: CGFloat
    let slot: Int           // Sinowealth 0x08 LED slot index (0..125)
    let normX: Double       // 0.0 .. 1.0 horizontal center for wave effects
    let normY: Double       // 0.0 .. 1.0 vertical center for wave effects
    let zone: KeyZone
}

enum K648Layout {
    static let canvasWidth: CGFloat = 602
    static let canvasHeight: CGFloat = 228
    static let totalLedSlots: Int = 126

    static let keys: [KeyboardKey] = [
        KeyboardKey(id: "K1", name: "Esc", label: "ESC", x: 9.5, y: 17.0, width: 28.0, height: 28.0, slot: 0, normX: 0.0200, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K2", name: "F1", label: "F1", x: 73.5, y: 17.0, width: 28.0, height: 28.0, slot: 12, normX: 0.1313, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K3", name: "F2", label: "F2", x: 105.5, y: 17.0, width: 28.0, height: 28.0, slot: 18, normX: 0.1870, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K4", name: "F3", label: "F3", x: 137.5, y: 17.0, width: 28.0, height: 28.0, slot: 24, normX: 0.2426, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K5", name: "F4", label: "F4", x: 169.5, y: 17.0, width: 28.0, height: 28.0, slot: 30, normX: 0.2983, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K6", name: "F5", label: "F5", x: 216.5, y: 17.0, width: 28.0, height: 28.0, slot: 36, normX: 0.3800, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K7", name: "F6", label: "F6", x: 249.5, y: 17.0, width: 28.0, height: 28.0, slot: 42, normX: 0.4374, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K8", name: "F7", label: "F7", x: 280.5, y: 17.0, width: 28.0, height: 28.0, slot: 48, normX: 0.4913, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K9", name: "F8", label: "F8", x: 313.5, y: 17.0, width: 28.0, height: 28.0, slot: 54, normX: 0.5487, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K10", name: "F9", label: "F9", x: 361.5, y: 17.0, width: 28.0, height: 28.0, slot: 60, normX: 0.6322, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K11", name: "F10", label: "F10", x: 392.5, y: 17.0, width: 28.0, height: 28.0, slot: 66, normX: 0.6861, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K12", name: "F11", label: "F11", x: 424.5, y: 17.0, width: 28.0, height: 28.0, slot: 72, normX: 0.7417, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K13", name: "F12", label: "F12", x: 456.5, y: 17.0, width: 28.0, height: 28.0, slot: 78, normX: 0.7974, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K14", name: "PrtSc", label: "PRT", x: 498.5, y: 17.0, width: 28.0, height: 28.0, slot: 84, normX: 0.8704, normY: 0.0576, zone: .function),
        KeyboardKey(id: "K15", name: "Num+", label: "+", x: 530.5, y: 17.0, width: 28.0, height: 28.0, slot: 90, normX: 0.9261, normY: 0.0576, zone: .numpad),
        KeyboardKey(id: "K16", name: "Num-", label: "-", x: 562.5, y: 18.0, width: 28.0, height: 28.0, slot: 96, normX: 0.9817, normY: 0.0628, zone: .numpad),
        KeyboardKey(id: "K17", name: "`", label: "`", x: 9.5, y: 54.0, width: 28.0, height: 28.0, slot: 1, normX: 0.0200, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K18", name: "1", label: "1", x: 41.5, y: 54.0, width: 28.0, height: 28.0, slot: 7, normX: 0.0757, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K19", name: "2", label: "2", x: 73.5, y: 54.0, width: 28.0, height: 28.0, slot: 13, normX: 0.1313, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K20", name: "3", label: "3", x: 105.5, y: 54.0, width: 28.0, height: 28.0, slot: 19, normX: 0.1870, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K21", name: "4", label: "4", x: 137.5, y: 54.0, width: 28.0, height: 28.0, slot: 25, normX: 0.2426, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K22", name: "5", label: "5", x: 169.5, y: 54.0, width: 28.0, height: 28.0, slot: 31, normX: 0.2983, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K23", name: "6", label: "6", x: 201.5, y: 54.0, width: 28.0, height: 28.0, slot: 37, normX: 0.3539, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K24", name: "7", label: "7", x: 233.5, y: 54.0, width: 28.0, height: 28.0, slot: 43, normX: 0.4096, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K25", name: "8", label: "8", x: 264.5, y: 54.0, width: 28.0, height: 28.0, slot: 49, normX: 0.4635, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K26", name: "9", label: "9", x: 297.5, y: 54.0, width: 28.0, height: 28.0, slot: 55, normX: 0.5209, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K27", name: "0", label: "0", x: 328.5, y: 54.0, width: 28.0, height: 28.0, slot: 61, normX: 0.5748, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K28", name: "-", label: "-", x: 360.5, y: 54.0, width: 28.0, height: 28.0, slot: 67, normX: 0.6304, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K29", name: "=", label: "=", x: 392.5, y: 54.0, width: 28.0, height: 28.0, slot: 73, normX: 0.6861, normY: 0.2513, zone: .alpha),
        KeyboardKey(id: "K30", name: "Backspace", label: "⌫", x: 424.5, y: 54.0, width: 58.0, height: 28.0, slot: 79, normX: 0.7678, normY: 0.2513, zone: .modifiers),
        KeyboardKey(id: "K31", name: "NumLock", label: "NUM", x: 498.5, y: 54.0, width: 28.0, height: 28.0, slot: 85, normX: 0.8704, normY: 0.2513, zone: .numpad),
        KeyboardKey(id: "K32", name: "Num /", label: "/", x: 530.5, y: 54.0, width: 28.0, height: 28.0, slot: 91, normX: 0.9261, normY: 0.2513, zone: .numpad),
        KeyboardKey(id: "K33", name: "Num*", label: "*", x: 562.5, y: 54.0, width: 28.0, height: 28.0, slot: 97, normX: 0.9817, normY: 0.2513, zone: .numpad),
        KeyboardKey(id: "K34", name: "Tab", label: "TAB", x: 8.5, y: 86.0, width: 44.0, height: 28.0, slot: 2, normX: 0.0322, normY: 0.4188, zone: .modifiers),
        KeyboardKey(id: "K35", name: "Q", label: "Q", x: 57.5, y: 86.0, width: 28.0, height: 28.0, slot: 8, normX: 0.1035, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K36", name: "W", label: "W", x: 89.5, y: 86.0, width: 28.0, height: 28.0, slot: 14, normX: 0.1591, normY: 0.4188, zone: .wasd),
        KeyboardKey(id: "K37", name: "E", label: "E", x: 121.5, y: 86.0, width: 28.0, height: 28.0, slot: 20, normX: 0.2148, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K38", name: "R", label: "R", x: 153.5, y: 86.0, width: 28.0, height: 28.0, slot: 26, normX: 0.2704, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K39", name: "T", label: "T", x: 185.5, y: 86.0, width: 28.0, height: 28.0, slot: 32, normX: 0.3261, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K40", name: "Y", label: "Y", x: 217.5, y: 86.0, width: 28.0, height: 28.0, slot: 38, normX: 0.3817, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K41", name: "U", label: "U", x: 249.5, y: 86.0, width: 28.0, height: 28.0, slot: 44, normX: 0.4374, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K42", name: "I", label: "I", x: 281.5, y: 86.0, width: 28.0, height: 28.0, slot: 50, normX: 0.4930, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K43", name: "O", label: "O", x: 312.5, y: 86.0, width: 28.0, height: 28.0, slot: 56, normX: 0.5470, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K44", name: "P", label: "P", x: 344.5, y: 86.0, width: 28.0, height: 28.0, slot: 62, normX: 0.6026, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K45", name: "[", label: "[", x: 376.5, y: 86.0, width: 28.0, height: 28.0, slot: 68, normX: 0.6583, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K46", name: "]", label: "]", x: 408.5, y: 86.0, width: 28.0, height: 28.0, slot: 74, normX: 0.7139, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K47", name: "\\", label: "\\", x: 440.5, y: 86.0, width: 42.0, height: 28.0, slot: 80, normX: 0.7817, normY: 0.4188, zone: .alpha),
        KeyboardKey(id: "K48", name: "Num7", label: "7", x: 498.5, y: 86.0, width: 28.0, height: 28.0, slot: 86, normX: 0.8704, normY: 0.4188, zone: .numpad),
        KeyboardKey(id: "K49", name: "Num8", label: "8", x: 530.5, y: 86.0, width: 28.0, height: 28.0, slot: 92, normX: 0.9261, normY: 0.4188, zone: .numpad),
        KeyboardKey(id: "K50", name: "Num9", label: "9", x: 562.5, y: 86.0, width: 28.0, height: 28.0, slot: 98, normX: 0.9817, normY: 0.4188, zone: .numpad),
        KeyboardKey(id: "K54", name: "CapsLock", label: "CAPS", x: 8.5, y: 118.0, width: 52.0, height: 28.0, slot: 3, normX: 0.0391, normY: 0.5864, zone: .modifiers),
        KeyboardKey(id: "K55", name: "A", label: "A", x: 65.5, y: 118.0, width: 28.0, height: 28.0, slot: 9, normX: 0.1174, normY: 0.5864, zone: .wasd),
        KeyboardKey(id: "K56", name: "S", label: "S", x: 97.5, y: 118.0, width: 28.0, height: 28.0, slot: 15, normX: 0.1730, normY: 0.5864, zone: .wasd),
        KeyboardKey(id: "K57", name: "D", label: "D", x: 129.5, y: 118.0, width: 28.0, height: 28.0, slot: 21, normX: 0.2287, normY: 0.5864, zone: .wasd),
        KeyboardKey(id: "K58", name: "F", label: "F", x: 161.5, y: 118.0, width: 28.0, height: 28.0, slot: 27, normX: 0.2843, normY: 0.5864, zone: .alpha),
        KeyboardKey(id: "K59", name: "G", label: "G", x: 193.5, y: 118.0, width: 28.0, height: 28.0, slot: 33, normX: 0.3400, normY: 0.5864, zone: .alpha),
        KeyboardKey(id: "K60", name: "H", label: "H", x: 224.5, y: 118.0, width: 28.0, height: 28.0, slot: 39, normX: 0.3939, normY: 0.5864, zone: .alpha),
        KeyboardKey(id: "K61", name: "J", label: "J", x: 257.5, y: 118.0, width: 28.0, height: 28.0, slot: 45, normX: 0.4513, normY: 0.5864, zone: .alpha),
        KeyboardKey(id: "K62", name: "K", label: "K", x: 288.5, y: 118.0, width: 28.0, height: 28.0, slot: 51, normX: 0.5052, normY: 0.5864, zone: .alpha),
        KeyboardKey(id: "K63", name: "L", label: "L", x: 320.5, y: 118.0, width: 28.0, height: 28.0, slot: 57, normX: 0.5609, normY: 0.5864, zone: .alpha),
        KeyboardKey(id: "K64", name: ";", label: ";", x: 352.5, y: 118.0, width: 28.0, height: 28.0, slot: 63, normX: 0.6165, normY: 0.5864, zone: .alpha),
        KeyboardKey(id: "K65", name: "'", label: "'", x: 384.5, y: 118.0, width: 28.0, height: 28.0, slot: 69, normX: 0.6722, normY: 0.5864, zone: .alpha),
        KeyboardKey(id: "K66", name: "Enter", label: "ENTER", x: 415.5, y: 118.0, width: 67.0, height: 28.0, slot: 81, normX: 0.7600, normY: 0.5864, zone: .modifiers),
        KeyboardKey(id: "K51", name: "Num4", label: "4", x: 498.5, y: 118.0, width: 28.0, height: 28.0, slot: 87, normX: 0.8704, normY: 0.5864, zone: .numpad),
        KeyboardKey(id: "K52", name: "Num5", label: "5", x: 530.5, y: 118.0, width: 28.0, height: 28.0, slot: 93, normX: 0.9261, normY: 0.5864, zone: .numpad),
        KeyboardKey(id: "K53", name: "Num6", label: "6", x: 562.5, y: 118.0, width: 28.0, height: 28.0, slot: 99, normX: 0.9817, normY: 0.5864, zone: .numpad),
        KeyboardKey(id: "K69", name: "LShift", label: "SHIFT", x: 9.5, y: 150.0, width: 67.0, height: 28.0, slot: 4, normX: 0.0539, normY: 0.7539, zone: .modifiers),
        KeyboardKey(id: "K70", name: "Z", label: "Z", x: 81.5, y: 149.0, width: 28.0, height: 28.0, slot: 10, normX: 0.1452, normY: 0.7487, zone: .alpha),
        KeyboardKey(id: "K71", name: "X", label: "X", x: 113.5, y: 150.0, width: 28.0, height: 28.0, slot: 16, normX: 0.2009, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K72", name: "C", label: "C", x: 145.5, y: 150.0, width: 28.0, height: 28.0, slot: 22, normX: 0.2565, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K73", name: "V", label: "V", x: 176.5, y: 150.0, width: 28.0, height: 28.0, slot: 28, normX: 0.3104, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K74", name: "B", label: "B", x: 208.5, y: 150.0, width: 28.0, height: 28.0, slot: 34, normX: 0.3661, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K75", name: "N", label: "N", x: 240.5, y: 150.0, width: 28.0, height: 28.0, slot: 40, normX: 0.4217, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K76", name: "M", label: "M", x: 273.5, y: 150.0, width: 28.0, height: 28.0, slot: 46, normX: 0.4791, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K77", name: ",", label: ",", x: 305.5, y: 150.0, width: 28.0, height: 28.0, slot: 52, normX: 0.5348, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K78", name: ".", label: ".", x: 336.5, y: 150.0, width: 28.0, height: 28.0, slot: 58, normX: 0.5887, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K79", name: "/", label: "/", x: 368.5, y: 150.0, width: 28.0, height: 28.0, slot: 64, normX: 0.6443, normY: 0.7539, zone: .alpha),
        KeyboardKey(id: "K80", name: "RShift", label: "SHIFT", x: 400.5, y: 150.0, width: 51.0, height: 28.0, slot: 76, normX: 0.7200, normY: 0.7539, zone: .modifiers),
        KeyboardKey(id: "K81", name: "Up", label: "↑", x: 461.5, y: 155.0, width: 28.0, height: 28.0, slot: 82, normX: 0.8061, normY: 0.7801, zone: .arrows),
        KeyboardKey(id: "K67", name: "Num1", label: "1", x: 498.5, y: 150.0, width: 28.0, height: 28.0, slot: 88, normX: 0.8704, normY: 0.7539, zone: .numpad),
        KeyboardKey(id: "K68", name: "Num2", label: "2", x: 530.5, y: 150.0, width: 28.0, height: 28.0, slot: 94, normX: 0.9261, normY: 0.7539, zone: .numpad),
        KeyboardKey(id: "K92", name: "Num3", label: "3", x: 562.5, y: 150.0, width: 28.0, height: 28.0, slot: 100, normX: 0.9817, normY: 0.7539, zone: .numpad),
        KeyboardKey(id: "K82", name: "LCtrl", label: "CTRL", x: 9.5, y: 182.0, width: 35.0, height: 28.0, slot: 5, normX: 0.0261, normY: 0.9215, zone: .modifiers),
        KeyboardKey(id: "K83", name: "LWin", label: "⌘/WIN", x: 49.5, y: 182.0, width: 35.0, height: 28.0, slot: 11, normX: 0.0957, normY: 0.9215, zone: .modifiers),
        KeyboardKey(id: "K84", name: "LAlt", label: "ALT", x: 89.5, y: 182.0, width: 35.0, height: 28.0, slot: 17, normX: 0.1652, normY: 0.9215, zone: .modifiers),
        KeyboardKey(id: "K85", name: "Space", label: "SPACE", x: 128.5, y: 182.0, width: 195.0, height: 28.0, slot: 35, normX: 0.3722, normY: 0.9215, zone: .modifiers),
        KeyboardKey(id: "K86", name: "RAlt", label: "ALT", x: 329.5, y: 182.0, width: 28.0, height: 28.0, slot: 53, normX: 0.5765, normY: 0.9215, zone: .modifiers),
        KeyboardKey(id: "K87", name: "FN", label: "FN", x: 361.5, y: 182.0, width: 28.0, height: 28.0, slot: 59, normX: 0.6322, normY: 0.9215, zone: .modifiers),
        KeyboardKey(id: "K88", name: "RCtrl", label: "CTRL", x: 393.5, y: 182.0, width: 28.0, height: 28.0, slot: 65, normX: 0.6878, normY: 0.9215, zone: .modifiers),
        KeyboardKey(id: "K94", name: "Num0", label: "0", x: 530.5, y: 182.0, width: 28.0, height: 28.0, slot: 95, normX: 0.9261, normY: 0.9215, zone: .numpad),
        KeyboardKey(id: "K93", name: "Num .", label: ".", x: 562.5, y: 182.0, width: 28.0, height: 28.0, slot: 101, normX: 0.9817, normY: 0.9215, zone: .numpad),
        KeyboardKey(id: "K89", name: "Left", label: "←", x: 428.5, y: 186.0, width: 28.0, height: 28.0, slot: 77, normX: 0.7487, normY: 0.9424, zone: .arrows),
        KeyboardKey(id: "K90", name: "Down", label: "↓", x: 461.5, y: 186.0, width: 28.0, height: 28.0, slot: 83, normX: 0.8061, normY: 0.9424, zone: .arrows),
        KeyboardKey(id: "K91", name: "Right", label: "→", x: 493.5, y: 186.0, width: 28.0, height: 28.0, slot: 89, normX: 0.8617, normY: 0.9424, zone: .arrows),
    ]

    static let keyById: [String: KeyboardKey] = Dictionary(uniqueKeysWithValues: keys.map { ($0.id, $0) })
    static let keyByName: [String: KeyboardKey] = Dictionary(uniqueKeysWithValues: keys.map { ($0.name, $0) })
    static let keyBySlot: [Int: KeyboardKey] = Dictionary(uniqueKeysWithValues: keys.map { ($0.slot, $0) })

    /// Maps standard USB HID Keyboard/Keypad Usage IDs (Usage Page 0x07) to physical K648 keys.
    static let keyByHIDUsage: [UInt32: KeyboardKey] = {
        let pairs: [(UInt32, String)] = [
            // Letters A..Z
            (0x04, "A"), (0x05, "B"), (0x06, "C"), (0x07, "D"), (0x08, "E"), (0x09, "F"),
            (0x0A, "G"), (0x0B, "H"), (0x0C, "I"), (0x0D, "J"), (0x0E, "K"), (0x0F, "L"),
            (0x10, "M"), (0x11, "N"), (0x12, "O"), (0x13, "P"), (0x14, "Q"), (0x15, "R"),
            (0x16, "S"), (0x17, "T"), (0x18, "U"), (0x19, "V"), (0x1A, "W"), (0x1B, "X"),
            (0x1C, "Y"), (0x1D, "Z"),
            // Numbers 1..0
            (0x1E, "1"), (0x1F, "2"), (0x20, "3"), (0x21, "4"), (0x22, "5"),
            (0x23, "6"), (0x24, "7"), (0x25, "8"), (0x26, "9"), (0x27, "0"),
            // Core controls & punctuation
            (0x28, "Enter"), (0x29, "Esc"), (0x2A, "Backspace"), (0x2B, "Tab"), (0x2C, "Space"),
            (0x2D, "-"), (0x2E, "="), (0x2F, "["), (0x30, "]"), (0x31, "\\"),
            (0x33, ";"), (0x34, "'"), (0x35, "`"), (0x36, ","), (0x37, "."), (0x38, "/"),
            (0x39, "CapsLock"),
            // Function row F1..F12 + PrtSc
            (0x3A, "F1"), (0x3B, "F2"), (0x3C, "F3"), (0x3D, "F4"),
            (0x3E, "F5"), (0x3F, "F6"), (0x40, "F7"), (0x41, "F8"),
            (0x42, "F9"), (0x43, "F10"), (0x44, "F11"), (0x45, "F12"),
            (0x46, "PrtSc"),
            // Arrows
            (0x4F, "Right"), (0x50, "Left"), (0x51, "Down"), (0x52, "Up"),
            // Numpad
            (0x53, "NumLock"), (0x54, "Num /"), (0x55, "Num*"), (0x56, "Num-"), (0x57, "Num+"),
            (0x58, "Enter"), // Fallback if numpad enter code ever emitted
            (0x59, "Num1"), (0x5A, "Num2"), (0x5B, "Num3"), (0x5C, "Num4"), (0x5D, "Num5"),
            (0x5E, "Num6"), (0x5F, "Num7"), (0x60, "Num8"), (0x61, "Num9"),
            (0x62, "Num0"), (0x63, "Num ."),
            // Modifiers
            (0xE0, "LCtrl"), (0xE1, "LShift"), (0xE2, "LAlt"), (0xE3, "LWin"),
            (0xE4, "RCtrl"), (0xE5, "RShift"), (0xE6, "RAlt"),
        ]
        var dict: [UInt32: KeyboardKey] = [:]
        for (usage, name) in pairs {
            if let k = keyByName[name] {
                dict[usage] = k
            }
        }
        return dict
    }()
}
