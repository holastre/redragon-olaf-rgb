import Foundation
import SwiftUI
import AppKit

struct RGBColor: Codable, Hashable {
    var r: Double // 0.0 ... 1.0
    var g: Double // 0.0 ... 1.0
    var b: Double // 0.0 ... 1.0

    init(r: Double, g: Double, b: Double) {
        self.r = min(1, max(0, r))
        self.g = min(1, max(0, g))
        self.b = min(1, max(0, b))
    }

    init(r8: UInt8, g8: UInt8, b8: UInt8) {
        self.r = Double(r8) / 255.0
        self.g = Double(g8) / 255.0
        self.b = Double(b8) / 255.0
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var val: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&val)
        if cleaned.count == 6 {
            self.r = Double((val >> 16) & 0xFF) / 255.0
            self.g = Double((val >> 8) & 0xFF) / 255.0
            self.b = Double(val & 0xFF) / 255.0
        } else {
            self.r = 1; self.g = 1; self.b = 1
        }
    }

    init(color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        self.r = min(1, max(0, Double(ns.redComponent)))
        self.g = min(1, max(0, Double(ns.greenComponent)))
        self.b = min(1, max(0, Double(ns.blueComponent)))
    }

    static func hsv(h: Double, s: Double, v: Double) -> RGBColor {
        let hh = ((h.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0)
        let i = Int(floor(hh * 6.0))
        let f = hh * 6.0 - Double(i)
        let p = v * (1.0 - s)
        let q = v * (1.0 - f * s)
        let t = v * (1.0 - (1.0 - f) * s)
        switch i % 6 {
        case 0: return RGBColor(r: v, g: t, b: p)
        case 1: return RGBColor(r: q, g: v, b: p)
        case 2: return RGBColor(r: p, g: v, b: t)
        case 3: return RGBColor(r: p, g: q, b: v)
        case 4: return RGBColor(r: t, g: p, b: v)
        default: return RGBColor(r: v, g: p, b: q)
        }
    }

    func scaled(by factor: Double) -> RGBColor {
        RGBColor(r: r * factor, g: g * factor, b: b * factor)
    }

    func blended(with other: RGBColor, t: Double) -> RGBColor {
        let k = min(1, max(0, t))
        return RGBColor(
            r: r + (other.r - r) * k,
            g: g + (other.g - g) * k,
            b: b + (other.b - b) * k
        )
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", UInt8(round(r * 255)), UInt8(round(g * 255)), UInt8(round(b * 255)))
    }

    func toHardwareBytes(brightness: Double, gammaCorrect: Bool) -> (UInt8, UInt8, UInt8) {
        let br = min(1.0, max(0.0, brightness))
        func ch(_ v: Double) -> UInt8 {
            let scaled = min(1.0, max(0.0, v * br))
            if scaled <= 0.001 { return 0 }
            let mapped = gammaCorrect ? pow(scaled, 1.65) : scaled
            let byteVal = Int(round(mapped * 255.0))
            return UInt8(min(255, max(scaled > 0.02 ? 1 : 0, byteVal)))
        }
        return (ch(r), ch(g), ch(b))
    }

    static let black = RGBColor(r: 0, g: 0, b: 0)
    static let white = RGBColor(r: 1, g: 1, b: 1)
    static let red = RGBColor(hex: "#FF2438")
    static let orange = RGBColor(hex: "#FF7A00")
    static let yellow = RGBColor(hex: "#FFD500")
    static let green = RGBColor(hex: "#00E676")
    static let cyan = RGBColor(hex: "#00E5FF")
    static let blue = RGBColor(hex: "#2979FF")
    static let purple = RGBColor(hex: "#AA00FF")
    static let magenta = RGBColor(hex: "#FF1791")

    static let swatches: [RGBColor] = [
        RGBColor(hex: "#FF2438"),
        RGBColor(hex: "#FF6B00"),
        RGBColor(hex: "#FFD600"),
        RGBColor(hex: "#00E676"),
        RGBColor(hex: "#00E5FF"),
        RGBColor(hex: "#2979FF"),
        RGBColor(hex: "#7C4DFF"),
        RGBColor(hex: "#FF1791"),
        RGBColor(hex: "#FFFFFF"),
        RGBColor(hex: "#FFE0B2"),
        RGBColor(hex: "#18FFFF"),
        RGBColor(hex: "#000000"),
    ]
}

enum GlobalEffect: String, Codable, CaseIterable, Identifiable {
    case rainbowWave = "rainbowWave"
    case solid = "solid"
    case breathing = "breathing"
    case spectrumCycle = "spectrumCycle"
    case aurora = "aurora"
    case fire = "fire"
    case matrixRain = "matrixRain"
    case twinkle = "twinkle"
    case radialPulse = "radialPulse"
    case reactiveTrail = "reactiveTrail"
    case reactiveRipple = "reactiveRipple"
    case reactiveRainbowRipple = "reactiveRainbowRipple"
    case reactiveCross = "reactiveCross"
    case reactiveSplash = "reactiveSplash"
    case reactiveHeatmap = "reactiveHeatmap"
    case customOnly = "customOnly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rainbowWave: return "Onda Arcoíris"
        case .solid: return "Color Sólido"
        case .breathing: return "Respiración"
        case .spectrumCycle: return "Ciclo de Espectro"
        case .aurora: return "Aurora Dual"
        case .fire: return "Fuego / Brasas"
        case .matrixRain: return "Lluvia Matrix"
        case .twinkle: return "Estrellas"
        case .radialPulse: return "Pulso Radial"
        case .reactiveTrail: return "Estela Reactiva"
        case .reactiveRipple: return "Onda Expansiva"
        case .reactiveRainbowRipple: return "Onda Arcoíris"
        case .reactiveCross: return "Cruz Láser"
        case .reactiveSplash: return "Chispas Reactivas"
        case .reactiveHeatmap: return "Mapa de Calor"
        case .customOnly: return "Solo por Tecla"
        }
    }

    var iconName: String {
        switch self {
        case .rainbowWave: return "rainbow"
        case .solid: return "paintpalette.fill"
        case .breathing: return "aqi.medium"
        case .spectrumCycle: return "circle.hexagongrid.fill"
        case .aurora: return "sparkles"
        case .fire: return "flame.fill"
        case .matrixRain: return "chevron.down.2"
        case .twinkle: return "star.fill"
        case .radialPulse: return "dot.radiowaves.left.and.right"
        case .reactiveTrail: return "bolt.fill"
        case .reactiveRipple: return "water.waves"
        case .reactiveRainbowRipple: return "sun.max.trianglebadge.exclamationmark"
        case .reactiveCross: return "plus.viewfinder"
        case .reactiveSplash: return "sparkle"
        case .reactiveHeatmap: return "thermometer.sun.fill"
        case .customOnly: return "keyboard"
        }
    }

    var isReactive: Bool {
        switch self {
        case .reactiveTrail, .reactiveRipple, .reactiveRainbowRipple, .reactiveCross, .reactiveSplash, .reactiveHeatmap:
            return true
        default:
            return false
        }
    }

    var isAnimated: Bool {
        switch self {
        case .solid, .customOnly, .reactiveTrail, .reactiveRipple, .reactiveRainbowRipple, .reactiveCross, .reactiveSplash, .reactiveHeatmap:
            return false
        default:
            return true
        }
    }

    var usesPrimaryColor: Bool {
        switch self {
        case .solid, .breathing, .aurora, .matrixRain, .twinkle, .radialPulse,
             .reactiveTrail, .reactiveRipple, .reactiveCross, .reactiveSplash:
            return true
        default:
            return false
        }
    }

    var usesSecondaryColor: Bool {
        switch self {
        case .aurora, .radialPulse, .twinkle,
             .reactiveTrail, .reactiveRipple, .reactiveRainbowRipple, .reactiveCross, .reactiveSplash:
            return true
        default:
            return false
        }
    }

    var usesDirection: Bool {
        switch self {
        case .rainbowWave, .aurora: return true
        default: return false
        }
    }

    var usesSpeed: Bool {
        switch self {
        case .solid, .customOnly: return false
        default: return true
        }
    }

    static let ambientEffects: [GlobalEffect] = [
        .rainbowWave, .solid, .breathing, .spectrumCycle,
        .aurora, .fire, .matrixRain, .twinkle,
        .radialPulse, .customOnly
    ]

    static let reactiveEffects: [GlobalEffect] = [
        .reactiveTrail, .reactiveRipple, .reactiveRainbowRipple,
        .reactiveCross, .reactiveSplash, .reactiveHeatmap
    ]
}

enum ReactiveOverlayMode: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case keyFlash = "keyFlash"
    case ripple = "ripple"
    case laserCross = "laserCross"
    case rainbowRipple = "rainbowRipple"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Desactivado"
        case .keyFlash: return "Destello tecla"
        case .ripple: return "Onda expansiva"
        case .laserCross: return "Cruz láser"
        case .rainbowRipple: return "Onda arcoíris"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "nosign"
        case .keyFlash: return "bolt.fill"
        case .ripple: return "water.waves"
        case .laserCross: return "plus.viewfinder"
        case .rainbowRipple: return "sparkles"
        }
    }
}

enum WaveDirection: String, Codable, CaseIterable, Identifiable {
    case leftToRight = "ltr"
    case rightToLeft = "rtl"
    case diagonal = "diag"
    case topToBottom = "ttb"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftToRight: return "Izq → Der"
        case .rightToLeft: return "Der → Izq"
        case .diagonal: return "Diagonal"
        case .topToBottom: return "Arriba → Abajo"
        }
    }

    var iconName: String {
        switch self {
        case .leftToRight: return "arrow.right"
        case .rightToLeft: return "arrow.left"
        case .diagonal: return "arrow.down.right"
        case .topToBottom: return "arrow.down"
        }
    }
}

enum KeyEffect: String, Codable, CaseIterable, Identifiable {
    case inherit = "inherit"
    case solid = "solid"
    case breathing = "breathing"
    case heartbeat = "heartbeat"
    case rainbow = "rainbow"
    case sparkle = "sparkle"
    case blink = "blink"
    case dualFade = "dualFade"
    case reactiveFade = "reactiveFade"
    case reactiveFlash = "reactiveFlash"
    case off = "off"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inherit: return "Heredar global"
        case .solid: return "Color fijo"
        case .breathing: return "Respiración"
        case .heartbeat: return "Latido / Pulso"
        case .rainbow: return "Arcoíris propio"
        case .sparkle: return "Destello"
        case .blink: return "Parpadeo"
        case .dualFade: return "Alternar 2 colores"
        case .reactiveFade: return "Reactiva (encender)"
        case .reactiveFlash: return "Reactiva (destello)"
        case .off: return "Apagada"
        }
    }

    var shortBadge: String {
        switch self {
        case .inherit: return ""
        case .solid: return "•"
        case .breathing: return "~"
        case .heartbeat: return "♥"
        case .rainbow: return "◈"
        case .sparkle: return "✦"
        case .blink: return "⚡"
        case .dualFade: return "⇄"
        case .reactiveFade: return "◉"
        case .reactiveFlash: return "✸"
        case .off: return "×"
        }
    }

    var isAnimated: Bool {
        switch self {
        case .inherit, .solid, .off, .reactiveFade, .reactiveFlash: return false
        default: return true
        }
    }

    var usesSpeed: Bool {
        switch self {
        case .inherit, .solid, .off: return false
        default: return true
        }
    }

    var usesSecondaryColor: Bool {
        switch self {
        case .dualFade, .reactiveFlash: return true
        default: return false
        }
    }
}

struct KeyOverride: Codable, Hashable {
    var effect: KeyEffect
    var color: RGBColor
    var secondaryColor: RGBColor
    var speed: Double

    init(
        effect: KeyEffect = .solid,
        color: RGBColor = .cyan,
        secondaryColor: RGBColor = .magenta,
        speed: Double = 1.0
    ) {
        self.effect = effect
        self.color = color
        self.secondaryColor = secondaryColor
        self.speed = speed
    }
}

struct LightingProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var globalEffect: GlobalEffect
    var primaryColor: RGBColor
    var secondaryColor: RGBColor
    var brightness: Double
    var speed: Double
    var direction: WaveDirection
    var reactiveOverlay: ReactiveOverlayMode
    var reactiveOverlayColor: RGBColor
    var keyOverrides: [String: KeyOverride] // keyId ("K1".."K94") -> override

    init(
        id: UUID = UUID(),
        name: String,
        globalEffect: GlobalEffect = .rainbowWave,
        primaryColor: RGBColor = .cyan,
        secondaryColor: RGBColor = .magenta,
        brightness: Double = 0.85,
        speed: Double = 1.0,
        direction: WaveDirection = .leftToRight,
        reactiveOverlay: ReactiveOverlayMode = .none,
        reactiveOverlayColor: RGBColor = .white,
        keyOverrides: [String: KeyOverride] = [:]
    ) {
        self.id = id
        self.name = name
        self.globalEffect = globalEffect
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.brightness = brightness
        self.speed = speed
        self.direction = direction
        self.reactiveOverlay = reactiveOverlay
        self.reactiveOverlayColor = reactiveOverlayColor
        self.keyOverrides = keyOverrides
    }

    // Backwards-compatible decoding for previously saved state.json files
    enum CodingKeys: String, CodingKey {
        case id, name, globalEffect, primaryColor, secondaryColor, brightness, speed, direction
        case reactiveOverlay, reactiveOverlayColor, keyOverrides
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        globalEffect = try c.decode(GlobalEffect.self, forKey: .globalEffect)
        primaryColor = try c.decode(RGBColor.self, forKey: .primaryColor)
        secondaryColor = try c.decode(RGBColor.self, forKey: .secondaryColor)
        brightness = try c.decode(Double.self, forKey: .brightness)
        speed = try c.decode(Double.self, forKey: .speed)
        direction = try c.decode(WaveDirection.self, forKey: .direction)
        reactiveOverlay = (try? c.decode(ReactiveOverlayMode.self, forKey: .reactiveOverlay)) ?? .none
        reactiveOverlayColor = (try? c.decode(RGBColor.self, forKey: .reactiveOverlayColor)) ?? .white
        keyOverrides = try c.decode([String: KeyOverride].self, forKey: .keyOverrides)
    }

    var hasAnyContinuousAnimation: Bool {
        if globalEffect.isAnimated { return true }
        return keyOverrides.values.contains { $0.effect.isAnimated }
    }

    static let builtInPresets: [LightingProfile] = {
        // Helper to map key names to key IDs
        func idOf(_ name: String) -> String? { K648Layout.keyByName[name]?.id }

        // Gaming FPS preset: dark blue base + pulsing red WASD + cyan arrows + gold Esc/Space
        var fpsOverrides: [String: KeyOverride] = [:]
        for n in ["W", "A", "S", "D"] {
            if let k = idOf(n) {
                fpsOverrides[k] = KeyOverride(effect: .breathing, color: RGBColor(hex: "#FF1744"), speed: 1.4)
            }
        }
        for n in ["Up", "Down", "Left", "Right"] {
            if let k = idOf(n) {
                fpsOverrides[k] = KeyOverride(effect: .solid, color: RGBColor(hex: "#00E5FF"))
            }
        }
        for n in ["1", "2", "3", "4", "5", "R", "E", "F", "Q"] {
            if let k = idOf(n) {
                fpsOverrides[k] = KeyOverride(effect: .solid, color: RGBColor(hex: "#FF9100"))
            }
        }
        if let esc = idOf("Esc") {
            fpsOverrides[esc] = KeyOverride(effect: .heartbeat, color: RGBColor(hex: "#FF1744"), speed: 1.2)
        }
        if let sp = idOf("Space") {
            fpsOverrides[sp] = KeyOverride(effect: .dualFade, color: RGBColor(hex: "#00E5FF"), secondaryColor: RGBColor(hex: "#2979FF"), speed: 0.9)
        }

        // Coding / Productivity preset
        var devOverrides: [String: KeyOverride] = [:]
        if let esc = idOf("Esc") {
            devOverrides[esc] = KeyOverride(effect: .breathing, color: RGBColor(hex: "#FF3D00"), speed: 0.8)
        }
        for n in ["Enter", "Backspace", "Tab", "LShift", "RShift", "LCtrl", "RCtrl", "LWin", "LAlt", "RAlt"] {
            if let k = idOf(n) {
                devOverrides[k] = KeyOverride(effect: .solid, color: RGBColor(hex: "#00B0FF"))
            }
        }
        for n in ["Up", "Down", "Left", "Right"] {
            if let k = idOf(n) {
                devOverrides[k] = KeyOverride(effect: .solid, color: RGBColor(hex: "#00E676"))
            }
        }

        return [
            LightingProfile(
                name: "Onda Reactiva",
                globalEffect: .reactiveRipple,
                primaryColor: RGBColor(hex: "#00E5FF"),
                secondaryColor: RGBColor(hex: "#071024"),
                brightness: 0.95,
                speed: 1.1,
                direction: .leftToRight
            ),
            LightingProfile(
                name: "Arcoíris al Teclear",
                globalEffect: .reactiveRainbowRipple,
                primaryColor: .cyan,
                secondaryColor: RGBColor(hex: "#090912"),
                brightness: 0.95,
                speed: 1.1,
                direction: .leftToRight
            ),
            LightingProfile(
                name: "Cruz Láser",
                globalEffect: .reactiveCross,
                primaryColor: RGBColor(hex: "#FF1744"),
                secondaryColor: RGBColor(hex: "#10060B"),
                brightness: 0.95,
                speed: 1.2,
                direction: .leftToRight
            ),
            LightingProfile(
                name: "Estela Neón",
                globalEffect: .reactiveTrail,
                primaryColor: RGBColor(hex: "#FF1791"),
                secondaryColor: RGBColor(hex: "#0A0C18"),
                brightness: 0.95,
                speed: 1.0,
                direction: .leftToRight
            ),
            LightingProfile(
                name: "Chispas Reactivas",
                globalEffect: .reactiveSplash,
                primaryColor: RGBColor(hex: "#FFD600"),
                secondaryColor: RGBColor(hex: "#120A04"),
                brightness: 0.95,
                speed: 1.0,
                direction: .leftToRight
            ),
            LightingProfile(
                name: "Mapa de Calor",
                globalEffect: .reactiveHeatmap,
                primaryColor: RGBColor(hex: "#FF2438"),
                secondaryColor: RGBColor(hex: "#0A1A40"),
                brightness: 0.95,
                speed: 1.0,
                direction: .leftToRight
            ),
            LightingProfile(
                name: "Arcoíris Fluido",
                globalEffect: .rainbowWave,
                primaryColor: .cyan,
                secondaryColor: .magenta,
                brightness: 0.9,
                speed: 1.0,
                direction: .leftToRight
            ),
            LightingProfile(
                name: "Gaming FPS (WASD)",
                globalEffect: .solid,
                primaryColor: RGBColor(hex: "#0A1E40"),
                secondaryColor: .cyan,
                brightness: 0.9,
                speed: 1.0,
                direction: .leftToRight,
                reactiveOverlay: .keyFlash,
                reactiveOverlayColor: RGBColor(hex: "#FFFFFF"),
                keyOverrides: fpsOverrides
            ),
            LightingProfile(
                name: "Cyberpunk Neón",
                globalEffect: .aurora,
                primaryColor: RGBColor(hex: "#00F0FF"),
                secondaryColor: RGBColor(hex: "#FF00AA"),
                brightness: 0.95,
                speed: 1.1,
                direction: .diagonal,
                reactiveOverlay: .ripple,
                reactiveOverlayColor: RGBColor(hex: "#FFFFFF")
            ),
            LightingProfile(
                name: "Código / Dev",
                globalEffect: .solid,
                primaryColor: RGBColor(hex: "#DCE8FF"),
                secondaryColor: RGBColor(hex: "#00B0FF"),
                brightness: 0.75,
                speed: 1.0,
                direction: .leftToRight,
                reactiveOverlay: .keyFlash,
                reactiveOverlayColor: RGBColor(hex: "#00E5FF"),
                keyOverrides: devOverrides
            ),
            LightingProfile(
                name: "Fuego Volcánico",
                globalEffect: .fire,
                primaryColor: RGBColor(hex: "#FF3D00"),
                secondaryColor: RGBColor(hex: "#FFD600"),
                brightness: 0.95,
                speed: 1.2,
                direction: .topToBottom
            ),
            LightingProfile(
                name: "Lluvia Matrix",
                globalEffect: .matrixRain,
                primaryColor: RGBColor(hex: "#00FF66"),
                secondaryColor: RGBColor(hex: "#003311"),
                brightness: 0.9,
                speed: 1.1,
                direction: .topToBottom
            ),
            LightingProfile(
                name: "Pulso Galaxia",
                globalEffect: .radialPulse,
                primaryColor: RGBColor(hex: "#7C4DFF"),
                secondaryColor: RGBColor(hex: "#00E5FF"),
                brightness: 0.9,
                speed: 1.0,
                direction: .leftToRight
            ),
            LightingProfile(
                name: "Estrellas Nocturnas",
                globalEffect: .twinkle,
                primaryColor: RGBColor(hex: "#FFFFFF"),
                secondaryColor: RGBColor(hex: "#0B1026"),
                brightness: 0.85,
                speed: 1.0,
                direction: .leftToRight
            ),
        ]
    }()
}

struct AppPersistedState: Codable {
    var activeProfile: LightingProfile
    var savedProfiles: [LightingProfile]
    var gammaCorrection: Bool
    var keepRunningInMenuBar: Bool
    var launchHiddenInMenuBar: Bool
    var turnOffOnLockOrSleep: Bool

    init(
        activeProfile: LightingProfile,
        savedProfiles: [LightingProfile],
        gammaCorrection: Bool,
        keepRunningInMenuBar: Bool,
        launchHiddenInMenuBar: Bool = false,
        turnOffOnLockOrSleep: Bool = true
    ) {
        self.activeProfile = activeProfile
        self.savedProfiles = savedProfiles
        self.gammaCorrection = gammaCorrection
        self.keepRunningInMenuBar = keepRunningInMenuBar
        self.launchHiddenInMenuBar = launchHiddenInMenuBar
        self.turnOffOnLockOrSleep = turnOffOnLockOrSleep
    }

    enum CodingKeys: String, CodingKey {
        case activeProfile, savedProfiles, gammaCorrection
        case keepRunningInMenuBar, launchHiddenInMenuBar, turnOffOnLockOrSleep
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activeProfile = try c.decode(LightingProfile.self, forKey: .activeProfile)
        savedProfiles = try c.decode([LightingProfile].self, forKey: .savedProfiles)
        gammaCorrection = (try? c.decode(Bool.self, forKey: .gammaCorrection)) ?? true
        keepRunningInMenuBar = (try? c.decode(Bool.self, forKey: .keepRunningInMenuBar)) ?? true
        launchHiddenInMenuBar = (try? c.decode(Bool.self, forKey: .launchHiddenInMenuBar)) ?? false
        turnOffOnLockOrSleep = (try? c.decode(Bool.self, forKey: .turnOffOnLockOrSleep)) ?? true
    }
}
